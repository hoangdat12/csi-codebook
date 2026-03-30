% =========================================================================
% SCRIPT: ĐÁNH GIÁ BER CHỈ SỬ DỤNG K-MEANS SCHEDULING (KHÔNG DÙNG SOS)
% Antenna: 32T32R | Evaluate Group Sizes: 2 to 12
% =========================================================================
clear; clc; close all;
setupPath();

% =========================================================================
% 1. Configuration for test — 32T32R
% =========================================================================
prepareDataConfig = struct();
prepareDataConfig.Num_UEs           = 60000;
prepareDataConfig.N1                = 8;   % 8x4 = 32 Tx ports
prepareDataConfig.N2                = 4;
prepareDataConfig.O1                = 4;
prepareDataConfig.O2                = 4;
prepareDataConfig.L                 = 2;
prepareDataConfig.NumLayers         = 1;
prepareDataConfig.subbandAmplitude  = true;
prepareDataConfig.PhaseAlphabetSize = 8;

% =========================================================================
% 2. Prepare precoder matrix W for all UEs
% =========================================================================
disp('--- Generating data for 60,000 UEs (32T32R) ---');
[W_all, UE_Reported_Indices] = prepareData(prepareDataConfig);

% =========================================================================
% 3. Pre-Processing: Build representative UE pool via K-Means clustering
% =========================================================================
poolConfig = struct();
poolConfig.numClusters    = 500;   % Tăng số cụm lên để phân loại chi tiết hơn
poolConfig.targetPoolSize = 2000;  % Tăng Pool lên 2000 UEs
poolConfig.kmeansMaxIter  = 100;

disp('--- Running K-Means to build Representative Pool ---');
[W_pool, pool_indices] = buildRepresentativePool(W_all, poolConfig);

% =========================================================================
% 4. PHY Layer Configuration — 32T32R
% =========================================================================
phyConfig = struct();
phyConfig.MCS               = 4;
phyConfig.SNR_dB            = 20;
phyConfig.PRBSet            = 0:272;
phyConfig.SubcarrierSpacing = 30;
phyConfig.NSizeGrid         = 273;


% =========================================================================
% ĐÁNH GIÁ LẬP LỊCH TOÀN BỘ VỚI THRESHOLD = 0.8 (CÓ ĐO THỜI GIAN)
% =========================================================================
disp(' ');
disp('=======================================================================================================');
disp('   LẬP LỊCH TOÀN BỘ UEs (K-MEANS) VỚI CHORDAL DISTANCE THRESHOLD = 0.8 | POOL = 2000 UEs');
disp('=======================================================================================================');

threshold = 0.8;
test_groupSizes = 2:8;       % Đồng bộ: Chạy liên tục từ 2 đến 8
test_numClusters = 500;      % Đồng bộ: Tăng lên 500 cụm để phân loại 2000 UEs chi tiết hơn

% Khởi tạo các mảng để lưu dữ liệu vẽ đồ thị
num_test = length(test_groupSizes);
valid_counts = zeros(1, num_test);
max_groups = zeros(1, num_test);
avg_valid_scores = zeros(1, num_test);
avg_total_scores = zeros(1, num_test);
exec_times = zeros(1, num_test);

% Thêm cột Thời gian vào bảng in
fprintf('%-10s | %-18s | %-20s | %-20s | %-15s\n', 'Group Size', 'Nhóm đạt / Tối đa', 'Điểm TB (Toàn bộ)', 'Điểm TB (Nhóm đạt)', 'Thời gian (s)');
disp('-------------------------------------------------------------------------------------------------------');

for i = 1:num_test
    gs = test_groupSizes(i);
    max_groups(i) = floor(length(pool_indices) / gs); 
    
    % Bắt đầu đo thời gian
    tic;
    [~, numValid, avgValidScore, avgTotalScore] = scheduleAllUEsWithThreshold(W_pool, gs, test_numClusters, threshold);
    exec_times(i) = toc; % Kết thúc đo thời gian
    
    % Lưu dữ liệu vào mảng
    valid_counts(i) = numValid;
    avg_valid_scores(i) = avgValidScore;
    avg_total_scores(i) = avgTotalScore;
    
    % In kết quả
    fprintf('%-10d | %4d / %-11d | %-20.4f | %-20.4f | %-15.4f\n', ...
        gs, valid_counts(i), max_groups(i), avg_total_scores(i), avg_valid_scores(i), exec_times(i));
end
disp('=======================================================================================================');

% =========================================================================
% VẼ BIỂU ĐỒ ĐÁNH GIÁ HIỆU SUẤT K-MEANS
% =========================================================================
disp('--- Đang vẽ biểu đồ đánh giá... ---');

% 1. Đồ thị: Số lượng nhóm đạt chuẩn vs Kích thước nhóm
figure('Name', 'Số lượng nhóm MU-MIMO hợp lệ', 'Position', [100, 100, 600, 450]);
b = bar(test_groupSizes, [valid_counts' (max_groups - valid_counts)'], 'stacked');
b(1).FaceColor = [0 0.4470 0.7410]; % Màu xanh lam cho nhóm đạt
b(2).FaceColor = [0.8 0.8 0.8];     % Màu xám cho nhóm bị loại
legend('Nhóm đạt chuẩn (\geq 0.8)', 'Nhóm bị loại (< 0.8)', 'Location', 'northeast');
title('Khả năng ghép nhóm của K-Means Only (Pool: 2000 UEs)', 'FontSize', 13);
xlabel('Kích thước nhóm (Group Size)', 'FontSize', 11);
ylabel('Số lượng nhóm', 'FontSize', 11);
grid on; set(gca, 'XTick', test_groupSizes);

% Thêm label số lượng nhóm đạt trực tiếp lên phần cột màu xanh
for i = 1:num_test
    if valid_counts(i) > 0
        text(test_groupSizes(i), valid_counts(i), num2str(valid_counts(i)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
            'FontWeight', 'bold', 'Color', 'k');
    end
end

% 2. Đồ thị: Điểm trực giao trung bình
figure('Name', 'Điểm trực giao (Chordal Distance)', 'Position', [750, 100, 600, 450]);
plot(test_groupSizes, avg_total_scores, '-ob', 'LineWidth', 2, 'MarkerSize', 7, 'MarkerFaceColor', 'b'); hold on;
plot(test_groupSizes, avg_valid_scores, '-sr', 'LineWidth', 2, 'MarkerSize', 7, 'MarkerFaceColor', 'r');
yline(threshold, '--k', 'Threshold (0.8)', 'LineWidth', 1.5, 'LabelHorizontalAlignment', 'left');
legend('Điểm TB Toàn bộ', 'Điểm TB Nhóm đạt chuẩn', 'Location', 'northeast');
title('Chất lượng trực giao theo kích thước nhóm', 'FontSize', 13);
xlabel('Kích thước nhóm (Group Size)', 'FontSize', 11);
ylabel('Chordal Distance', 'FontSize', 11);
grid on; set(gca, 'XTick', test_groupSizes);
ylim([0.4 1.05]);

% 3. Đồ thị: Thời gian thực thi
figure('Name', 'Thời gian thực thi', 'Position', [400, 600, 600, 450]);
plot(test_groupSizes, exec_times, '-^g', 'LineWidth', 2, 'MarkerSize', 7, 'MarkerFaceColor', 'g');
title('Thời gian thực thi thuật toán K-Means Only', 'FontSize', 13);
xlabel('Kích thước nhóm (Group Size)', 'FontSize', 11);
ylabel('Thời gian (giây)', 'FontSize', 11);
grid on; set(gca, 'XTick', test_groupSizes);

disp('--- Hoàn tất! ---');

% =========================================================================
% LOCAL FUNCTIONS 
% =========================================================================

function [validGroups, numValidGroups, avgValidScore, avgTotalScore] = scheduleAllUEsWithThreshold(W_matrix, groupSize, numClusters, threshold)
    % =========================================================================
    % Lập lịch toàn bộ UEs dựa trên K-Means và lọc theo Threshold
    % ĐÃ TỐI ƯU HÓA: Sử dụng Vectorization (Nhân ma trận) để tính Chordal Distance
    % =========================================================================
    
    [Num_Antennas, NumLayers, NUE] = size(W_matrix);
    maxPossibleGroups = floor(NUE / groupSize); 
    
    % 1. Phân cụm toàn bộ UEs bằng K-Means
    W_flat = reshape(W_matrix, Num_Antennas * NumLayers, NUE).';
    W_features = [real(W_flat), imag(W_flat)];
    
    [cluster_idx, ~] = kmeans(W_features, numClusters, 'Distance', 'cosine', 'MaxIter', 100);
    
    % Đưa UEs vào các danh sách theo cụm
    cluster_ues = cell(numClusters, 1);
    for c = 1:numClusters
        members = find(cluster_idx == c);
        cluster_ues{c} = members(randperm(length(members))); 
    end
    
    validGroups = {};
    validScores = [];
    allScores = []; 
    
    % Chuẩn bị ma trận logic để lấy tam giác trên (phục vụ tính khoảng cách)
    % Giúp tránh việc lặp lại tính toán ở phần 3
    upperTriIdx = triu(true(groupSize), 1);
    numPairs = groupSize * (groupSize - 1) / 2;
    
    % 2. Ghép nhóm
    for g = 1:maxPossibleGroups
        available_clusters = find(cellfun(@length, cluster_ues) > 0);
        
        if length(available_clusters) < groupSize
            break; 
        end
        
        selected_clusters = available_clusters(randperm(length(available_clusters), groupSize));
        
        current_group = zeros(1, groupSize);
        for i = 1:groupSize
            c = selected_clusters(i);
            current_group(i) = cluster_ues{c}(1);
            cluster_ues{c}(1) = []; 
        end
        
        % =================================================================
        % 3. TÍNH CHORDAL DISTANCE (ĐÃ TỐI ƯU VỚI NHÂN MA TRẬN)
        % Thay vì dùng 2 vòng lặp for gọi hàm chordalDistance, ta tính gộp
        % =================================================================
        
        % Rút ma trận W của cả nhóm và làm phẳng nếu có nhiều layers
        % Kích thước W_group: [(Num_Antennas * NumLayers) x groupSize]
        W_group = reshape(W_matrix(:, :, current_group), Num_Antennas * NumLayers, groupSize);
        
        % Tính ma trận Gram (chứa tích vô hướng w_a^H * w_b của tất cả cặp)
        GramMatrix = W_group' * W_group; 
        
        % Tính bình phương chuẩn (norm squared) của từng UE trong nhóm
        normsSq = sum(abs(W_group).^2, 1); % Kích thước: [1 x groupSize]
        
        % Tính ma trận mẫu số: ||w_a||^2 * ||w_b||^2
        normProdMatrix = normsSq' * normsSq; 
        
        % Tính khoảng cách Chordal cho TẤT CẢ các cặp cùng lúc
        distMatrix = 1 - (abs(GramMatrix).^2) ./ normProdMatrix;
        
        % Chỉ lấy tổng khoảng cách của các cặp không lặp (tam giác trên của ma trận)
        groupDist = sum(distMatrix(upperTriIdx));
        groupScore = groupDist / numPairs;
        
        % =================================================================
        
        % Lưu điểm của nhóm này vào danh sách tổng
        allScores(end+1) = groupScore;
        
        % 4. KIỂM TRA THRESHOLD
        if groupScore >= threshold
            validGroups{end+1} = current_group;
            validScores(end+1) = groupScore;
        end
    end
    
    % 5. Tổng kết đầu ra
    numValidGroups = length(validGroups);
    
    if ~isempty(allScores)
        avgTotalScore = mean(allScores);
    else
        avgTotalScore = 0;
    end
    
    if numValidGroups > 0
        avgValidScore = mean(validScores);
    else
        avgValidScore = 0; 
    end
end

function [W_all, UE_Reported_Indices] = prepareData(config)

    % --- Read configuration fields (with default values) ---
    Num_UEs           = getField(config, 'Num_UEs',           20000);
    N1                = getField(config, 'N1',                4);
    N2                = getField(config, 'N2',                1);
    O1                = getField(config, 'O1',                4);
    O2                = getField(config, 'O2',                1);
    L                 = getField(config, 'L',                 2);
    NumLayers         = getField(config, 'NumLayers',         1);
    subbandAmplitude  = getField(config, 'subbandAmplitude',  true);
    PhaseAlphabetSize = getField(config, 'PhaseAlphabetSize', 8);

    % --- Generate random PMI indices for all UEs ---
    fprintf('Generating PMI configuration for %d UEs...\n', Num_UEs);
    UE_Reported_Indices = randomPMIConfig(Num_UEs, N1, N2, O1, O2, L, NumLayers, subbandAmplitude);

    % --- Build cfg struct for generateTypeIIPrecoder ---
    cfg = struct();
    cfg.CodebookConfig.N1                = N1;
    cfg.CodebookConfig.N2                = N2;
    cfg.CodebookConfig.O1                = O1;
    cfg.CodebookConfig.O2                = O2;
    cfg.CodebookConfig.NumberOfBeams     = L;
    cfg.CodebookConfig.PhaseAlphabetSize = PhaseAlphabetSize;
    cfg.CodebookConfig.SubbandAmplitude  = subbandAmplitude;
    cfg.CodebookConfig.numLayers         = NumLayers;

    % --- Compute precoder matrix W_all for all UEs ---
    Num_Antennas = 2 * N1 * N2;
    W_all = zeros(Num_Antennas, NumLayers, Num_UEs);

    fprintf('Computing precoder matrix W_all...\n');
    for u = 1:Num_UEs
        indices_ue = UE_Reported_Indices{u};
        W_all(:, :, u) = generateTypeIIPrecoder(cfg, indices_ue.i1, indices_ue.i2);
    end
    fprintf('W_all completed: [%d x %d x %d]\n\n', size(W_all));

end % end prepareData

function [W_pool, pool_indices] = buildRepresentativePool(W_all, config)

    % --- Read configuration fields ---
    numClusters    = getField(config, 'numClusters',    50);
    targetPoolSize = getField(config, 'targetPoolSize', 200);
    kmeansMaxIter  = getField(config, 'kmeansMaxIter',  100);

    [Num_Antennas, NumLayers, Num_UEs] = size(W_all);

    % --- Extract features: flatten precoder matrices and split into Real/Imag parts ---
    W_flat     = reshape(W_all, Num_Antennas * NumLayers, Num_UEs).';
    W_features = [real(W_flat), imag(W_flat)];

    % --- Run K-means with cosine distance to cluster UEs by beam direction similarity ---
    fprintf('Running K-means (%d clusters) on %d UEs...\n', numClusters, Num_UEs);
    [cluster_idx, ~] = kmeans(W_features, numClusters, ...
                            'Distance', 'cosine',    ...
                            'MaxIter',  kmeansMaxIter);

    % --- Uniformly sample UEs from each cluster ---
    ues_per_cluster = ceil(targetPoolSize / numClusters);

    pool_indices = [];
    for c = 1:numClusters
        members     = find(cluster_idx == c);
        members     = members(randperm(length(members)));       % Shuffle randomly
        num_to_pick = min(ues_per_cluster, length(members));
        pool_indices = [pool_indices; members(1:num_to_pick)]; 
    end

    W_pool = W_all(:, :, pool_indices);

    fprintf('Representative pool: %d UEs from %d clusters (target: %d).\n\n', ...
            length(pool_indices), numClusters, targetPoolSize);

end

function val = getField(s, fname, default)
    if isfield(s, fname)
        val = s.(fname);
    else
        val = default;
    end
end
