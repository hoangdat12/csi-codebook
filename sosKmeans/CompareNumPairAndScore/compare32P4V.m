% =========================================================================
% SCRIPT: SO SÁNH TRỰC TIẾP K-MEANS THUẦN VÀ K-MEANS + SOS (MU-MIMO)
% Dataset: 60,000 UEs (32T32R) -> Pool: 2000 UEs
% Group Sizes: 2 to 8 | Threshold: 0.8
% =========================================================================
clear; clc; close all;
setupPath();

% =========================================================================
% 1. Cấu hình Dữ liệu (32T32R)
% =========================================================================
prepareDataConfig = struct();
prepareDataConfig.Num_UEs           = 60000;
prepareDataConfig.N1                = 4;   % 8x4 = 32 Tx ports
prepareDataConfig.N2                = 4;
prepareDataConfig.O1                = 4;
prepareDataConfig.O2                = 4;
prepareDataConfig.L                 = 2;
prepareDataConfig.NumLayers         = 2;
prepareDataConfig.subbandAmplitude  = true;
prepareDataConfig.PhaseAlphabetSize = 8;

% =========================================================================
% 2. Khởi tạo dữ liệu
% =========================================================================
disp('--- Đang tạo dữ liệu cho 60,000 UEs (32T32R) ---');
[W_all, ~] = prepareData(prepareDataConfig);

% =========================================================================
% 3. Phân cụm K-Means tạo Representative Pool
% =========================================================================
poolConfig = struct();
poolConfig.numClusters    = 500;   
poolConfig.targetPoolSize = 5000;  
poolConfig.kmeansMaxIter  = 100;

disp('--- Đang chạy K-Means tạo Representative Pool (2000 UEs) ---');
[W_pool, pool_indices] = buildRepresentativePool(W_all, poolConfig);

% =========================================================================
% 4. SO SÁNH THUẬT TOÁN K-MEANS THUẦN VÀ K-MEANS + SOS
% =========================================================================
disp(' ');
disp('================================================================================================================');
disp('   SO SÁNH LẬP LỊCH: K-MEANS THUẦN vs K-MEANS + SOS (THRESHOLD = 0.8 | POOL = 2000 UEs) ');
disp('================================================================================================================');

threshold = 0.8;
test_groupSizes = 2:6; 
test_numClusters = 500; % Cho hàm KM Only
sos_maxIter = 50;       % Vòng lặp SOS
sos_popSize = 20;       % Quần thể SOS

num_test = length(test_groupSizes);

% Mảng lưu kết quả K-Means Only
km_valid = zeros(1, num_test);
km_score = zeros(1, num_test);
km_time  = zeros(1, num_test);

% Mảng lưu kết quả SOS
sos_valid = zeros(1, num_test);
sos_score = zeros(1, num_test);
sos_time  = zeros(1, num_test);

max_groups = zeros(1, num_test);

fprintf('%-10s | %-10s || %-10s | %-12s | %-10s || %-10s | %-12s | %-10s\n', ...
    'Group Size', 'Tối đa', 'KM Đạt', 'KM Score', 'KM Time(s)', 'SOS Đạt', 'SOS Score', 'SOS Time(s)');
disp('----------------------------------------------------------------------------------------------------------------');

for i = 1:num_test
    gs = test_groupSizes(i);
    max_groups(i) = floor(size(W_pool, 3) / gs); 
    
    % --- 1. CHẠY K-MEANS ONLY ---
    tic;
    [~, km_valid(i), km_score(i), ~] = scheduleAllUEsWithThreshold(W_pool, gs, test_numClusters, threshold);
    km_time(i) = toc;
    
    % --- 2. CHẠY K-MEANS + SOS ---
    tic;
    [~, sos_valid(i), sos_score(i), ~] = scheduleAllUEs_SOS(W_pool, gs, sos_maxIter, sos_popSize, threshold);
    sos_time(i) = toc;
    
    % In kết quả
    fprintf('%-10d | %-10d || %-10d | %-12.4f | %-10.4f || %-10d | %-12.4f | %-10.4f\n', ...
        gs, max_groups(i), km_valid(i), km_score(i), km_time(i), sos_valid(i), sos_score(i), sos_time(i));
end
disp('================================================================================================================');
% =========================================================================
% 5. VẼ ĐỒ THỊ SO SÁNH TRỰC QUAN (GỘP TRÊN CÙNG 1 FIGURE)
% =========================================================================
disp('--- Đang vẽ đồ thị so sánh... ---');

% Tạo 1 cửa sổ Figure lớn bao trùm cả 3 đồ thị
figure('Name', 'So sánh tổng quan: K-Means vs K-Means + SOS', 'Position', [100, 100, 1500, 450]);

% -------------------------------------------------------------------------
% Subplot 1: Số lượng nhóm vượt Threshold (Capacity)
% -------------------------------------------------------------------------
subplot(1, 3, 1);
b = bar(test_groupSizes, [km_valid' sos_valid'], 'grouped');
b(1).FaceColor = [0 0.4470 0.7410];     % Xanh (KM)
b(2).FaceColor = [0.8500 0.3250 0.0980];% Cam đỏ (SOS)
legend('K-Means Only', 'K-Means + SOS', 'Location', 'northeast');
title('Số lượng nhóm ghép thành công (\geq 0.8)', 'FontSize', 12);
xlabel('Kích thước nhóm (Group Size)', 'FontSize', 11);
ylabel('Số lượng nhóm đạt chuẩn', 'FontSize', 11);
grid on; set(gca, 'XTick', test_groupSizes);

% In số lên đầu cột (Lệch tọa độ X một chút cho từng cột)
offset = 0.15; 
for i = 1:num_test
    if km_valid(i) > 0
        text(test_groupSizes(i) - offset, km_valid(i), num2str(km_valid(i)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9);
    end
    if sos_valid(i) > 0
        text(test_groupSizes(i) + offset, sos_valid(i), num2str(sos_valid(i)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 9, 'FontWeight', 'bold');
    end
end

% -------------------------------------------------------------------------
% Subplot 2: Điểm trực giao trung bình của các nhóm đạt
% -------------------------------------------------------------------------
subplot(1, 3, 2);
plot(test_groupSizes, km_score, '-ob', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b'); hold on;
plot(test_groupSizes, sos_score, '-sr', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r');
% Lấy giá trị biến threshold tự động in lên đồ thị
yline(threshold, '--k', ['Threshold (' num2str(threshold) ')'], 'LineWidth', 1.5, 'LabelHorizontalAlignment', 'left');
legend('K-Means Only', 'K-Means + SOS', 'Location', 'northeast');
title('Chất lượng trực giao (Điểm trung bình)', 'FontSize', 12);
xlabel('Kích thước nhóm (Group Size)', 'FontSize', 11);
ylabel('Chordal Distance', 'FontSize', 11);
grid on; set(gca, 'XTick', test_groupSizes); ylim([0.75 1.05]);

% -------------------------------------------------------------------------
% Subplot 3: Thời gian thực thi
% -------------------------------------------------------------------------
subplot(1, 3, 3);
plot(test_groupSizes, km_time, '-ob', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b'); hold on;
plot(test_groupSizes, sos_time, '-sr', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r');
legend('K-Means Only', 'K-Means + SOS', 'Location', 'northwest');
title('Chi phí thời gian thuật toán (Complexity)', 'FontSize', 12);
xlabel('Kích thước nhóm (Group Size)', 'FontSize', 11);
ylabel('Thời gian (giây)', 'FontSize', 11);
grid on; set(gca, 'XTick', test_groupSizes);

disp('--- Hoàn tất chạy kịch bản gộp và vẽ đồ thị! ---');

% =========================================================================
% LOCAL FUNCTIONS (BAO GỒM CẢ K-MEANS VÀ SOS ĐÃ TỐI ƯU)
% =========================================================================

% -------------------------------------------------------------------------
% HÀM LẬP LỊCH: K-MEANS THUẦN
% -------------------------------------------------------------------------
function [validGroups, numValidGroups, avgValidScore, avgTotalScore] = scheduleAllUEsWithThreshold(W_matrix, groupSize, numClusters, threshold)
    [Num_Antennas, NumLayers, NUE] = size(W_matrix);
    maxPossibleGroups = floor(NUE / groupSize); 
    
    W_flat = reshape(W_matrix, Num_Antennas * NumLayers, NUE).';
    W_features = [real(W_flat), imag(W_flat)];
    [cluster_idx, ~] = kmeans(W_features, numClusters, 'Distance', 'cosine', 'MaxIter', 100);
    
    cluster_ues = cell(numClusters, 1);
    for c = 1:numClusters
        members = find(cluster_idx == c);
        cluster_ues{c} = members(randperm(length(members))); 
    end
    
    validGroups = {}; validScores = []; allScores = []; 
    upperTriIdx = triu(true(groupSize), 1);
    numPairs = groupSize * (groupSize - 1) / 2;
    
    for g = 1:maxPossibleGroups
        available_clusters = find(cellfun(@length, cluster_ues) > 0);
        if length(available_clusters) < groupSize, break; end
        
        selected_clusters = available_clusters(randperm(length(available_clusters), groupSize));
        current_group = zeros(1, groupSize);
        for i = 1:groupSize
            c = selected_clusters(i);
            current_group(i) = cluster_ues{c}(1);
            cluster_ues{c}(1) = []; 
        end
        
        W_group = reshape(W_matrix(:, :, current_group), Num_Antennas * NumLayers, groupSize);
        GramMatrix = W_group' * W_group; 
        normsSq = sum(abs(W_group).^2, 1); 
        normProdMatrix = normsSq' * normsSq; 
        distMatrix = 1 - (abs(GramMatrix).^2) ./ normProdMatrix;
        
        groupScore = sum(distMatrix(upperTriIdx)) / numPairs;
        allScores(end+1) = groupScore;
        
        if groupScore >= threshold
            validGroups{end+1} = current_group;
            validScores(end+1) = groupScore;
        end
    end
    
    numValidGroups = length(validGroups);
    if ~isempty(allScores), avgTotalScore = mean(allScores); else, avgTotalScore = 0; end
    if numValidGroups > 0, avgValidScore = mean(validScores); else, avgValidScore = 0; end
end

% -------------------------------------------------------------------------
% HÀM LẬP LỊCH: K-MEANS + SOS
% -------------------------------------------------------------------------
function [validGroups, numValidGroups, avgValidScore, avgTotalScore] = scheduleAllUEs_SOS(W_matrix, groupSize, maxIter, popSize, threshold)
    [Num_Antennas, NumLayers, NUE] = size(W_matrix);
    numGroups = floor(NUE / groupSize);
    NUE_used = numGroups * groupSize; 
    
    % Tiền xử lý ma trận khoảng cách cực nhanh
    W_flat = reshape(W_matrix(:, :, 1:NUE_used), Num_Antennas * NumLayers, NUE_used);
    Gram = W_flat' * W_flat; 
    normsSq = sum(abs(W_flat).^2, 1);
    normProd = normsSq' * normsSq;
    distMat = 1 - (abs(Gram).^2) ./ normProd; 
    
    eco = zeros(popSize, NUE_used);
    scores = zeros(popSize, 1);
    for i = 1:popSize
        eco(i, :) = randperm(NUE_used); 
        scores(i) = computeScheduleFitnessOptimize(eco(i, :), distMat, groupSize, numGroups);
    end
    [bestScore, bestIdx] = max(scores);
    bestOrganism = eco(bestIdx, :);
    
    for iter = 1:maxIter
        for i = 1:popSize
            % Mutualism
            j = randi(popSize); while j == i, j = randi(popSize); end
            new_i = mutualismSwap(eco(i,:), eco(j,:));
            new_j = mutualismSwap(eco(j,:), eco(i,:));
            score_i = computeScheduleFitnessOptimize(new_i, distMat, groupSize, numGroups);
            score_j = computeScheduleFitnessOptimize(new_j, distMat, groupSize, numGroups);
            if score_i > scores(i), eco(i,:) = new_i; scores(i) = score_i; end
            if score_j > scores(j), eco(j,:) = new_j; scores(j) = score_j; end
            
            % Commensalism
            j = randi(popSize); while j == i, j = randi(popSize); end
            new_i = commensalismSwap(eco(i,:), eco(bestIdx, :));
            score_i = computeScheduleFitnessOptimize(new_i, distMat, groupSize, numGroups);
            if score_i > scores(i), eco(i,:) = new_i; scores(i) = score_i; end
            
            % Parasitism
            j = randi(popSize); while j == i, j = randi(popSize); end
            parasite_vec = parasitePerturb(eco(i,:));
            score_p = computeScheduleFitnessOptimize(parasite_vec, distMat, groupSize, numGroups);
            if score_p > scores(j), eco(j,:) = parasite_vec; scores(j) = score_p; end
        end
        [currentBestScore, currentBestIdx] = max(scores);
        if currentBestScore > bestScore
            bestScore = currentBestScore;
            bestIdx = currentBestIdx;
            bestOrganism = eco(bestIdx, :);
        end
    end
    
    validGroups = {}; validScores = []; allScores = [];
    numPairsPerGroup = groupSize * (groupSize - 1) / 2;
    
    for g = 1:numGroups
        idx = (g-1)*groupSize + 1 : g*groupSize;
        ueIdx = bestOrganism(idx);
        
        groupDist = 0;
        for a = 1:groupSize-1
            for b = a+1:groupSize
                groupDist = groupDist + distMat(ueIdx(a), ueIdx(b));
            end
        end
        groupScore = groupDist / numPairsPerGroup;
        allScores(end+1) = groupScore;
        
        if groupScore >= threshold
            validGroups{end+1} = ueIdx;
            validScores(end+1) = groupScore;
        end
    end
    
    numValidGroups = length(validGroups);
    if ~isempty(allScores), avgTotalScore = mean(allScores); else, avgTotalScore = 0; end
    if numValidGroups > 0, avgValidScore = mean(validScores); else, avgValidScore = 0; end
end

% -------------------------------------------------------------------------
% HÀM HỖ TRỢ SOS
% -------------------------------------------------------------------------
function score = computeScheduleFitnessOptimize(perm, distMat, groupSize, numGroups)
    totalDist = 0;
    numPairsPerGroup = groupSize * (groupSize - 1) / 2; 
    for g = 1:numGroups
        idx = (g-1)*groupSize + 1 : g*groupSize;
        ueIdx = perm(idx);
        groupDist = 0;
        for a = 1:groupSize-1
            for b = a+1:groupSize
                groupDist = groupDist + distMat(ueIdx(a), ueIdx(b));
            end
        end
        totalDist = totalDist + groupDist / numPairsPerGroup;
    end
    score = totalDist / numGroups;
end

function newPerm = mutualismSwap(permA, permB)
    n = length(permA);
    pts = sort(randperm(n, 2));
    segment = permB(pts(1):pts(2)); 
    remaining = permA(~ismember(permA, segment));  
    maxInsert = length(remaining) + 1; 
    insertPos = randi(maxInsert);
    newPerm = [remaining(1:insertPos-1), segment, remaining(insertPos:end)];
end

function newPerm = commensalismSwap(permA, ~)
    newPerm = permA;
    pts = randperm(length(permA), 2);
    temp = newPerm(pts(1));
    newPerm(pts(1)) = newPerm(pts(2));
    newPerm(pts(2)) = temp;
end

function parasite = parasitePerturb(perm)
    parasite = perm;
    n = length(perm);
    pts = sort(randperm(n, 2));
    parasite(pts(1):pts(2)) = parasite(pts(1) + randperm(pts(2)-pts(1)+1) - 1);
end

% -------------------------------------------------------------------------
% HÀM TẠO DỮ LIỆU & TIỀN XỬ LÝ (GIỮ NGUYÊN)
% -------------------------------------------------------------------------
function [W_all, UE_Reported_Indices] = prepareData(config)
    Num_UEs           = getField(config, 'Num_UEs',           20000);
    N1                = getField(config, 'N1',                4);
    N2                = getField(config, 'N2',                1);
    O1                = getField(config, 'O1',                4);
    O2                = getField(config, 'O2',                1);
    L                 = getField(config, 'L',                 2);
    NumLayers         = getField(config, 'NumLayers',         1);
    subbandAmplitude  = getField(config, 'subbandAmplitude',  true);
    PhaseAlphabetSize = getField(config, 'PhaseAlphabetSize', 8);

    fprintf('Generating PMI configuration for %d UEs...\n', Num_UEs);
    UE_Reported_Indices = randomPMIConfig(Num_UEs, N1, N2, O1, O2, L, NumLayers, subbandAmplitude);

    cfg = struct();
    cfg.CodebookConfig.N1                = N1;
    cfg.CodebookConfig.N2                = N2;
    cfg.CodebookConfig.O1                = O1;
    cfg.CodebookConfig.O2                = O2;
    cfg.CodebookConfig.NumberOfBeams     = L;
    cfg.CodebookConfig.PhaseAlphabetSize = PhaseAlphabetSize;
    cfg.CodebookConfig.SubbandAmplitude  = subbandAmplitude;
    cfg.CodebookConfig.numLayers         = NumLayers;

    Num_Antennas = 2 * N1 * N2;
    W_all = zeros(Num_Antennas, NumLayers, Num_UEs);

    fprintf('Computing precoder matrix W_all...\n');
    for u = 1:Num_UEs
        indices_ue = UE_Reported_Indices{u};
        W_all(:, :, u) = generateTypeIIPrecoder(cfg, indices_ue.i1, indices_ue.i2);
    end
    fprintf('W_all completed: [%d x %d x %d]\n\n', size(W_all));
end

function [W_pool, pool_indices] = buildRepresentativePool(W_all, config)
    numClusters    = getField(config, 'numClusters',    50);
    targetPoolSize = getField(config, 'targetPoolSize', 200);
    kmeansMaxIter  = getField(config, 'kmeansMaxIter',  100);

    [Num_Antennas, NumLayers, Num_UEs] = size(W_all);
    W_flat     = reshape(W_all, Num_Antennas * NumLayers, Num_UEs).';
    W_features = [real(W_flat), imag(W_flat)];

    fprintf('Running K-means (%d clusters) on %d UEs...\n', numClusters, Num_UEs);
    [cluster_idx, ~] = kmeans(W_features, numClusters, 'Distance', 'cosine', 'MaxIter', kmeansMaxIter);

    ues_per_cluster = ceil(targetPoolSize / numClusters);
    pool_indices = [];
    for c = 1:numClusters
        members     = find(cluster_idx == c);
        members     = members(randperm(length(members)));       
        num_to_pick = min(ues_per_cluster, length(members));
        pool_indices = [pool_indices; members(1:num_to_pick)]; 
    end
    W_pool = W_all(:, :, pool_indices);
    fprintf('Representative pool: %d UEs from %d clusters (target: %d).\n\n', ...
            length(pool_indices), numClusters, targetPoolSize);
end

function val = getField(s, fname, default)
    if isfield(s, fname), val = s.(fname); else, val = default; end
end