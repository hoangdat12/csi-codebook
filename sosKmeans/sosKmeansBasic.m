% =========================================================================
% SCRIPT: K-MEANS + SOS VS GREEDY MU-MIMO SCHEDULING CHO 20,000 UEs
% So sánh Group Size: 4, 3, 2
% =========================================================================
clear; clc; close all;
setupPath();

% =========================================================================
% 1. Configuration for test
% =========================================================================
prepareDataConfig = struct();
prepareDataConfig.Num_UEs           = 60000;
prepareDataConfig.N1                = 4;
prepareDataConfig.N2                = 1;
prepareDataConfig.O1                = 4;
prepareDataConfig.O2                = 1;
prepareDataConfig.L                 = 2;
prepareDataConfig.NumLayers         = 1;
prepareDataConfig.subbandAmplitude  = true;
prepareDataConfig.PhaseAlphabetSize = 8;

% =========================================================================
% 2. Prepare W for Number of UE Test
% =========================================================================
disp('--- Đang tạo dữ liệu cho 60,000 UEs ---');
[W_all, UE_Reported_Indices] = prepareData(prepareDataConfig);

% =========================================================================
% 3. Pre-Processing (K-Means)
% =========================================================================
poolConfig = struct();
poolConfig.numClusters    = 50;
poolConfig.targetPoolSize = 200;
poolConfig.kmeansMaxIter  = 100;

disp('--- Đang chạy K-Means để tạo Representative Pool ---');
[W_pool, pool_indices] = buildRepresentativePool(W_all, poolConfig);

% =========================================================================
% 4. PHY Configuration chung
% =========================================================================
phyConfig = struct();
phyConfig.MCS = 9;
phyConfig.SNR_dB = 20;
phyConfig.PRBSet = 0:272;
phyConfig.SubcarrierSpacing = 30;
phyConfig.NSizeGrid = 273;

maxIter = 100; % Số vòng lặp tối đa của SOS

% Các biến lưu trữ kết quả để in bảng tổng kết
time_SOS = zeros(1, 3);
time_Greedy = zeros(1, 3);
score_SOS = zeros(1, 3);
score_Greedy = zeros(1, 3);
num_groups_SOS = zeros(1, 3);     % THÊM: Biến lưu số lượng nhóm SOS
num_groups_Greedy = zeros(1, 3);  % THÊM: Biến lưu số lượng nhóm Greedy

% =========================================================================
% 5. TEST KỊCH BẢN: GROUP SIZE = 4
% =========================================================================
disp(' ');
disp('############################################################');
disp('             KỊCH BẢN 1: MU-MIMO GROUP SIZE = 4             ');
disp('############################################################');

% --- Thuật toán SOS ---
tic;
[bestGroups_SOS4, score_SOS(1)] = sosMUMIMOScheduling(W_pool, 4, maxIter);
time_SOS(1) = toc;
num_groups_SOS(1) = length(bestGroups_SOS4); % Đếm số nhóm SOS ghép được

disp('--- Đang mô phỏng PHY Layer cho nhóm tốt nhất của SOS (4 UEs) ---');
[sBER4_1, sBER4_2, sBER4_3, sBER4_4] = simulateMuMimoGroup4UE(W_pool, bestGroups_SOS4, phyConfig);

% --- Thuật toán Greedy Tối ưu ---
% Nhận lại bestGroups_Greedy4 để đếm
[bestGroups_Greedy4, time_Greedy(1), score_Greedy(1), ~] = runGreedy4UEOptimize(W_pool, phyConfig, time_SOS(1), score_SOS(1));
num_groups_Greedy(1) = length(bestGroups_Greedy4); % Đếm số nhóm Greedy ghép được

% =========================================================================
% 6. TEST KỊCH BẢN: GROUP SIZE = 3
% =========================================================================
disp(' ');
disp('############################################################');
disp('             KỊCH BẢN 2: MU-MIMO GROUP SIZE = 3             ');
disp('############################################################');

% --- Thuật toán SOS ---
tic;
[bestGroups_SOS3, score_SOS(2)] = sosMUMIMOScheduling(W_pool, 3, maxIter);
time_SOS(2) = toc;
num_groups_SOS(2) = length(bestGroups_SOS3);

disp('--- Đang mô phỏng PHY Layer cho nhóm tốt nhất của SOS (3 UEs) ---');
[sBER3_1, sBER3_2, sBER3_3] = simulateMuMimoGroup3UE(W_pool, bestGroups_SOS3, phyConfig);

% --- Thuật toán Greedy Tối ưu ---
[bestGroups_Greedy3, time_Greedy(2), score_Greedy(2), ~] = runGreedy3UEOptimize(W_pool, phyConfig, time_SOS(2), score_SOS(2));
num_groups_Greedy(2) = length(bestGroups_Greedy3);

% =========================================================================
% 7. TEST KỊCH BẢN: GROUP SIZE = 2
% =========================================================================
disp(' ');
disp('############################################################');
disp('             KỊCH BẢN 3: MU-MIMO GROUP SIZE = 2             ');
disp('############################################################');

% --- Thuật toán SOS ---
tic;
[bestGroups_SOS2, score_SOS(3)] = sosMUMIMOScheduling(W_pool, 2, maxIter);
time_SOS(3) = toc;
num_groups_SOS(3) = length(bestGroups_SOS2);

disp('--- Đang mô phỏng PHY Layer cho nhóm tốt nhất của SOS (2 UEs) ---');
[sBER2_1, sBER2_2] = simulateMuMimoGroup2UE(W_pool, bestGroups_SOS2, phyConfig);

% --- Thuật toán Greedy Tối ưu ---
[bestGroups_Greedy2, time_Greedy(3), score_Greedy(3), ~] = runGreedy2UEOptimize(W_pool, phyConfig, time_SOS(3), score_SOS(3));
num_groups_Greedy(3) = length(bestGroups_Greedy2);

% =========================================================================
% 8. BẢNG TỔNG KẾT TOÀN BỘ
% =========================================================================
disp(' ');
disp('====================================================================================================');
disp('                              BẢNG TỔNG KẾT: SOS VS GREEDY (OPTIMIZED)                              ');
disp('====================================================================================================');
fprintf('%-12s | %-18s | %-30s | %-30s\n', 'Group Size', 'Số nhóm ghép được', 'Thời gian thực thi (giây)', 'Điểm Orthogonality (Score)');
fprintf('%-12s | %-8s | %-7s | %-14s | %-13s | %-14s | %-13s\n', '', 'SOS', 'Greedy', 'SOS', 'Greedy', 'SOS', 'Greedy');
disp('----------------------------------------------------------------------------------------------------');
fprintf('%-12s | %-8d | %-7d | %-14.4f | %-13.4f | %-14.4f | %-13.4f\n', '4 UEs', num_groups_SOS(1), num_groups_Greedy(1), time_SOS(1), time_Greedy(1), score_SOS(1), score_Greedy(1));
fprintf('%-12s | %-8d | %-7d | %-14.4f | %-13.4f | %-14.4f | %-13.4f\n', '3 UEs', num_groups_SOS(2), num_groups_Greedy(2), time_SOS(2), time_Greedy(2), score_SOS(2), score_Greedy(2));
fprintf('%-12s | %-8d | %-7d | %-14.4f | %-13.4f | %-14.4f | %-13.4f\n', '2 UEs', num_groups_SOS(3), num_groups_Greedy(3), time_SOS(3), time_Greedy(3), score_SOS(3), score_Greedy(3));
disp('====================================================================================================');

% =========================================================================
% LOCAL FUNCTIONS 
% =========================================================================
function [bestGroups, bestScore] = sosMUMIMOScheduling(W_all, groupSize, maxIter)
    NUE = size(W_all, 3);
    
    % --- TỐI ƯU 1: GIẢM POPULATION SIZE ---
    % Vì K-Means đã gom cụm tốt, ta không cần quá nhiều "sinh vật"
    popSize = 30; 
    
    numGroups = floor(NUE / groupSize);
    population = zeros(popSize, NUE);
    for p = 1:popSize
        population(p, :) = randperm(NUE);
    end
    
    % --- TỐI ƯU 2: PRECOMPUTED DISTANCE MATRIX ---
    % Tính khoảng cách cho mọi cặp UE một lần duy nhất
    disp('      [SOS] Đang tính Ma trận khoảng cách...');
    distMat = zeros(NUE, NUE);
    for i = 1:NUE-1
        for j = i+1:NUE
            distMat(i, j) = chordalDistance(W_all(:,:,i), W_all(:,:,j));
            distMat(j, i) = distMat(i, j); % Ma trận đối xứng
        end
    end
    
    % Truyền distMat vào hàm tính Fitness thay vì W_all
    fitnessFunc = @(perm) computeScheduleFitnessOptimize(perm, distMat, groupSize, numGroups);
    
    % Tính Fitness ban đầu cho toàn bộ quần thể
    fitness = zeros(popSize, 1);
    for p = 1:popSize
        fitness(p) = fitnessFunc(population(p, :));
    end
    
    [bestScore, bestIdx] = max(fitness);
    bestPerm = population(bestIdx, :);
    
    % --- TỐI ƯU 3: EARLY STOPPING (Dừng Sớm) ---
    no_improve_counter = 0;
    max_no_improve = 15; % Dừng nếu 15 vòng liên tiếp không cải thiện điểm
    
    disp('      [SOS] Bắt đầu chạy các thế hệ tiến hóa...');
    for iter = 1:maxIter
        prevBestScore = bestScore;
        
        % ===== MUTUALISM PHASE =====
        for i = 1:popSize
            j = randi(popSize);
            while j == i, j = randi(popSize); end
            
            newOrgI = mutualismSwap(population(i,:), population(j,:));
            newOrgJ = mutualismSwap(population(j,:), population(i,:));
            
            fI = fitnessFunc(newOrgI);
            if fI > fitness(i)
                population(i,:) = newOrgI;
                fitness(i) = fI;
            end
            
            fJ = fitnessFunc(newOrgJ);
            if fJ > fitness(j)
                population(j,:) = newOrgJ;
                fitness(j) = fJ;
            end
        end
        
        % ===== COMMENSALISM PHASE =====
        for i = 1:popSize
            j = randi(popSize);
            while j == i, j = randi(popSize); end
            
            newOrg = commensalismSwap(population(i,:), population(j,:));
            fNew = fitnessFunc(newOrg);
            if fNew > fitness(i)
                population(i,:) = newOrg;
                fitness(i) = fNew;
            end
        end
        
        % ===== PARASITISM PHASE =====
        for i = 1:popSize
            parasite = parasitePerturb(population(i,:));
            host = randi(popSize);
            while host == i, host = randi(popSize); end
            
            fParasite = fitnessFunc(parasite);
            if fParasite > fitness(host)
                population(host,:) = parasite;
                fitness(host) = fParasite;
            end
        end
        
        % Cập nhật điểm tốt nhất
        [curBest, curIdx] = max(fitness);
        if curBest > bestScore
            bestScore = curBest;
            bestPerm = population(curIdx, :);
            no_improve_counter = 0; % Reset bộ đếm nếu có cải thiện
        else
            no_improve_counter = no_improve_counter + 1;
        end
        
        % Kiểm tra điều kiện dừng sớm
        if no_improve_counter >= max_no_improve
            fprintf('      [SOS] Thuật toán hội tụ sớm tại vòng lặp %d (Điểm: %.4f)\n', iter, bestScore);
            break;
        end
    end
    
    % Trích xuất danh sách nhóm tốt nhất
    bestGroups = cell(numGroups, 1);
    for g = 1:numGroups
        idx = (g-1)*groupSize + 1 : g*groupSize;
        bestGroups{g} = bestPerm(idx);
    end
end

% =========================================================================
% HÀM FITNESS ĐƯỢC TỐI ƯU HÓA (Tra cứu ma trận thay vì gọi hàm)
% =========================================================================
function score = computeScheduleFitnessOptimize(perm, distMat, groupSize, numGroups)
    totalDist = 0;
    numPairsPerGroup = groupSize * (groupSize - 1) / 2;
    
    for g = 1:numGroups
        idx = (g-1)*groupSize + 1 : g*groupSize;
        ueIdx = perm(idx);
        groupDist = 0;
        
        % Tra cứu trực tiếp từ distMat, bỏ qua hàm chordalDistance
        for a = 1:groupSize-1
            for b = a+1:groupSize
                groupDist = groupDist + distMat(ueIdx(a), ueIdx(b));
            end
        end
        
        totalDist = totalDist + groupDist / numPairsPerGroup;
    end
    score = totalDist / numGroups;
end

% =========================================================================
% CÁC HÀM ĐỘT BIẾN / LAI GHÉP (Giữ nguyên)
% =========================================================================
function newPerm = mutualismSwap(permA, permB)
    n = length(permA);
    pts = sort(randperm(n, 2));
    segment = permB(pts(1):pts(2));
    
    remaining = permA(~ismember(permA, segment));  
    
    maxInsert = length(remaining) + 1; 
    insertPos = randi(maxInsert);
    
    newPerm = [remaining(1:insertPos-1), segment, remaining(insertPos:end)];
    
    assert(length(newPerm) == n, 'Lỗi: Chiều dài newPerm bị sai lệch sau khi Swap!');
end

function newPerm = commensalismSwap(permA, ~)
    newPerm = permA;
    pts = randperm(length(permA), 2);
    % Đổi chỗ 2 phần tử
    temp = newPerm(pts(1));
    newPerm(pts(1)) = newPerm(pts(2));
    newPerm(pts(2)) = temp;
end

function parasite = parasitePerturb(perm)
    parasite = perm;
    n = length(perm);
    pts = sort(randperm(n, 2));
    % Đảo lộn ngẫu nhiên một đoạn
    parasite(pts(1):pts(2)) = parasite(pts(1) + randperm(pts(2)-pts(1)+1) - 1);
end

function [W_all, UE_Reported_Indices] = prepareData(config)
% prepareData - Tạo dữ liệu precoder W_all và PMI indices cho tất cả UE
%
% Input:
%   config - struct chứa các cấu hình, gồm các trường:
%       .Num_UEs           - Số lượng UE (mặc định: 20000)
%       .N1                - Số phần tử theo chiều ngang (mặc định: 4)
%       .N2                - Số phần tử theo chiều dọc (mặc định: 1)
%       .O1                - Oversampling chiều ngang (mặc định: 4)
%       .O2                - Oversampling chiều dọc (mặc định: 1)
%       .L                 - Số lượng chùm tia / NumberOfBeams (mặc định: 2)
%       .NumLayers         - Số layer / RI (mặc định: 1)
%       .subbandAmplitude  - Bật/tắt subband amplitude (mặc định: true)
%       .PhaseAlphabetSize - Kích thước bảng chữ cái pha NPSK (mặc định: 8)
%
% Output:
%   W_all               - Ma trận precoder [Num_Antennas x NumLayers x Num_UEs]
%   UE_Reported_Indices - Cell array chứa PMI indices {i1, i2} của từng UE

% --- Đọc cấu hình (có giá trị mặc định) ---
Num_UEs           = getField(config, 'Num_UEs',           20000);
N1                = getField(config, 'N1',                4);
N2                = getField(config, 'N2',                1);
O1                = getField(config, 'O1',                4);
O2                = getField(config, 'O2',                1);
L                 = getField(config, 'L',                 2);
NumLayers         = getField(config, 'NumLayers',         1);
subbandAmplitude  = getField(config, 'subbandAmplitude',  true);
PhaseAlphabetSize = getField(config, 'PhaseAlphabetSize', 8);

% --- Tạo PMI indices ngẫu nhiên cho tất cả UE ---
fprintf('Đang tạo cấu hình PMI cho %d UEs...\n', Num_UEs);
UE_Reported_Indices = randomPMIConfig(Num_UEs, N1, N2, O1, O2, L, NumLayers, subbandAmplitude);

% --- Xây dựng struct cfg cho generateTypeIIPrecoder ---
cfg = struct();
cfg.CodebookConfig.N1                = N1;
cfg.CodebookConfig.N2                = N2;
cfg.CodebookConfig.O1                = O1;
cfg.CodebookConfig.O2                = O2;
cfg.CodebookConfig.NumberOfBeams     = L;
cfg.CodebookConfig.PhaseAlphabetSize = PhaseAlphabetSize;
cfg.CodebookConfig.SubbandAmplitude  = subbandAmplitude;
cfg.CodebookConfig.numLayers         = NumLayers;

% --- Tính toán W_all ---
Num_Antennas = 2 * N1 * N2;
W_all = zeros(Num_Antennas, NumLayers, Num_UEs);

fprintf('Đang tính toán ma trận Precoder W_all...\n');
for u = 1:Num_UEs
    indices_ue = UE_Reported_Indices{u};
    W_all(:, :, u) = generateTypeIIPrecoder(cfg, indices_ue.i1, indices_ue.i2);
end
fprintf('Hoàn thành W_all: [%d x %d x %d]\n\n', size(W_all));

end % end prepareData

function [W_pool, pool_indices] = buildRepresentativePool(W_all, config)
    % buildRepresentativePool - Chọn tập UE đại diện bằng K-means clustering
    %
    % Ý tưởng: Gom W_all thành numClusters cụm theo hướng beam (cosine distance),
    %           sau đó lấy mẫu đều từ mỗi cụm để tạo một pool nhỏ nhưng
    %           bao phủ đủ đa dạng không gian beam.
    %
    % Input:
    %   W_all  - Ma trận precoder [Num_Antennas x NumLayers x Num_UEs]
    %   config - struct với các trường:
    %       .numClusters     - Số cụm K-means (mặc định: 50)
    %       .targetPoolSize  - Kích thước pool mong muốn (mặc định: 200)
    %       .kmeansMaxIter   - Số vòng lặp tối đa K-means (mặc định: 100)
    %
    % Output:
    %   W_pool       - Precoder của UE được chọn [Num_Antennas x NumLayers x PoolSize]
    %   pool_indices - Chỉ số UE được chọn trong W_all [PoolSize x 1]

    % --- Đọc config ---
    numClusters    = getField(config, 'numClusters',    50);
    targetPoolSize = getField(config, 'targetPoolSize', 200);
    kmeansMaxIter  = getField(config, 'kmeansMaxIter',  100);

    [Num_Antennas, NumLayers, Num_UEs] = size(W_all);

    % --- Trích xuất đặc trưng: flatten + tách Real/Imag ---
    W_flat     = reshape(W_all, Num_Antennas * NumLayers, Num_UEs).';
    W_features = [real(W_flat), imag(W_flat)];

    % --- K-means theo cosine distance để gom UE cùng hướng beam ---
    fprintf('Đang chạy K-means (%d cụm) trên %d UEs...\n', numClusters, Num_UEs);
    [cluster_idx, ~] = kmeans(W_features, numClusters, ...
                            'Distance', 'cosine',    ...
                            'MaxIter',  kmeansMaxIter);

    % --- Lấy mẫu đều từ mỗi cụm ---
    ues_per_cluster = ceil(targetPoolSize / numClusters);

    pool_indices = [];
    for c = 1:numClusters
        members     = find(cluster_idx == c);
        members     = members(randperm(length(members)));       % Trộn ngẫu nhiên
        num_to_pick = min(ues_per_cluster, length(members));
        pool_indices = [pool_indices; members(1:num_to_pick)];  %#ok<AGROW>
    end

    W_pool = W_all(:, :, pool_indices);

    fprintf('Pool đại diện: %d UEs từ %d cụm (mục tiêu: %d).\n\n', ...
            length(pool_indices), numClusters, targetPoolSize);

end

function [BER1, BER2, BER3, BER4] = simulateMuMimoGroup4UE(W_pool, bestGroups_SOS, config)
    disp('--- Bắt đầu mô phỏng truyền MU-MIMO cho nhóm 4 UEs ---');

    % 1. Lấy index của 4 UEs trong nhóm đầu tiên từ thuật toán SOS
    best_group = bestGroups_SOS{1}; 
    ue1_idx = best_group(1);
    ue2_idx = best_group(2);
    ue3_idx = best_group(3);
    ue4_idx = best_group(4);

    % 2. Trích xuất Precoder cho 4 UEs
    W1 = W_pool(:, :, ue1_idx);
    W2 = W_pool(:, :, ue2_idx);
    W3 = W_pool(:, :, ue3_idx);
    W4 = W_pool(:, :, ue4_idx);

    fprintf('Đã chọn UE %d, %d, %d, %d từ Sub-pool để truyền đi.\n', ue1_idx, ue2_idx, ue3_idx, ue4_idx);

    % 3. Cấu hình PDSCH và Carrier cơ bản từ biến config
    nLayers = size(W1, 2); 
    MCS = config.MCS; 

    pdsch = customPDSCHConfig(); 
    pdsch.DMRS.DMRSConfigurationType = 1;
    pdsch.DMRS.DMRSAdditionalPosition = 1;
    pdsch.NumLayers = nLayers;
    pdsch.PRBSet = config.PRBSet;
    pdsch.DMRS.DMRSLength = 2; % Bắt buộc mở rộng độ dài DMRS = 2 cho MU-MIMO 4 UEs

    carrier = nrCarrierConfig;
    carrier.SubcarrierSpacing = config.SubcarrierSpacing;
    carrier.NSizeGrid = config.NSizeGrid; 

    % 4. Gọi hàm muMimo
    SNR_dB = config.SNR_dB; 
    fprintf('Đang chạy hàm muMimo với SNR = %d dB...\n', SNR_dB);

    [BER1, BER2, BER3, BER4] = muMimo4UE(carrier, pdsch, W1, W2, W3, W4, MCS, SNR_dB);

    % 5. Hiển thị kết quả BER
    fprintf('\n================ KẾT QUẢ TRUYỀN DỮ LIỆU ================\n');
    fprintf('BER của UE 1 (ID: %d): %.6f\n', ue1_idx, BER1);
    fprintf('BER của UE 2 (ID: %d): %.6f\n', ue2_idx, BER2);
    fprintf('BER của UE 3 (ID: %d): %.6f\n', ue3_idx, BER3);
    fprintf('BER của UE 4 (ID: %d): %.6f\n', ue4_idx, BER4);
    disp('========================================================');
end

function [BER1, BER2, BER3] = simulateMuMimoGroup3UE(W_pool, bestGroups_SOS, config)
    disp('--- Bắt đầu mô phỏng truyền MU-MIMO cho nhóm 3 UEs ---');

    % 1. Lấy index của 3 UEs trong nhóm đầu tiên từ thuật toán SOS
    best_group = bestGroups_SOS{1}; 
    ue1_idx = best_group(1);
    ue2_idx = best_group(2);
    ue3_idx = best_group(3);

    % 2. Trích xuất Precoder cho 3 UEs
    W1 = W_pool(:, :, ue1_idx);
    W2 = W_pool(:, :, ue2_idx);
    W3 = W_pool(:, :, ue3_idx);

    fprintf('Đã chọn UE %d, %d, %d từ Sub-pool để truyền đi.\n', ue1_idx, ue2_idx, ue3_idx);

    % 3. Cấu hình PDSCH và Carrier cơ bản từ biến config
    nLayers = size(W1, 2); 
    MCS = config.MCS; 

    pdsch = customPDSCHConfig(); 
    pdsch.DMRS.DMRSConfigurationType = 1;
    pdsch.DMRS.DMRSAdditionalPosition = 1;
    pdsch.NumLayers = nLayers;
    pdsch.PRBSet = config.PRBSet;
    pdsch.DMRS.DMRSLength = 2; % Giữ DMRS = 2 để hỗ trợ đủ số cổng cho 3 UEs

    carrier = nrCarrierConfig;
    carrier.SubcarrierSpacing = config.SubcarrierSpacing;
    carrier.NSizeGrid = config.NSizeGrid; 

    % 4. Gọi hàm muMimo3UE
    SNR_dB = config.SNR_dB; 
    fprintf('Đang chạy hàm muMimo3UE với SNR = %d dB...\n', SNR_dB);

    [BER1, BER2, BER3] = muMimo3UE(carrier, pdsch, W1, W2, W3, MCS, SNR_dB);

    % 5. Hiển thị kết quả BER
    fprintf('\n================ KẾT QUẢ TRUYỀN DỮ LIỆU ================\n');
    fprintf('BER của UE 1 (ID: %d): %.6f\n', ue1_idx, BER1);
    fprintf('BER của UE 2 (ID: %d): %.6f\n', ue2_idx, BER2);
    fprintf('BER của UE 3 (ID: %d): %.6f\n', ue3_idx, BER3);
    disp('========================================================');
end

function [BER1, BER2] = simulateMuMimoGroup2UE(W_pool, bestGroups_SOS, config)
    disp('--- Bắt đầu mô phỏng truyền MU-MIMO cho nhóm 2 UEs ---');

    % 1. Lấy index của 2 UEs trong nhóm đầu tiên từ thuật toán SOS
    best_group = bestGroups_SOS{1}; 
    ue1_idx = best_group(1);
    ue2_idx = best_group(2);

    % 2. Trích xuất Precoder cho 2 UEs
    W1 = W_pool(:, :, ue1_idx);
    W2 = W_pool(:, :, ue2_idx);

    fprintf('Đã chọn UE %d, %d từ Sub-pool để truyền đi.\n', ue1_idx, ue2_idx);

    % 3. Cấu hình PDSCH và Carrier cơ bản từ biến config
    nLayers = size(W1, 2); 
    MCS = config.MCS; 

    pdsch = customPDSCHConfig(); 
    pdsch.DMRS.DMRSConfigurationType = 1;
    pdsch.DMRS.DMRSAdditionalPosition = 1;
    pdsch.NumLayers = nLayers;
    pdsch.PRBSet = config.PRBSet;
    pdsch.DMRS.DMRSLength = 1; % Với 2 UEs (tối đa 4 ports), DMRS Length = 1 là đủ

    carrier = nrCarrierConfig;
    carrier.SubcarrierSpacing = config.SubcarrierSpacing;
    carrier.NSizeGrid = config.NSizeGrid; 

    % 4. Gọi hàm muMimo2UE
    SNR_dB = config.SNR_dB; 
    fprintf('Đang chạy hàm muMimo2UE với SNR = %d dB...\n', SNR_dB);

    [BER1, BER2] = muMimo2UE(carrier, pdsch, W1, W2, MCS, SNR_dB);

    % 5. Hiển thị kết quả BER
    fprintf('\n================ KẾT QUẢ TRUYỀN DỮ LIỆU ================\n');
    fprintf('BER của UE 1 (ID: %d): %.6f\n', ue1_idx, BER1);
    fprintf('BER của UE 2 (ID: %d): %.6f\n', ue2_idx, BER2);
    disp('========================================================');
end

function val = getField(s, fname, default)
    if isfield(s, fname)
        val = s.(fname);
    else
        val = default;
    end
end

function [BER1, BER2, BER3, BER4] = muMimo4UE(...
    carrier, basePDSCHConfig, ...
    UE1_W, UE2_W, UE3_W, UE4_W, MCS, SNR_dB ...
)

    nLayers = size(UE1_W, 2);

    % -----------------------------------------------------------------
    % Cấu hình 4 UEs độc lập
    % -----------------------------------------------------------------
    pdsch1 = basePDSCHConfig;
    if pdsch1.NumLayers == 1, pdsch1.DMRS.DMRSPortSet = 0; else, pdsch1.DMRS.DMRSPortSet = [0, 1]; end
    pdsch1 = pdsch1.setMCS(MCS);
    [~, pInfo1] = nrPDSCHIndices(carrier, pdsch1);
    TBS1 = nrTBS(pdsch1.Modulation, pdsch1.NumLayers, length(pdsch1.PRBSet), pInfo1.NREPerPRB, pdsch1.TargetCodeRate);
    inputBits1 = randi([0 1], TBS1, 1);

    pdsch2 = basePDSCHConfig;
    if pdsch2.NumLayers == 1, pdsch2.DMRS.DMRSPortSet = 2; else, pdsch2.DMRS.DMRSPortSet = [2, 3]; end
    pdsch2 = pdsch2.setMCS(MCS);
    [~, pInfo2] = nrPDSCHIndices(carrier, pdsch2);
    TBS2 = nrTBS(pdsch2.Modulation, pdsch2.NumLayers, length(pdsch2.PRBSet), pInfo2.NREPerPRB, pdsch2.TargetCodeRate);
    inputBits2 = randi([0 1], TBS2, 1);

    pdsch3 = basePDSCHConfig;
    if pdsch3.NumLayers == 1, pdsch3.DMRS.DMRSPortSet = 4; else, pdsch3.DMRS.DMRSPortSet = [4, 5]; end
    pdsch3 = pdsch3.setMCS(MCS);
    [~, pInfo3] = nrPDSCHIndices(carrier, pdsch3);
    TBS3 = nrTBS(pdsch3.Modulation, pdsch3.NumLayers, length(pdsch3.PRBSet), pInfo3.NREPerPRB, pdsch3.TargetCodeRate);
    inputBits3 = randi([0 1], TBS3, 1);

    pdsch4 = basePDSCHConfig;
    if pdsch4.NumLayers == 1, pdsch4.DMRS.DMRSPortSet = 6; else, pdsch4.DMRS.DMRSPortSet = [6, 7]; end
    pdsch4 = pdsch4.setMCS(MCS);
    [~, pInfo4] = nrPDSCHIndices(carrier, pdsch4);
    TBS4 = nrTBS(pdsch4.Modulation, pdsch4.NumLayers, length(pdsch4.PRBSet), pInfo4.NREPerPRB, pdsch4.TargetCodeRate);
    inputBits4 = randi([0 1], TBS4, 1);

    % -----------------------------------------------------------------
    % Tính toán tiền mã hóa MMSE
    % -----------------------------------------------------------------
    % LÝ THUYẾT: Áp dụng Hermitian Transpose (') để tính Kênh truyền H
    H_composite = [UE1_W'; UE2_W'; UE3_W'; UE4_W'];
    numTx = size(UE1_W, 1);
    W_total_T = getMMSEPrecoder(H_composite, SNR_dB, numTx);

    W1_transposed = W_total_T(1:nLayers, :);
    W2_transposed = W_total_T(nLayers+1:2*nLayers, :);
    W3_transposed = W_total_T(2*nLayers+1:3*nLayers, :);
    W4_transposed = W_total_T(3*nLayers+1:end, :);

    % -----------------------------------------------------------------
    % Điều chế và Tiền mã hóa (PDSCH & DMRS)
    % -----------------------------------------------------------------
    [sym1, ind1] = PDSCHEncode(pdsch1, carrier, inputBits1);
    [antsym1, antind1] = nrPDSCHPrecode(carrier, sym1, ind1, W1_transposed);
    dSym1 = nrPDSCHDMRS(carrier, pdsch1); dInd1 = nrPDSCHDMRSIndices(carrier, pdsch1);
    [dAntSym1, dAntInd1] = nrPDSCHPrecode(carrier, dSym1, dInd1, W1_transposed);

    [sym2, ind2] = PDSCHEncode(pdsch2, carrier, inputBits2);
    [antsym2, antind2] = nrPDSCHPrecode(carrier, sym2, ind2, W2_transposed);
    dSym2 = nrPDSCHDMRS(carrier, pdsch2); dInd2 = nrPDSCHDMRSIndices(carrier, pdsch2);
    [dAntSym2, dAntInd2] = nrPDSCHPrecode(carrier, dSym2, dInd2, W2_transposed);

    [sym3, ind3] = PDSCHEncode(pdsch3, carrier, inputBits3);
    [antsym3, antind3] = nrPDSCHPrecode(carrier, sym3, ind3, W3_transposed);
    dSym3 = nrPDSCHDMRS(carrier, pdsch3); dInd3 = nrPDSCHDMRSIndices(carrier, pdsch3);
    [dAntSym3, dAntInd3] = nrPDSCHPrecode(carrier, dSym3, dInd3, W3_transposed);

    [sym4, ind4] = PDSCHEncode(pdsch4, carrier, inputBits4);
    [antsym4, antind4] = nrPDSCHPrecode(carrier, sym4, ind4, W4_transposed);
    dSym4 = nrPDSCHDMRS(carrier, pdsch4); dInd4 = nrPDSCHDMRSIndices(carrier, pdsch4);
    [dAntSym4, dAntInd4] = nrPDSCHPrecode(carrier, dSym4, dInd4, W4_transposed);

    % -----------------------------------------------------------------
    % Resource Mapping & OFDM
    % -----------------------------------------------------------------
    numPorts = size(W1_transposed, 2);
    txGrid = nrResourceGrid(carrier, numPorts);

    txGrid(antind1) = txGrid(antind1) + antsym1;
    txGrid(dAntInd1) = txGrid(dAntInd1) + dAntSym1;

    txGrid(antind2) = txGrid(antind2) + antsym2;
    txGrid(dAntInd2) = txGrid(dAntInd2) + dAntSym2;

    txGrid(antind3) = txGrid(antind3) + antsym3;
    txGrid(dAntInd3) = txGrid(dAntInd3) + dAntSym3;

    txGrid(antind4) = txGrid(antind4) + antsym4;
    txGrid(dAntInd4) = txGrid(dAntInd4) + dAntSym4;

    txWaveform = nrOFDMModulate(carrier, txGrid);

    % -----------------------------------------------------------------
    % Channel (Mô phỏng kênh truyền vật lý)
    % -----------------------------------------------------------------
    % LÝ THUYẾT: Tín hiệu thu = Tín hiệu phát * Kênh truyền H + Nhiễu (AWGN)
    rxWaveformUE1 = awgn(txWaveform * H_composite(1, :).', SNR_dB, 'measured');
    rxWaveformUE2 = awgn(txWaveform * H_composite(2, :).', SNR_dB, 'measured');
    rxWaveformUE3 = awgn(txWaveform * H_composite(3, :).', SNR_dB, 'measured');
    rxWaveformUE4 = awgn(txWaveform * H_composite(4, :).', SNR_dB, 'measured');

    % -----------------------------------------------------------------
    % RX & Tính BER
    % -----------------------------------------------------------------
    rxBits1 = rxPDSCHDecode(carrier, pdsch1, rxWaveformUE1, txWaveform, TBS1);
    BER1 = biterr(double(inputBits1), double(rxBits1)) / TBS1;

    rxBits2 = rxPDSCHDecode(carrier, pdsch2, rxWaveformUE2, txWaveform, TBS2);
    BER2 = biterr(double(inputBits2), double(rxBits2)) / TBS2;

    rxBits3 = rxPDSCHDecode(carrier, pdsch3, rxWaveformUE3, txWaveform, TBS3);
    BER3 = biterr(double(inputBits3), double(rxBits3)) / TBS3;

    rxBits4 = rxPDSCHDecode(carrier, pdsch4, rxWaveformUE4, txWaveform, TBS4);
    BER4 = biterr(double(inputBits4), double(rxBits4)) / TBS4;
end

function [BER1, BER2, BER3] = muMimo3UE(...
    carrier, basePDSCHConfig, ...
    UE1_W, UE2_W, UE3_W, MCS, SNR_dB ...
)

    nLayers = size(UE1_W, 2);

    % -----------------------------------------------------------------
    % Cấu hình 3 UEs độc lập
    % -----------------------------------------------------------------
    pdsch1 = basePDSCHConfig;
    if pdsch1.NumLayers == 1, pdsch1.DMRS.DMRSPortSet = 0; else, pdsch1.DMRS.DMRSPortSet = [0, 1]; end
    pdsch1 = pdsch1.setMCS(MCS);
    [~, pInfo1] = nrPDSCHIndices(carrier, pdsch1);
    TBS1 = nrTBS(pdsch1.Modulation, pdsch1.NumLayers, length(pdsch1.PRBSet), pInfo1.NREPerPRB, pdsch1.TargetCodeRate);
    inputBits1 = randi([0 1], TBS1, 1);

    pdsch2 = basePDSCHConfig;
    if pdsch2.NumLayers == 1, pdsch2.DMRS.DMRSPortSet = 2; else, pdsch2.DMRS.DMRSPortSet = [2, 3]; end
    pdsch2 = pdsch2.setMCS(MCS);
    [~, pInfo2] = nrPDSCHIndices(carrier, pdsch2);
    TBS2 = nrTBS(pdsch2.Modulation, pdsch2.NumLayers, length(pdsch2.PRBSet), pInfo2.NREPerPRB, pdsch2.TargetCodeRate);
    inputBits2 = randi([0 1], TBS2, 1);

    pdsch3 = basePDSCHConfig;
    if pdsch3.NumLayers == 1, pdsch3.DMRS.DMRSPortSet = 4; else, pdsch3.DMRS.DMRSPortSet = [4, 5]; end
    pdsch3 = pdsch3.setMCS(MCS);
    [~, pInfo3] = nrPDSCHIndices(carrier, pdsch3);
    TBS3 = nrTBS(pdsch3.Modulation, pdsch3.NumLayers, length(pdsch3.PRBSet), pInfo3.NREPerPRB, pdsch3.TargetCodeRate);
    inputBits3 = randi([0 1], TBS3, 1);

    % -----------------------------------------------------------------
    % Tính toán tiền mã hóa MMSE
    % -----------------------------------------------------------------
    % LÝ THUYẾT: Áp dụng Hermitian Transpose (') để tính Kênh truyền H
    H_composite = [UE1_W'; UE2_W'; UE3_W'];
    numTx = size(UE1_W, 1);
    W_total_T = getMMSEPrecoder(H_composite, SNR_dB, numTx);

    W1_transposed = W_total_T(1:nLayers, :);
    W2_transposed = W_total_T(nLayers+1:2*nLayers, :);
    W3_transposed = W_total_T(2*nLayers+1:end, :); % Lấy đến hết cho UE3

    % -----------------------------------------------------------------
    % Điều chế và Tiền mã hóa (PDSCH & DMRS)
    % -----------------------------------------------------------------
    [sym1, ind1] = PDSCHEncode(pdsch1, carrier, inputBits1);
    [antsym1, antind1] = nrPDSCHPrecode(carrier, sym1, ind1, W1_transposed);
    dSym1 = nrPDSCHDMRS(carrier, pdsch1); dInd1 = nrPDSCHDMRSIndices(carrier, pdsch1);
    [dAntSym1, dAntInd1] = nrPDSCHPrecode(carrier, dSym1, dInd1, W1_transposed);

    [sym2, ind2] = PDSCHEncode(pdsch2, carrier, inputBits2);
    [antsym2, antind2] = nrPDSCHPrecode(carrier, sym2, ind2, W2_transposed);
    dSym2 = nrPDSCHDMRS(carrier, pdsch2); dInd2 = nrPDSCHDMRSIndices(carrier, pdsch2);
    [dAntSym2, dAntInd2] = nrPDSCHPrecode(carrier, dSym2, dInd2, W2_transposed);

    [sym3, ind3] = PDSCHEncode(pdsch3, carrier, inputBits3);
    [antsym3, antind3] = nrPDSCHPrecode(carrier, sym3, ind3, W3_transposed);
    dSym3 = nrPDSCHDMRS(carrier, pdsch3); dInd3 = nrPDSCHDMRSIndices(carrier, pdsch3);
    [dAntSym3, dAntInd3] = nrPDSCHPrecode(carrier, dSym3, dInd3, W3_transposed);

    % -----------------------------------------------------------------
    % Resource Mapping & OFDM
    % -----------------------------------------------------------------
    numPorts = size(W1_transposed, 2);
    txGrid = nrResourceGrid(carrier, numPorts);

    txGrid(antind1) = txGrid(antind1) + antsym1;
    txGrid(dAntInd1) = txGrid(dAntInd1) + dAntSym1;

    txGrid(antind2) = txGrid(antind2) + antsym2;
    txGrid(dAntInd2) = txGrid(dAntInd2) + dAntSym2;

    txGrid(antind3) = txGrid(antind3) + antsym3;
    txGrid(dAntInd3) = txGrid(dAntInd3) + dAntSym3;

    txWaveform = nrOFDMModulate(carrier, txGrid);

    % -----------------------------------------------------------------
    % Channel (Mô phỏng kênh truyền vật lý)
    % -----------------------------------------------------------------
    rxWaveformUE1 = awgn(txWaveform * H_composite(1, :).', SNR_dB, 'measured');
    rxWaveformUE2 = awgn(txWaveform * H_composite(2, :).', SNR_dB, 'measured');
    rxWaveformUE3 = awgn(txWaveform * H_composite(3, :).', SNR_dB, 'measured');

    % -----------------------------------------------------------------
    % RX & Tính BER
    % -----------------------------------------------------------------
    rxBits1 = rxPDSCHDecode(carrier, pdsch1, rxWaveformUE1, txWaveform, TBS1);
    BER1 = biterr(double(inputBits1), double(rxBits1)) / TBS1;

    rxBits2 = rxPDSCHDecode(carrier, pdsch2, rxWaveformUE2, txWaveform, TBS2);
    BER2 = biterr(double(inputBits2), double(rxBits2)) / TBS2;

    rxBits3 = rxPDSCHDecode(carrier, pdsch3, rxWaveformUE3, txWaveform, TBS3);
    BER3 = biterr(double(inputBits3), double(rxBits3)) / TBS3;
end

function [BER1, BER2] = muMimo2UE(...
    carrier, basePDSCHConfig, ...
    UE1_W, UE2_W, MCS, SNR_dB ...
)

    nLayers = size(UE1_W, 2);

    % -----------------------------------------------------------------
    % Cấu hình 2 UEs độc lập
    % -----------------------------------------------------------------
    pdsch1 = basePDSCHConfig;
    if pdsch1.NumLayers == 1, pdsch1.DMRS.DMRSPortSet = 0; else, pdsch1.DMRS.DMRSPortSet = [0, 1]; end
    pdsch1 = pdsch1.setMCS(MCS);
    [~, pInfo1] = nrPDSCHIndices(carrier, pdsch1);
    TBS1 = nrTBS(pdsch1.Modulation, pdsch1.NumLayers, length(pdsch1.PRBSet), pInfo1.NREPerPRB, pdsch1.TargetCodeRate);
    inputBits1 = randi([0 1], TBS1, 1);

    pdsch2 = basePDSCHConfig;
    if pdsch2.NumLayers == 1, pdsch2.DMRS.DMRSPortSet = 2; else, pdsch2.DMRS.DMRSPortSet = [2, 3]; end
    pdsch2 = pdsch2.setMCS(MCS);
    [~, pInfo2] = nrPDSCHIndices(carrier, pdsch2);
    TBS2 = nrTBS(pdsch2.Modulation, pdsch2.NumLayers, length(pdsch2.PRBSet), pInfo2.NREPerPRB, pdsch2.TargetCodeRate);
    inputBits2 = randi([0 1], TBS2, 1);

    % -----------------------------------------------------------------
    % Tính toán tiền mã hóa MMSE
    % -----------------------------------------------------------------
    H_composite = [UE1_W'; UE2_W'];
    numTx = size(UE1_W, 1);
    W_total_T = getMMSEPrecoder(H_composite, SNR_dB, numTx);

    W1_transposed = W_total_T(1:nLayers, :);
    W2_transposed = W_total_T(nLayers+1:end, :); % Lấy đến hết cho UE2

    % -----------------------------------------------------------------
    % Điều chế và Tiền mã hóa (PDSCH & DMRS)
    % -----------------------------------------------------------------
    [sym1, ind1] = PDSCHEncode(pdsch1, carrier, inputBits1);
    [antsym1, antind1] = nrPDSCHPrecode(carrier, sym1, ind1, W1_transposed);
    dSym1 = nrPDSCHDMRS(carrier, pdsch1); dInd1 = nrPDSCHDMRSIndices(carrier, pdsch1);
    [dAntSym1, dAntInd1] = nrPDSCHPrecode(carrier, dSym1, dInd1, W1_transposed);

    [sym2, ind2] = PDSCHEncode(pdsch2, carrier, inputBits2);
    [antsym2, antind2] = nrPDSCHPrecode(carrier, sym2, ind2, W2_transposed);
    dSym2 = nrPDSCHDMRS(carrier, pdsch2); dInd2 = nrPDSCHDMRSIndices(carrier, pdsch2);
    [dAntSym2, dAntInd2] = nrPDSCHPrecode(carrier, dSym2, dInd2, W2_transposed);

    % -----------------------------------------------------------------
    % Resource Mapping & OFDM
    % -----------------------------------------------------------------
    numPorts = size(W1_transposed, 2);
    txGrid = nrResourceGrid(carrier, numPorts);

    txGrid(antind1) = txGrid(antind1) + antsym1;
    txGrid(dAntInd1) = txGrid(dAntInd1) + dAntSym1;

    txGrid(antind2) = txGrid(antind2) + antsym2;
    txGrid(dAntInd2) = txGrid(dAntInd2) + dAntSym2;

    txWaveform = nrOFDMModulate(carrier, txGrid);

    % -----------------------------------------------------------------
    % Channel (Mô phỏng kênh truyền vật lý)
    % -----------------------------------------------------------------
    rxWaveformUE1 = awgn(txWaveform * H_composite(1, :).', SNR_dB, 'measured');
    rxWaveformUE2 = awgn(txWaveform * H_composite(2, :).', SNR_dB, 'measured');

    % -----------------------------------------------------------------
    % RX & Tính BER
    % -----------------------------------------------------------------
    rxBits1 = rxPDSCHDecode(carrier, pdsch1, rxWaveformUE1, txWaveform, TBS1);
    BER1 = biterr(double(inputBits1), double(rxBits1)) / TBS1;

    rxBits2 = rxPDSCHDecode(carrier, pdsch2, rxWaveformUE2, txWaveform, TBS2);
    BER2 = biterr(double(inputBits2), double(rxBits2)) / TBS2;
end

function [bestGroups_Greedy, time_greedy_4, avg_score_greedy_4, BER_results] = runGreedy4UE(W_pool, phyConfig, timeSOS, bestScore_SOS)
    disp('--- Bắt đầu thuật toán Vét cạn (Greedy) cho 4 UEs ---');

    Actual_Pool_Size = size(W_pool, 3); 
    available_ues = 1:Actual_Pool_Size; 
    groupSize = 4;
    num_groups_to_find = floor(Actual_Pool_Size / groupSize);

    total_loop_score = 0;
    completed_groups = 0;
    bestGroups_Greedy = {}; 
    BER_results = [];

    timeout_limit = 5 * 60; % 5 phút timeout
    tic; 

    for g = 1:num_groups_to_find
        if toc > timeout_limit
            fprintf('\n[TIMEOUT] Đã hết 5 phút. Dừng tại nhóm thứ %d\n', g);
            break;
        end
        
        best_group_score = -1;
        best_idx_in_avail = [1, 2, 3, 4]; 
        
        N_avail = length(available_ues);
        if N_avail < groupSize, break; end

        found_any = false;
        % --- 4 VÒNG LẶP VÉT CẠN (O(N^4)) ---
        for i = 1:N_avail-3
            for j = i+1:N_avail-2
                for k = j+1:N_avail-1
                    for l = k+1:N_avail
                        
                        idx_a = available_ues(i);
                        idx_b = available_ues(j);
                        idx_c = available_ues(k);
                        idx_d = available_ues(l);
                        
                        % Tính 6 cặp Chordal Distance chéo
                        d1 = chordalDistance(W_pool(:,:,idx_a), W_pool(:,:,idx_b));
                        d2 = chordalDistance(W_pool(:,:,idx_a), W_pool(:,:,idx_c));
                        d3 = chordalDistance(W_pool(:,:,idx_a), W_pool(:,:,idx_d));
                        d4 = chordalDistance(W_pool(:,:,idx_b), W_pool(:,:,idx_c));
                        d5 = chordalDistance(W_pool(:,:,idx_b), W_pool(:,:,idx_d));
                        d6 = chordalDistance(W_pool(:,:,idx_c), W_pool(:,:,idx_d));
                        
                        avg_score = (d1 + d2 + d3 + d4 + d5 + d6) / 6;
                        
                        if avg_score > best_group_score
                            best_group_score = avg_score;
                            best_idx_in_avail = [i, j, k, l];
                            found_any = true;
                        end
                    end
                end
            end
            if toc > timeout_limit, break; end
        end
        
        if ~found_any, break; end

        actual_ids = available_ues(best_idx_in_avail);
        bestGroups_Greedy{end+1} = actual_ids; 
        total_loop_score = total_loop_score + best_group_score;
        completed_groups = completed_groups + 1;
        
        available_ues(best_idx_in_avail) = [];
    end

    time_greedy_4 = toc;
    avg_score_greedy_4 = total_loop_score / max(1, completed_groups);

    % =========================================================================
    % Tổng kết và so sánh với SOS
    % =========================================================================
    fprintf('\n================== BẢNG SO SÁNH TỔNG HỢP (4 UEs) ==================\n');
    fprintf('Tiêu chí                | SOS (Meta-heuristic) | Greedy (Exhaustive)\n');
    fprintf('------------------------------------------------------------\n');
    fprintf('Thời gian thực thi (s)  | %-20.4f | %-18.4f\n', timeSOS, time_greedy_4);
    fprintf('Điểm Orthogonality TB   | %-20.4f | %-18.4f\n', bestScore_SOS, avg_score_greedy_4);
    fprintf('Số nhóm hoàn thành      | %-20d | %-18d\n', floor(Actual_Pool_Size/4), completed_groups);
    fprintf('============================================================\n');

    % =========================================================================
    % Mô phỏng PHY cho Greedy
    % =========================================================================
    if ~isempty(bestGroups_Greedy)
        disp('--- Đang mô phỏng PHY Layer cho nhóm tốt nhất của Greedy (4 UEs) ---');
        [gBER1, gBER2, gBER3, gBER4] = simulateMuMimoGroup4UE(W_pool, bestGroups_Greedy, phyConfig);
        BER_results = [gBER1, gBER2, gBER3, gBER4];
    end
end

function [bestGroups_Greedy, time_greedy_3, avg_score_greedy_3, BER_results] = runGreedy3UE(W_pool, phyConfig, timeSOS, bestScore_SOS)
    disp('--- Bắt đầu thuật toán Vét cạn (Greedy) cho 3 UEs ---');

    Actual_Pool_Size = size(W_pool, 3); 
    available_ues = 1:Actual_Pool_Size; 
    groupSize = 3;
    num_groups_to_find = floor(Actual_Pool_Size / groupSize);

    total_loop_score = 0;
    completed_groups = 0;
    bestGroups_Greedy = {}; 
    BER_results = [];

    timeout_limit = 5 * 60; 
    tic; 

    for g = 1:num_groups_to_find
        if toc > timeout_limit
            fprintf('\n[TIMEOUT] Dừng tại nhóm thứ %d\n', g);
            break;
        end
        
        best_group_score = -1;
        best_idx_in_avail = [1, 2, 3]; 
        
        N_avail = length(available_ues);
        if N_avail < groupSize, break; end

        found_any = false;
        % --- 3 VÒNG LẶP VÉT CẠN (O(N^3)) ---
        for i = 1:N_avail-2
            for j = i+1:N_avail-1
                for k = j+1:N_avail
                    
                    idx_a = available_ues(i);
                    idx_b = available_ues(j);
                    idx_c = available_ues(k);
                    
                    % Tính 3 cặp Chordal Distance chéo cho nhóm 3 người
                    d1 = chordalDistance(W_pool(:,:,idx_a), W_pool(:,:,idx_b));
                    d2 = chordalDistance(W_pool(:,:,idx_a), W_pool(:,:,idx_c));
                    d3 = chordalDistance(W_pool(:,:,idx_b), W_pool(:,:,idx_c));
                    
                    avg_score = (d1 + d2 + d3) / 3;
                    
                    if avg_score > best_group_score
                        best_group_score = avg_score;
                        best_idx_in_avail = [i, j, k];
                        found_any = true;
                    end
                end
            end
            if toc > timeout_limit, break; end
        end
        
        if ~found_any, break; end

        actual_ids = available_ues(best_idx_in_avail);
        bestGroups_Greedy{end+1} = actual_ids; 
        total_loop_score = total_loop_score + best_group_score;
        completed_groups = completed_groups + 1;
        
        available_ues(best_idx_in_avail) = [];
    end

    time_greedy_3 = toc;
    avg_score_greedy_3 = total_loop_score / max(1, completed_groups);

    % =========================================================================
    % TỔNG KẾT SO SÁNH (SOS vs Greedy 3 UEs)
    % =========================================================================
    fprintf('\n================== BẢNG SO SÁNH (3 UEs) ===================\n');
    fprintf('Tiêu chí                | SOS (Meta)           | Greedy (3-Loop)\n');
    fprintf('------------------------------------------------------------\n');
    fprintf('Thời gian thực thi (s)  | %-20.4f | %-18.4f\n', timeSOS, time_greedy_3);
    fprintf('Điểm Orthogonality TB   | %-20.4f | %-18.4f\n', bestScore_SOS, avg_score_greedy_3);
    fprintf('Số nhóm hoàn thành      | %-20d | %-18d\n', floor(Actual_Pool_Size/3), completed_groups);
    fprintf('============================================================\n');

    % =========================================================================
    % Mô phỏng PHY cho Greedy
    % =========================================================================
    if ~isempty(bestGroups_Greedy)
        disp('--- Đang mô phỏng PHY Layer cho nhóm tốt nhất của Greedy (3 UEs) ---');
        [gBER1, gBER2, gBER3] = simulateMuMimoGroup3UE(W_pool, bestGroups_Greedy, phyConfig);
        BER_results = [gBER1, gBER2, gBER3];
    end
end

function [bestGroups_Greedy, time_greedy_2, avg_score_greedy_2, BER_results] = runGreedy2UE(W_pool, phyConfig, timeSOS, bestScore_SOS)
    disp('--- Bắt đầu thuật toán Vét cạn (Greedy) cho 2 UEs ---');

    Actual_Pool_Size = size(W_pool, 3); 
    available_ues = 1:Actual_Pool_Size; 
    groupSize = 2;
    num_groups_to_find = floor(Actual_Pool_Size / groupSize);

    total_loop_score = 0;
    completed_groups = 0;
    bestGroups_Greedy = {}; 
    BER_results = [];

    timeout_limit = 5 * 60; % 5 phút timeout
    tic; 

    for g = 1:num_groups_to_find
        if toc > timeout_limit
            fprintf('\n[TIMEOUT] Dừng tại nhóm thứ %d\n', g);
            break;
        end
        
        best_group_score = -1;
        best_idx_in_avail = [1, 2]; 
        
        N_avail = length(available_ues);
        if N_avail < groupSize, break; end

        found_any = false;
        % --- 2 VÒNG LẶP VÉT CẠN (O(N^2)) ---
        for i = 1:N_avail-1
            for j = i+1:N_avail
                
                idx_a = available_ues(i);
                idx_b = available_ues(j);
                
                % Chỉ có 1 cặp Chordal Distance cho nhóm 2 người
                d1 = chordalDistance(W_pool(:,:,idx_a), W_pool(:,:,idx_b));
                
                avg_score = d1;
                
                if avg_score > best_group_score
                    best_group_score = avg_score;
                    best_idx_in_avail = [i, j];
                    found_any = true;
                end
            end
        end
        
        if ~found_any, break; end

        actual_ids = available_ues(best_idx_in_avail);
        bestGroups_Greedy{end+1} = actual_ids; 
        total_loop_score = total_loop_score + best_group_score;
        completed_groups = completed_groups + 1;
        
        available_ues(best_idx_in_avail) = [];
    end

    time_greedy_2 = toc;
    avg_score_greedy_2 = total_loop_score / max(1, completed_groups);

    % =========================================================================
    % TỔNG KẾT SO SÁNH (SOS vs Greedy 2 UEs)
    % =========================================================================
    fprintf('\n================== BẢNG SO SÁNH (2 UEs) ===================\n');
    fprintf('Tiêu chí                | SOS (Meta)           | Greedy (2-Loop)\n');
    fprintf('------------------------------------------------------------\n');
    fprintf('Thời gian thực thi (s)  | %-20.4f | %-18.4f\n', timeSOS, time_greedy_2);
    fprintf('Điểm Orthogonality TB   | %-20.4f | %-18.4f\n', bestScore_SOS, avg_score_greedy_2);
    fprintf('Số nhóm hoàn thành      | %-20d | %-18d\n', floor(Actual_Pool_Size/2), completed_groups);
    fprintf('============================================================\n');

    % =========================================================================
    % Mô phỏng PHY cho Greedy
    % =========================================================================
    if ~isempty(bestGroups_Greedy)
        disp('--- Đang mô phỏng PHY Layer cho nhóm tốt nhất của Greedy (2 UEs) ---');
        [gBER1, gBER2] = simulateMuMimoGroup2UE(W_pool, bestGroups_Greedy, phyConfig);
        BER_results = [gBER1, gBER2];
    end
end

function [bestGroups_Greedy, time_greedy_4, avg_score_greedy_4, BER_results] = runGreedy4UEOptimize(W_pool, phyConfig, timeSOS, bestScore_SOS)
    disp('--- Bắt đầu thuật toán Vét cạn (Greedy TỐI ƯU HÓA) cho 4 UEs ---');
    tic; 

    Actual_Pool_Size = size(W_pool, 3); 
    available_ues = 1:Actual_Pool_Size; 
    groupSize = 4;
    num_groups_to_find = floor(Actual_Pool_Size / groupSize);

    % =========================================================================
    % BƯỚC TỐI ƯU CỐT LÕI: Tính trước Ma trận khoảng cách
    % =========================================================================
    disp('Đang tính toán Ma trận khoảng cách (Precomputing Distance Matrix)...');
    distMat = zeros(Actual_Pool_Size, Actual_Pool_Size);
    for i = 1:Actual_Pool_Size-1
        for j = i+1:Actual_Pool_Size
            % Chỉ cần tính 1 lần cho mỗi cặp
            distMat(i, j) = chordalDistance(W_pool(:,:,i), W_pool(:,:,j));
            distMat(j, i) = distMat(i, j); % Ma trận đối xứng
        end
    end
    % =========================================================================

    total_loop_score = 0;
    completed_groups = 0;
    bestGroups_Greedy = {}; 
    BER_results = [];

    timeout_limit = 5 * 60; 

    for g = 1:num_groups_to_find
        if toc > timeout_limit
            fprintf('\n[TIMEOUT] Đã hết 5 phút. Dừng tại nhóm thứ %d\n', g);
            break;
        end
        
        best_group_score = -1;
        best_idx_in_avail = [1, 2, 3, 4]; 
        
        N_avail = length(available_ues);
        if N_avail < groupSize, break; end

        found_any = false;
        
        % --- 4 VÒNG LẶP (Chỉ thực hiện phép cộng và truy xuất mảng O(1)) ---
        for i = 1:N_avail-3
            idx_a = available_ues(i);
            for j = i+1:N_avail-2
                idx_b = available_ues(j);
                d1 = distMat(idx_a, idx_b); % Tra cứu cực nhanh
                
                for k = j+1:N_avail-1
                    idx_c = available_ues(k);
                    d2 = distMat(idx_a, idx_c);
                    d4 = distMat(idx_b, idx_c);
                    
                    for l = k+1:N_avail
                        idx_d = available_ues(l);
                        
                        % Lấy các khoảng cách còn lại
                        d3 = distMat(idx_a, idx_d);
                        d5 = distMat(idx_b, idx_d);
                        d6 = distMat(idx_c, idx_d);
                        
                        avg_score = (d1 + d2 + d3 + d4 + d5 + d6) / 6;
                        
                        if avg_score > best_group_score
                            best_group_score = avg_score;
                            best_idx_in_avail = [i, j, k, l];
                            found_any = true;
                        end
                    end
                end
            end
        end
        
        if ~found_any, break; end

        actual_ids = available_ues(best_idx_in_avail);
        bestGroups_Greedy{end+1} = actual_ids; 
        total_loop_score = total_loop_score + best_group_score;
        completed_groups = completed_groups + 1;
        
        % Xóa UE đã chọn (Cập nhật danh sách khả dụng)
        available_ues(best_idx_in_avail) = [];
    end

    time_greedy_4 = toc;
    avg_score_greedy_4 = total_loop_score / max(1, completed_groups);

    % (Giữ nguyên phần In Bảng So Sánh và Mô Phỏng PHY ở dưới...)
    fprintf('\n================== BẢNG SO SÁNH TỔNG HỢP (4 UEs) ==================\n');
    fprintf('Tiêu chí                | SOS (Meta-heuristic) | Greedy (Optimized)\n');
    fprintf('------------------------------------------------------------\n');
    fprintf('Thời gian thực thi (s)  | %-20.4f | %-18.4f\n', timeSOS, time_greedy_4);
    fprintf('Điểm Orthogonality TB   | %-20.4f | %-18.4f\n', bestScore_SOS, avg_score_greedy_4);
    fprintf('Số nhóm hoàn thành      | %-20d | %-18d\n', floor(Actual_Pool_Size/4), completed_groups);
    fprintf('============================================================\n');

    if ~isempty(bestGroups_Greedy)
        disp('--- Đang mô phỏng PHY Layer cho nhóm tốt nhất của Greedy (4 UEs) ---');
        [gBER1, gBER2, gBER3, gBER4] = simulateMuMimoGroup4UE(W_pool, bestGroups_Greedy, phyConfig);
        BER_results = [gBER1, gBER2, gBER3, gBER4];
    end
end

function [bestGroups_Greedy, time_greedy_3, avg_score_greedy_3, BER_results] = runGreedy3UEOptimize(W_pool, phyConfig, timeSOS, bestScore_SOS)
    disp('--- Bắt đầu thuật toán Vét cạn (Greedy TỐI ƯU HÓA) cho 3 UEs ---');
    tic; 

    Actual_Pool_Size = size(W_pool, 3); 
    available_ues = 1:Actual_Pool_Size; 
    groupSize = 3;
    num_groups_to_find = floor(Actual_Pool_Size / groupSize);

    % =========================================================================
    % BƯỚC TỐI ƯU CỐT LÕI: Tính trước Ma trận khoảng cách
    % =========================================================================
    disp('Đang tính toán Ma trận khoảng cách (Precomputing Distance Matrix)...');
    distMat = zeros(Actual_Pool_Size, Actual_Pool_Size);
    for i = 1:Actual_Pool_Size-1
        for j = i+1:Actual_Pool_Size
            distMat(i, j) = chordalDistance(W_pool(:,:,i), W_pool(:,:,j));
            distMat(j, i) = distMat(i, j); % Ma trận đối xứng
        end
    end
    % =========================================================================

    total_loop_score = 0;
    completed_groups = 0;
    bestGroups_Greedy = {}; 
    BER_results = [];

    timeout_limit = 5 * 60; 

    for g = 1:num_groups_to_find
        if toc > timeout_limit
            fprintf('\n[TIMEOUT] Đã hết 5 phút. Dừng tại nhóm thứ %d\n', g);
            break;
        end
        
        best_group_score = -1;
        best_idx_in_avail = [1, 2, 3]; 
        
        N_avail = length(available_ues);
        if N_avail < groupSize, break; end

        found_any = false;
        
        % --- 3 VÒNG LẶP (Tra cứu mảng O(1)) ---
        for i = 1:N_avail-2
            idx_a = available_ues(i);
            for j = i+1:N_avail-1
                idx_b = available_ues(j);
                d1 = distMat(idx_a, idx_b); % Tra cứu nhanh
                
                for k = j+1:N_avail
                    idx_c = available_ues(k);
                    
                    % Lấy các khoảng cách còn lại
                    d2 = distMat(idx_a, idx_c);
                    d3 = distMat(idx_b, idx_c);
                    
                    avg_score = (d1 + d2 + d3) / 3;
                    
                    if avg_score > best_group_score
                        best_group_score = avg_score;
                        best_idx_in_avail = [i, j, k];
                        found_any = true;
                    end
                end
            end
        end
        
        if ~found_any, break; end

        actual_ids = available_ues(best_idx_in_avail);
        bestGroups_Greedy{end+1} = actual_ids; 
        total_loop_score = total_loop_score + best_group_score;
        completed_groups = completed_groups + 1;
        
        % Xóa UE đã chọn (Cập nhật danh sách khả dụng)
        available_ues(best_idx_in_avail) = [];
    end

    time_greedy_3 = toc;
    avg_score_greedy_3 = total_loop_score / max(1, completed_groups);

    fprintf('\n================== BẢNG SO SÁNH TỔNG HỢP (3 UEs) ==================\n');
    fprintf('Tiêu chí                | SOS (Meta-heuristic) | Greedy (Optimized)\n');
    fprintf('------------------------------------------------------------\n');
    fprintf('Thời gian thực thi (s)  | %-20.4f | %-18.4f\n', timeSOS, time_greedy_3);
    fprintf('Điểm Orthogonality TB   | %-20.4f | %-18.4f\n', bestScore_SOS, avg_score_greedy_3);
    fprintf('Số nhóm hoàn thành      | %-20d | %-18d\n', floor(Actual_Pool_Size/3), completed_groups);
    fprintf('============================================================\n');

    if ~isempty(bestGroups_Greedy)
        disp('--- Đang mô phỏng PHY Layer cho nhóm tốt nhất của Greedy (3 UEs) ---');
        [gBER1, gBER2, gBER3] = simulateMuMimoGroup3UE(W_pool, bestGroups_Greedy, phyConfig);
        BER_results = [gBER1, gBER2, gBER3];
    end
end

function [bestGroups_Greedy, time_greedy_2, avg_score_greedy_2, BER_results] = runGreedy2UEOptimize(W_pool, phyConfig, timeSOS, bestScore_SOS)
    disp('--- Bắt đầu thuật toán Vét cạn (Greedy TỐI ƯU HÓA) cho 2 UEs ---');
    tic; 

    Actual_Pool_Size = size(W_pool, 3); 
    available_ues = 1:Actual_Pool_Size; 
    groupSize = 2;
    num_groups_to_find = floor(Actual_Pool_Size / groupSize);

    % =========================================================================
    % BƯỚC TỐI ƯU CỐT LÕI: Tính trước Ma trận khoảng cách
    % =========================================================================
    disp('Đang tính toán Ma trận khoảng cách (Precomputing Distance Matrix)...');
    distMat = zeros(Actual_Pool_Size, Actual_Pool_Size);
    for i = 1:Actual_Pool_Size-1
        for j = i+1:Actual_Pool_Size
            distMat(i, j) = chordalDistance(W_pool(:,:,i), W_pool(:,:,j));
            distMat(j, i) = distMat(i, j); % Ma trận đối xứng
        end
    end
    % =========================================================================

    total_loop_score = 0;
    completed_groups = 0;
    bestGroups_Greedy = {}; 
    BER_results = [];

    timeout_limit = 5 * 60; 

    for g = 1:num_groups_to_find
        if toc > timeout_limit
            fprintf('\n[TIMEOUT] Đã hết 5 phút. Dừng tại nhóm thứ %d\n', g);
            break;
        end
        
        best_group_score = -1;
        best_idx_in_avail = [1, 2]; 
        
        N_avail = length(available_ues);
        if N_avail < groupSize, break; end

        found_any = false;
        
        % --- 2 VÒNG LẶP (Tra cứu mảng O(1)) ---
        for i = 1:N_avail-1
            idx_a = available_ues(i);
            for j = i+1:N_avail
                idx_b = available_ues(j);
                
                % Lấy khoảng cách trực tiếp từ ma trận
                avg_score = distMat(idx_a, idx_b);
                
                if avg_score > best_group_score
                    best_group_score = avg_score;
                    best_idx_in_avail = [i, j];
                    found_any = true;
                end
            end
        end
        
        if ~found_any, break; end

        actual_ids = available_ues(best_idx_in_avail);
        bestGroups_Greedy{end+1} = actual_ids; 
        total_loop_score = total_loop_score + best_group_score;
        completed_groups = completed_groups + 1;
        
        % Xóa UE đã chọn
        available_ues(best_idx_in_avail) = [];
    end

    time_greedy_2 = toc;
    avg_score_greedy_2 = total_loop_score / max(1, completed_groups);

    fprintf('\n================== BẢNG SO SÁNH TỔNG HỢP (2 UEs) ==================\n');
    fprintf('Tiêu chí                | SOS (Meta-heuristic) | Greedy (Optimized)\n');
    fprintf('------------------------------------------------------------\n');
    fprintf('Thời gian thực thi (s)  | %-20.4f | %-18.4f\n', timeSOS, time_greedy_2);
    fprintf('Điểm Orthogonality TB   | %-20.4f | %-18.4f\n', bestScore_SOS, avg_score_greedy_2);
    fprintf('Số nhóm hoàn thành      | %-20d | %-18d\n', floor(Actual_Pool_Size/2), completed_groups);
    fprintf('============================================================\n');

    if ~isempty(bestGroups_Greedy)
        disp('--- Đang mô phỏng PHY Layer cho nhóm tốt nhất của Greedy (2 UEs) ---');
        [gBER1, gBER2] = simulateMuMimoGroup2UE(W_pool, bestGroups_Greedy, phyConfig);
        BER_results = [gBER1, gBER2];
    end
end