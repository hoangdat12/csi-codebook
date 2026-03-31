% =========================================================================
% SCRIPT: K-MEANS + SOS VS GREEDY MU-MIMO SCHEDULING FOR 60,000 UEs
% Antenna: 32T32R | Compare execution time between SOS and Greedy sweep
% =========================================================================
clear; clc; close all; 
setupPath();

nLayers = 4;

config.CodeBookConfig.N1 = 2;
config.CodeBookConfig.N2 = 1;
config.CodeBookConfig.cbMode = 1;

% 3. Gọi hàm để đọc dữ liệu từ file
% Đảm bảo file .txt đang nằm cùng thư mục với script đang chạy
[W_all, UE_Reported_Indices] = prepareData(config, nLayers);

% =========================================================================
% 3. Pre-Processing: Build representative UE pool via K-Means clustering
% =========================================================================
poolConfig = struct();
poolConfig.numClusters    = 50;
poolConfig.targetPoolSize = 200;
poolConfig.kmeansMaxIter  = 100;

disp('--- Running K-Means to build Representative Pool ---');
[W_pool, pool_indices, pool_pmi] = buildRepresentativePool(W_all, UE_Reported_Indices, poolConfig);

% TÌM CẶP UE TRỰC GIAO NHẤT TRONG TOÀN BỘ POOL
% =========================================================================
fprintf('\n[Pre-search] Finding most orthogonal UE pair in pool...\n');
[ue1, ue2, W1, W2, pairDist, pmi1, pmi2] = findBestOrthogonalPair(W_pool, pool_pmi);


% =========================================================================
% LOCAL FUNCTIONS 
% =========================================================================
function [ue1_idx, ue2_idx, W1, W2, bestScore, pmi1, pmi2] = findBestOrthogonalPair(W_pool, pool_pmi)
% pool_pmi: cell array {1 x NUE}, mỗi phần tử là struct indices của UE đó

    NUE = size(W_pool, 3);

    bestScore = -inf;
    ue1_idx   = -1;
    ue2_idx   = -1;

    fprintf('[PairSearch] Scanning %d UE pairs...\n', NUE*(NUE-1)/2);

    for i = 1:NUE-1
        for j = i+1:NUE
            Wi = W_pool(:, :, i);
            Wj = W_pool(:, :, j);

            score = chordalDistance(Wi, Wj);

            if score > bestScore
                bestScore = score;
                ue1_idx   = i;
                ue2_idx   = j;
            end
        end
    end

    W1   = W_pool(:, :, ue1_idx);
    W2   = W_pool(:, :, ue2_idx);
    pmi1 = pool_pmi{ue1_idx};   % <-- PMI struct của UE1
    pmi2 = pool_pmi{ue2_idx};   % <-- PMI struct của UE2

    % =====================================================================
    % In kết quả
    % =====================================================================
    fprintf('\n========================================\n');
    fprintf('  Best orthogonal pair found:\n');
    fprintf('  UE %d  vs  UE %d\n', ue1_idx, ue2_idx);
    fprintf('  Chordal Distance = %.6f\n', bestScore);
    fprintf('  (1 = hoàn toàn trực giao, 0 = hoàn toàn tương quan)\n');
    fprintf('========================================\n');

    fprintf('\nChordalDistance(W1, W2) = %.6f\n', chordalDistance(W1, W2));

    fprintf('W1 (UE %d):\n', ue1_idx); disp(W1);
    fprintf('W2 (UE %d):\n', ue2_idx); disp(W2);
end

function [W_all, UE_Reported_Indices] = prepareData(config, nLayers)
    % Trích xuất thông số cấu hình
    N1 = config.CodeBookConfig.N1;
    N2 = config.CodeBookConfig.N2;
    cbMode = config.CodeBookConfig.cbMode; % Cần đảm bảo cbMode có trong config

    nPort = 2 * N1 * N2; % Số cổng anten
    
    % Tự động tạo tên file dựa trên cấu hình (ví dụ: Precoding_4Port4Layer_CBModeN1N2_121.txt)
    filename = sprintf('Precoding_%dPort%dLayer_CBModeN1N2_%d%d%d.txt', nPort, nLayers, cbMode, N1, N2);
    
    fprintf('Đang đọc ma trận precoder W_all từ file: %s...\n', filename);
    
    % Mở file
    fid = fopen(filename, 'r');
    if fid == -1
        error('Không thể mở file: %s. Hãy đảm bảo file đang nằm cùng thư mục.', filename);
    end
    
    % Khởi tạo biến
    UE_Reported_Indices = {}; % Lưu thông tin info của từng ma trận
    W_all = [];               % Ma trận 3 chiều lưu toàn bộ các W
    pmi_count = 0;            % Đếm số lượng ma trận
    
    % Vòng lặp đọc toàn bộ file
    while ~feof(fid)
        info_line = fgetl(fid); % Đọc dòng thông tin PMI
        
        % Dừng nếu hết file
        if ~ischar(info_line)
            break;
        end
        
        % Bỏ qua các dòng trống (nếu có)
        if isempty(strtrim(info_line))
            continue;
        end
        
        pmi_count = pmi_count + 1;
        
        % Lưu dòng thông tin vào cell array thay vì struct random như cũ
        UE_Reported_Indices{pmi_count} = info_line; 
        
        % Khởi tạo ma trận tạm thời
        W_temp = zeros(nPort, nLayers);
        
        % Đọc các dòng chứa giá trị ma trận
        for row = 1:nPort
            row_data = fgetl(fid);
            W_temp(row, :) = str2num(row_data);
        end
        
        % Gán ma trận vừa đọc vào W_all
        W_all(:, :, pmi_count) = W_temp;
    end
    
    fclose(fid);
    
    % Hiển thị kích thước cuối cùng: [Số port x Số layer x Số PMI đọc được]
    fprintf('W_all completed: [%d x %d x %d]\n\n', size(W_all, 1), size(W_all, 2), size(W_all, 3));

end % end prepareData

function [W_pool, pool_indices, pool_pmi] = buildRepresentativePool(W_all, UE_Reported_Indices, config)
    % 1. Xử lý cấu hình an toàn (Thay thế getField để code độc lập hơn)
    if isfield(config, 'numClusters'), numClusters = config.numClusters; else numClusters = 50; end
    if isfield(config, 'targetPoolSize'), targetPoolSize = config.targetPoolSize; else targetPoolSize = 200; end
    if isfield(config, 'kmeansMaxIter'), kmeansMaxIter = config.kmeansMaxIter; else kmeansMaxIter = 100; end

    % 2. Lấy kích thước thực tế của W_all
    [Num_Antennas, NumLayers, Num_UEs] = size(W_all);

    % Kiểm tra cảnh báo nếu không đúng chuẩn 4x4 (tùy chọn)
    if Num_Antennas ~= 4 || NumLayers ~= 4
        warning('Đầu vào W_all có kích thước [%d x %d x %d]. Đang mong đợi ma trận 4x4.', Num_Antennas, NumLayers, Num_UEs);
    end

    % 3. Đảm bảo số lượng cluster không được vượt quá số lượng ma trận thực tế
    % (Nếu file của bạn chỉ có 16 ma trận mà numClusters = 50 thì K-means sẽ báo lỗi)
    if numClusters > Num_UEs
        fprintf('Cảnh báo: numClusters (%d) lớn hơn số lượng ma trận (%d). Tự động gán lại numClusters = %d.\n', numClusters, Num_UEs, Num_UEs);
        numClusters = Num_UEs;
    end

    % 4. Chuẩn bị dữ liệu cho K-means
    % W_all [4 x 4 x Num_UEs] -> Trải phẳng thành W_flat [Num_UEs x 16]
    W_flat = reshape(W_all, Num_Antennas * NumLayers, Num_UEs).';
    
    % Tách phần thực và phần ảo để làm features (kích thước [Num_UEs x 32])
    W_features = [real(W_flat), imag(W_flat)];

    fprintf('Running K-means (%d clusters) on %d matrices...\n', numClusters, Num_UEs);
    
    % 5. Chạy K-means
    [cluster_idx, ~] = kmeans(W_features, numClusters, ...
                            'Distance', 'cosine',    ...
                            'MaxIter',  kmeansMaxIter);

    % 6. Rút trích tập đại diện (Pool)
    ues_per_cluster = ceil(targetPoolSize / numClusters);
    pool_indices = [];
    
    for c = 1:numClusters
        members     = find(cluster_idx == c);
        members     = members(randperm(length(members))); % Xáo trộn ngẫu nhiên thứ tự
        num_to_pick = min(ues_per_cluster, length(members));
        pool_indices = [pool_indices; members(1:num_to_pick)];
    end

    % 7. Gán kết quả đầu ra
    W_pool   = W_all(:, :, pool_indices);
    pool_pmi = UE_Reported_Indices(pool_indices);   % <-- cell array PMI theo pool

    fprintf('Representative pool: %d matrices from %d clusters (target: %d).\n\n', ...
            length(pool_indices), numClusters, targetPoolSize);
end
