% =========================================================================
% SCRIPT: K-MEANS + SOS VS GREEDY MU-MIMO SCHEDULING FOR 60,000 UEs
% Antenna: 32T32R | Compare execution time between SOS and Greedy sweep
% =========================================================================
clear; clc; close all; 
setupPath();

nLayers = 4;
numberOfUeToGroup = 2;
numberOfUE = 20000;

config.CodeBookConfig.N1 = 4;
config.CodeBookConfig.N2 = 4;
config.CodeBookConfig.cbMode = 1;
config.FileName = "Layer4_Port32_N1_4_N2-4_c1.txt";

[W_all, UE_Reported_Indices, totalPMI] = prepareData(config, nLayers, numberOfUE);

baseConfig = struct('desc', 'Case 1: Default', ...
           'NLAYERS', nLayers, 'MCS', 27, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 2, 'DMRS_ADDITIONAL_POSITION', 1, ...
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', '2UE_Combine_PDSCH_Waveform_4P2V');

% =========================================================================
% 3. Pre-Processing: Build representative UE pool via K-Means clustering
% =========================================================================
poolConfig = struct();
poolConfig.numClusters = min(totalPMI, 500);
poolConfig.targetPoolSize = 2000;
poolConfig.kmeansMaxIter  = 100;

disp('--- Running K-Means to build Representative Pool ---');
[W_pool, pool_indices, pool_pmi] = buildRepresentativePool(W_all, UE_Reported_Indices, poolConfig);

% =========================================================================
% TÌM CÁC CẶP TRỰC GIAO VÀ TEST BER
% =========================================================================
threshold = 0.9; % Ngưỡng trực giao
fprintf('\n[Pre-search] Finding feasible orthogonal UE pairs (score >= %.2f)...\n', threshold);

% Gọi hàm mới của bro (Trả về danh sách các nhóm)
[f_groups, f_W, f_scores, f_pmi] = findFeasibleOrthogonalGroups(W_pool, pool_pmi, numberOfUeToGroup, 50, threshold);

% ── LỌC TÌM CẶP CÓ ĐIỂM NẰM TRONG KHOẢNG [0.90, 0.92] ────────────────
targetIdx = [];
for k = 1:length(f_scores)
    if f_scores(k) >= 0.90 && f_scores(k) <= 0.92
        targetIdx = k;
        break; % Tìm thấy cặp đầu tiên thỏa mãn là dừng lại luôn
    end
end

% Kiểm tra xem có tìm được cặp nào không
if ~isempty(f_W)
    fprintf('\n---> Đưa cặp ĐẦU TIÊN đạt chuẩn vào test BER Loopback quét dải SNR...\n');
    
    % Lấy ma trận W của nhóm ĐẦU TIÊN trong danh sách
    W_test = f_W{1}; 

    % ── ĐỊNH NGHĨA DẢI SNR QUÉT ──────────────────────────────────────────
    snrRange = 30; % Quét từ 0 đến 30, bước nhảy 5
    
    % Khởi tạo mảng lưu kết quả
    ber1_results = zeros(length(snrRange), 1);
    ber2_results = zeros(length(snrRange), 1);
    
    fprintf('\n[KẾT QUẢ TEST BER MU-MIMO THEO SNR]\n');
    fprintf('SNR (dB) | BER UE 1     | BER UE 2\n');
    fprintf('----------------------------------------\n');
    
    W_test = f_W{targetIdx}; 
    W_UE1_Codebook = W_test(:,:,1);
    W_UE2_Codebook = W_test(:,:,2);

    disp(W_UE1_Codebook);
    disp(W_UE2_Codebook);

    % ── VÒNG LẶP TEST SNR ────────────────────────────────────────────────
    for i = 1:length(snrRange)
        currentSNR = snrRange(i);
        
        [ber1, ber2] = muMIMO2UE(baseConfig, W_UE1_Codebook, W_UE2_Codebook, currentSNR);
        
        % Lưu kết quả vào mảng
        ber1_results(i) = ber1;
        ber2_results(i) = ber2;
        
        % In kết quả của từng mức SNR ra Command Window
        fprintf('%8d | %10.6f | %10.6f\n', currentSNR, ber1, ber2);
    end
    
    % ── VẼ BIỂU ĐỒ BER (WATERFALL CURVE) ─────────────────────────────────
    figure('Name', 'MU-MIMO BER Performance', 'Color', 'w');
    semilogy(snrRange, ber1_results, '-ob', 'LineWidth', 2, 'MarkerSize', 6);
    hold on;
    semilogy(snrRange, ber2_results, '-sr', 'LineWidth', 2, 'MarkerSize', 6);
    
    grid on;
    % Bật grid phụ để nhìn log-scale rõ hơn
    set(gca, 'YMinorGrid', 'on'); 
    
    xlabel('SNR (dB)', 'FontWeight', 'bold');
    ylabel('Bit Error Rate (BER)', 'FontWeight', 'bold');
    title('Hiệu năng BER của hệ thống MU-MIMO (2 UEs)', 'FontSize', 12);
    legend('UE 1', 'UE 2', 'Location', 'southwest');
    
    % Giới hạn trục Y (tùy chọn) để đồ thị đẹp hơn, ví dụ từ 10^-4 đến 1
    % ylim([1e-4 1]); 
    
else
    fprintf('\n[THẤT BẠI] SOS không tìm được cặp nào đạt ngưỡng trực giao %.2f.\n', threshold);
    fprintf('Gợi ý: Thử giảm threshold xuống 0.8 hoặc tăng targetPoolSize/maxIter lên.\n');
end

% =========================================================================
% LOCAL FUNCTIONS 
% =========================================================================
function [feasible_groups, feasible_W, feasible_scores, feasible_pmi] = findFeasibleOrthogonalGroups(W_pool, pool_pmi, num_users_to_group, maxIter, threshold)
    % Cài đặt mặc định nếu không truyền vào
    if nargin < 5
        threshold = 0.9; % Ngưỡng trực giao mặc định
    end
    if nargin < 4
        maxIter = 50; 
    end

    % 1. Gọi thuật toán SOS để tìm lịch trình ghép nhóm
    fprintf('[GroupSearch] Running SOS Algorithm...\n');
    % [bestGroups, ~] = sosMUMIMOScheduling(W_pool, num_users_to_group, maxIter);
    [bestGroups, ~] = psoMUMIMOScheduling(W_pool, num_users_to_group, maxIter);

    % 2. Lọc ra TẤT CẢ các nhóm thỏa mãn điều kiện (> threshold)
    feasible_groups = {};
    feasible_scores = [];
    feasible_W      = {};
    feasible_pmi    = {};

    numGroups = length(bestGroups);
    for g = 1:numGroups
        current_group = bestGroups{g};
        min_dist_in_group = inf;
        
        % Tính khoảng cách chordal nhỏ nhất giữa bất kỳ 2 UEs nào trong nhóm này
        for i = 1:num_users_to_group-1
            for j = i+1:num_users_to_group
                u1 = current_group(i);
                u2 = current_group(j);
                dist = chordalDistance(W_pool(:,:,u1), W_pool(:,:,u2));
                if dist < min_dist_in_group
                    min_dist_in_group = dist;
                end
            end
        end
        
        % Nếu nhóm này đạt chuẩn (> 0.9), lưu nó lại!
        if min_dist_in_group >= threshold
            feasible_groups{end+1} = current_group;      % Lưu index
            feasible_scores(end+1) = min_dist_in_group;  % Lưu điểm thực tế
            feasible_W{end+1}      = W_pool(:, :, current_group); % Lưu ma trận W
            feasible_pmi{end+1}    = pool_pmi(current_group);     % Lưu tên PMI
        end
    end

    % =====================================================================
    % In thống kê kết quả
    % =====================================================================
    fprintf('\n========================================\n');
    fprintf('  SOS Scheduling Completed!\n');
    fprintf('  - Total groups evaluated: %d\n', numGroups);
    fprintf('  - FEASIBLE GROUPS FOUND (Score >= %.2f): %d\n', threshold, length(feasible_groups));
    fprintf('========================================\n');
    
    for k = 1:length(feasible_groups)
        fprintf('  Group %d: UEs [%s] | Min Distance = %.4f\n', ...
            k, num2str(feasible_groups{k}), feasible_scores(k));
    end
    fprintf('\n');
end

function [W_all, UE_Reported_Indices, totalPMI] = prepareData(config, nLayers, numberOfUE)
    % Trích xuất thông số cấu hình
    N1 = config.CodeBookConfig.N1;
    N2 = config.CodeBookConfig.N2;
    cbMode = config.CodeBookConfig.cbMode;
    nPort = 2 * N1 * N2;
    filename = sprintf(config.FileName, nPort, nLayers, cbMode, N1, N2);

    fprintf('Đang nạp "bể" ma trận (pool) từ file: %s...\n', filename);

    % --- BƯỚC 1: ĐỌC TOÀN BỘ FILE VÀO MỘT TẬP HỢP TẠM THỜI (POOL) ---
    fid = fopen(filename, 'r');
    if fid == -1
        error('Không thể mở file: %s', filename);
    end

    W_pool = [];
    pool_info = {};
    pmi_in_file = 0;

    while ~feof(fid)
        info_line = fgetl(fid);
        if ~ischar(info_line), break; end
        if isempty(strtrim(info_line)), continue; end

        pmi_in_file = pmi_in_file + 1;
        pool_info{pmi_in_file} = info_line;
        
        W_temp = zeros(nPort, nLayers);
        for row = 1:nPort
            row_data = fgetl(fid);
            W_temp(row, :) = str2num(row_data);
        end
        W_pool(:, :, pmi_in_file) = W_temp;
    end
    fclose(fid);

    fprintf('Đã nạp thành công %d ma trận mẫu từ file.\n', pmi_in_file);

    % --- BƯỚC 2: LẤY MẪU NGẪU NHIÊN 20,000 CÁI TỪ POOL ---
    fprintf('Bắt đầu lấy mẫu %d ma trận ngẫu nhiên từ bể chứa...\n', numberOfUE);

    % Tạo 20,000 chỉ số ngẫu nhiên nằm trong khoảng từ 1 đến số lượng ma trận trong file
    % Ví dụ: Nếu file có 128 ma trận, rand_idx sẽ chứa 20,000 số ngẫu nhiên từ 1-128
    rand_idx = randi(pmi_in_file, 1, numberOfUE);

    % Trích xuất nhanh bằng cách sử dụng mảng chỉ số (Vectorized Indexing)
    W_all = W_pool(:, :, rand_idx);
    
    % Lấy thông tin PMI tương ứng
    UE_Reported_Indices = pool_info(rand_idx);

    totalPMI = pmi_in_file;

    fprintf('Hoàn thành! W_all: [%d x %d x %d]\n\n', size(W_all, 1), size(W_all, 2), size(W_all, 3));
end

function [W_pool, pool_indices, pool_pmi] = buildRepresentativePool(W_all, UE_Reported_Indices, config)
    % 1. Xử lý cấu hình an toàn (Thay thế getField để code độc lập hơn)
    if isfield(config, 'numClusters'), numClusters = config.numClusters; 
    else 
        numClusters = 50; 
    end
    if isfield(config, 'targetPoolSize'), targetPoolSize = config.targetPoolSize; 
    else 
        targetPoolSize = 200; 
    end
    if isfield(config, 'kmeansMaxIter'), kmeansMaxIter = config.kmeansMaxIter; 
    else 
        kmeansMaxIter = 100; 
    end

    % 2. Lấy kích thước thực tế của W_all
    [Num_Antennas, NumLayers, Num_UEs] = size(W_all);

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