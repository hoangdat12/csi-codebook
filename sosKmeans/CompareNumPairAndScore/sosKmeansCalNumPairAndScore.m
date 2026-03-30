% =========================================================================
% SCRIPT: K-MEANS + SOS VS GREEDY MU-MIMO SCHEDULING FOR 60,000 UEs
% Antenna: 32T32R | Compare Group Sizes: 2 to 12
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
poolConfig.numClusters    = 500;   % Đổi về 500 giống cấu hình trước
poolConfig.targetPoolSize = 2000;  % Tăng số lượng đại diện lên 2000 UEs
poolConfig.kmeansMaxIter  = 100;

disp('--- Running K-Means to build Representative Pool ---');
[W_pool, pool_indices] = buildRepresentativePool(W_all, poolConfig);

% =========================================================================
% 4. PHY Layer Configuration — 32T32R
% =========================================================================
phyConfig = struct();
phyConfig.MCS               = 4;
phyConfig.SNR_dB            = 20;  % Đưa về 20dB giống cấu hình test cũ
phyConfig.PRBSet            = 0:272;
phyConfig.SubcarrierSpacing = 30;
phyConfig.NSizeGrid         = 273;

% =========================================================================
% 5. ĐÁNH GIÁ: K-MEANS + SOS (Lập lịch toàn bộ với Threshold)
% =========================================================================
disp(' ');
disp('=============================================================================================');
disp('   ĐÁNH GIÁ LẬP LỊCH: K-MEANS + SOS (THRESHOLD = 0.8 | POOL = 2000 UEs) ');
disp('=============================================================================================');

threshold = 0.8;
test_groupSizes = 2:8;    % Đã sửa thành chạy liên tục từ 2 đến 8
sos_maxIter = 50;         % Tăng lên 50 vòng lặp cho Pool 2000 UEs
sos_popSize = 20;         % Kích thước quần thể

num_test = length(test_groupSizes);

% Các mảng lưu kết quả SOS
sos_valid_counts = zeros(1, num_test);
sos_avg_valid = zeros(1, num_test);
sos_times = zeros(1, num_test);
max_groups_arr = zeros(1, num_test);

fprintf('%-12s | %-15s | %-15s | %-15s | %-15s\n', ...
    'Group Size', 'Nhóm Tối đa', 'Nhóm Đạt', 'Điểm TB', 'Thời gian (s)');
disp('---------------------------------------------------------------------------------------------');

for i = 1:num_test
    gs = test_groupSizes(i);
    max_groups_arr(i) = floor(size(W_pool, 3) / gs); 
    
    % --- CHẠY K-MEANS + SOS ---
    tic;
    [~, sos_valid_counts(i), sos_avg_valid(i), ~] = scheduleAllUEs_SOS(W_pool, gs, sos_maxIter, sos_popSize, threshold);
    sos_times(i) = toc;
    
    % In kết quả
    fprintf('%-12d | %-15d | %-15d | %-15.4f | %-15.4f\n', ...
        gs, max_groups_arr(i), sos_valid_counts(i), sos_avg_valid(i), sos_times(i));
end
disp('=============================================================================================');

% =========================================================================
% 6. VẼ ĐỒ THỊ ĐÁNH GIÁ K-MEANS + SOS
% =========================================================================
disp('--- Đang vẽ đồ thị đánh giá... ---');

% Đồ thị 1: Số lượng nhóm vượt Threshold (Capacity)
figure('Name', 'Số lượng nhóm đạt chuẩn', 'Position', [100, 100, 600, 450]);
bar(test_groupSizes, sos_valid_counts, 'FaceColor', [0.8500 0.3250 0.0980]); % Màu cam đỏ đặc trưng
title('Số lượng nhóm ghép thành công (K-Means + SOS | 2000 UEs)', 'FontSize', 13);
xlabel('Kích thước nhóm (Group Size)', 'FontSize', 11);
ylabel('Số lượng nhóm đạt', 'FontSize', 11);
grid on; set(gca, 'XTick', test_groupSizes);

% Thêm label số liệu lên đầu cột cho rõ ràng
for i = 1:num_test
    text(test_groupSizes(i), sos_valid_counts(i), num2str(sos_valid_counts(i)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontWeight', 'bold');
end

% Đồ thị 2: Điểm trực giao trung bình của các nhóm đạt
figure('Name', 'Điểm trực giao trung bình', 'Position', [750, 100, 600, 450]);
plot(test_groupSizes, sos_avg_valid, '-sr', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r');
yline(threshold, '--k', 'Threshold (0.8)', 'LineWidth', 1.5, 'LabelHorizontalAlignment', 'left');
title('Chất lượng trực giao (Điểm trung bình các nhóm đạt)', 'FontSize', 13);
xlabel('Kích thước nhóm (Group Size)', 'FontSize', 11);
ylabel('Chordal Distance', 'FontSize', 11);
grid on; set(gca, 'XTick', test_groupSizes); ylim([0.75 1.05]);

% Đồ thị 3: Thời gian thực thi
figure('Name', 'Thời gian thực thi', 'Position', [400, 600, 600, 450]);
plot(test_groupSizes, sos_times, '-^g', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'g');
title('Chi phí thời gian thuật toán SOS (Complexity)', 'FontSize', 13);
xlabel('Kích thước nhóm (Group Size)', 'FontSize', 11);
ylabel('Thời gian (giây)', 'FontSize', 11);
grid on; set(gca, 'XTick', test_groupSizes);

disp('--- Hoàn tất! ---');

% =========================================================================
% LOCAL FUNCTIONS 
% =========================================================================

% =========================================================================
% FITNESS FUNCTION 
% =========================================================================
function [validGroups, numValidGroups, avgValidScore, avgTotalScore] = scheduleAllUEs_SOS(W_matrix, groupSize, maxIter, popSize, threshold)
    % =========================================================================
    % Lập lịch MU-MIMO bằng thuật toán SOS dựa trên ma trận khoảng cách
    % Đã tối ưu hóa tính toán khoảng cách nội bộ để chạy mượt
    % =========================================================================
    [Num_Antennas, NumLayers, NUE] = size(W_matrix);
    numGroups = floor(NUE / groupSize);
    NUE_used = numGroups * groupSize; 
    
    % 1. TIỀN XỬ LÝ: Tính sẵn ma trận khoảng cách cho tất cả UEs trong Pool (CỰC NHANH)
    W_flat = reshape(W_matrix(:, :, 1:NUE_used), Num_Antennas * NumLayers, NUE_used);
    Gram = W_flat' * W_flat; 
    normsSq = sum(abs(W_flat).^2, 1);
    normProd = normsSq' * normsSq;
    distMat = 1 - (abs(Gram).^2) ./ normProd; % Ma trận khoảng cách NUE_used x NUE_used
    
    % 2. KHỞI TẠO QUẦN THỂ (ECOSYSTEM)
    eco = zeros(popSize, NUE_used);
    scores = zeros(popSize, 1);
    for i = 1:popSize
        eco(i, :) = randperm(NUE_used); % Sinh hoán vị ngẫu nhiên
        scores(i) = computeScheduleFitnessOptimize(eco(i, :), distMat, groupSize, numGroups);
    end
    [bestScore, bestIdx] = max(scores);
    bestOrganism = eco(bestIdx, :);
    
    % 3. VÒNG LẶP TỐI ƯU HÓA SOS
    for iter = 1:maxIter
        for i = 1:popSize
            % --- Mutualism Phase ---
            j = randi(popSize); while j == i, j = randi(popSize); end
            new_i = mutualismSwap(eco(i,:), eco(j,:));
            new_j = mutualismSwap(eco(j,:), eco(i,:));
            score_i = computeScheduleFitnessOptimize(new_i, distMat, groupSize, numGroups);
            score_j = computeScheduleFitnessOptimize(new_j, distMat, groupSize, numGroups);
            if score_i > scores(i), eco(i,:) = new_i; scores(i) = score_i; end
            if score_j > scores(j), eco(j,:) = new_j; scores(j) = score_j; end
            
            % --- Commensalism Phase ---
            j = randi(popSize); while j == i, j = randi(popSize); end
            new_i = commensalismSwap(eco(i,:), eco(bestIdx, :));
            score_i = computeScheduleFitnessOptimize(new_i, distMat, groupSize, numGroups);
            if score_i > scores(i), eco(i,:) = new_i; scores(i) = score_i; end
            
            % --- Parasitism Phase ---
            j = randi(popSize); while j == i, j = randi(popSize); end
            parasite_vec = parasitePerturb(eco(i,:));
            score_p = computeScheduleFitnessOptimize(parasite_vec, distMat, groupSize, numGroups);
            if score_p > scores(j), eco(j,:) = parasite_vec; scores(j) = score_p; end
        end
        % Cập nhật cá thể xuất sắc nhất
        [currentBestScore, currentBestIdx] = max(scores);
        if currentBestScore > bestScore
            bestScore = currentBestScore;
            bestIdx = currentBestIdx;
            bestOrganism = eco(bestIdx, :);
        end
    end
    
    % 4. CHIA NHÓM VÀ LỌC THEO THRESHOLD TỪ KẾT QUẢ TỐT NHẤT CỦA SOS
    validGroups = {}; validScores = []; allScores = [];
    numPairsPerGroup = groupSize * (groupSize - 1) / 2;
    
    for g = 1:numGroups
        idx = (g-1)*groupSize + 1 : g*groupSize;
        ueIdx = bestOrganism(idx);
        
        % Lấy nhanh điểm khoảng cách từ distMat đã tính ở bước 1
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
    
    % 5. TỔNG KẾT
    numValidGroups = length(validGroups);
    avgTotalScore = mean(allScores);
    if numValidGroups > 0
        avgValidScore = mean(validScores);
    else
        avgValidScore = 0;
    end
end

function score = computeScheduleFitnessOptimize(perm, distMat, groupSize, numGroups)
    totalDist = 0;
    numPairsPerGroup = groupSize * (groupSize - 1) / 2; % Combinations of 2 within the group size
    
    for g = 1:numGroups
        idx = (g-1)*groupSize + 1 : g*groupSize;
        ueIdx = perm(idx);
        groupDist = 0;
        
        % Iterate through all UE pairs in a group and accumulate the orthogonal distance
        for a = 1:groupSize-1
            for b = a+1:groupSize
                groupDist = groupDist + distMat(ueIdx(a), ueIdx(b));
            end
        end
        
        totalDist = totalDist + groupDist / numPairsPerGroup;
    end
    % Return the average score across all scheduled groups
    score = totalDist / numGroups;
end

% =========================================================================
% MUTATION / CROSSOVER OPERATORS
% =========================================================================
function newPerm = mutualismSwap(permA, permB)
    n = length(permA);
    pts = sort(randperm(n, 2));
    segment = permB(pts(1):pts(2)); % Extract a segment from organism B
    
    remaining = permA(~ismember(permA, segment));  % Filter out duplicate elements in A
    
    maxInsert = length(remaining) + 1; 
    insertPos = randi(maxInsert);
    
    % Insert B's segment into a random position within the remaining parts of A
    newPerm = [remaining(1:insertPos-1), segment, remaining(insertPos:end)];
    
    assert(length(newPerm) == n, 'Error: newPerm length mismatch after Swap!');
end

function newPerm = commensalismSwap(permA, ~)
    newPerm = permA;
    pts = randperm(length(permA), 2);
    
    % Swap the positions of any two elements (Point Mutation Operator)
    temp = newPerm(pts(1));
    newPerm(pts(1)) = newPerm(pts(2));
    newPerm(pts(2)) = temp;
end

function parasite = parasitePerturb(perm)
    parasite = perm;
    n = length(perm);
    pts = sort(randperm(n, 2));
    
    % Randomly scramble a sub-segment within the organism (Array Mutation Operator)
    parasite(pts(1):pts(2)) = parasite(pts(1) + randperm(pts(2)-pts(1)+1) - 1);
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