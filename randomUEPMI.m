% =========================================================================
% SCRIPT: K-MEANS + SOS MU-MIMO SCHEDULING CHO 20,000 UEs
% =========================================================================
clear; clc; close all;
setupPath();

% =========================================================================
% Configuration for test
% =========================================================================
prepareDataConfig = struct();
prepareDataConfig.Num_UEs           = 20000;
prepareDataConfig.N1                = 4;
prepareDataConfig.N2                = 1;
prepareDataConfig.O1                = 4;
prepareDataConfig.O2                = 1;
prepareDataConfig.L                 = 2;
prepareDataConfig.NumLayers         = 1;
prepareDataConfig.subbandAmplitude  = true;
prepareDataConfig.PhaseAlphabetSize = 8;

% =========================================================================
% Prepare W for Number of UE Test
% =========================================================================
[W_all, UE_Reported_Indices] = prepareData(prepareDataConfig);

% =========================================================================
% Pre-Processing and prepare for SOS algorithms
% =========================================================================
poolConfig = struct();
poolConfig.numClusters    = 50;
poolConfig.targetPoolSize = 200;
poolConfig.kmeansMaxIter  = 100;

[W_pool, pool_indices] = buildRepresentativePool(W_all, poolConfig);

% =========================================================================
% SOS algorithms
% =========================================================================
groupSize = 4; 
maxIter = 100; 

disp('--- Bắt đầu lập lịch MU-MIMO với thuật toán SOS ---');
tic;
[bestGroups_SOS, bestScore_SOS] = sosMUMIMOScheduling(W_pool, groupSize, maxIter);
timeSOS = toc;

% =========================================================================
% Test Mu-MIMO with SOS
% =========================================================================
phyConfig = struct();
phyConfig.MCS = 9;
phyConfig.SNR_dB = 20;
phyConfig.PRBSet = 0:272;
phyConfig.SubcarrierSpacing = 30;
phyConfig.NSizeGrid = 273;

% Gọi hàm mô phỏng cho nhóm 4 UEs
[BER1, BER2, BER3, BER4] = simulateMuMimoGroup4UE(W_pool, bestGroups_SOS, phyConfig);

% % =========================================================================
% % Greedy algorithms (Vét cạn 4 UEs)
% % =========================================================================
% disp('--- Bắt đầu thuật toán Vét cạn (Greedy) cho 4 UEs ---');

% % Đảm bảo lấy đúng kích thước Pool
% Actual_Pool_Size = size(W_pool, 3); 
% available_ues = 1:Actual_Pool_Size; % Danh sách ID các UE đang còn trống
% groupSize = 4;
% num_groups_to_find = floor(Actual_Pool_Size / groupSize);

% total_loop_score = 0;
% completed_groups = 0;
% bestGroups_Greedy = {}; % Nơi lưu các nhóm đã ghép được

% timeout_limit = 5 * 60; % 5 phút timeout
% tic; 

% for g = 1:num_groups_to_find
%     % 1. Kiểm tra Timeout
%     if toc > timeout_limit
%         fprintf('\n[TIMEOUT] Đã hết 5 phút. Dừng tại nhóm thứ %d\n', g);
%         break;
%     end
    
%     best_group_score = -1;
%     best_idx_in_avail = [1, 2, 3, 4]; % Chỉ số vị trí trong mảng available_ues
    
%     N_avail = length(available_ues);
%     if N_avail < groupSize, break; end

%     % 2. Bắt đầu 4 vòng lặp quét cạn
%     % Chú ý: Với N=200, vòng lặp này cực kỳ nặng (~64 triệu tổ hợp)
%     found_any = false;
%     for i = 1:N_avail-3
%         for j = i+1:N_avail-2
%             for k = j+1:N_avail-1
%                 for l = k+1:N_avail
                    
%                     % Lấy ID thực tế của UE từ pool
%                     idx_a = available_ues(i);
%                     idx_b = available_ues(j);
%                     idx_c = available_ues(k);
%                     idx_d = available_ues(l);
                    
%                     % Tính 6 cặp Chordal Distance chéo
%                     d1 = chordalDistance(W_pool(:,:,idx_a), W_pool(:,:,idx_b));
%                     d2 = chordalDistance(W_pool(:,:,idx_a), W_pool(:,:,idx_c));
%                     d3 = chordalDistance(W_pool(:,:,idx_a), W_pool(:,:,idx_d));
%                     d4 = chordalDistance(W_pool(:,:,idx_b), W_pool(:,:,idx_c));
%                     d5 = chordalDistance(W_pool(:,:,idx_b), W_pool(:,:,idx_d));
%                     d6 = chordalDistance(W_pool(:,:,idx_c), W_pool(:,:,idx_d));
                    
%                     avg_score = (d1 + d2 + d3 + d4 + d5 + d6) / 6;
                    
%                     if avg_score > best_group_score
%                         best_group_score = avg_score;
%                         best_idx_in_avail = [i, j, k, l];
%                         found_any = true;
%                     end
%                 end
%             end
%         end
%         % Kiểm tra timeout trong vòng lặp i để thoát sớm
%         if toc > timeout_limit, break; end
%     end
    
%     if ~found_any, break; end

%     % 3. Lưu kết quả nhóm tốt nhất tìm được
%     actual_ids = available_ues(best_idx_in_avail);
%     bestGroups_Greedy{end+1} = actual_ids; %#ok<AGROW>
%     total_loop_score = total_loop_score + best_group_score;
%     completed_groups = completed_groups + 1;
    
%     fprintf('Nhóm %d: Score = %.4f | IDs = [%s] | Time: %.2fs\n', ...
%         g, best_group_score, num2str(actual_ids), toc);
    
%     % 4. Loại bỏ các UE đã được ghép khỏi danh sách khả dụng
%     available_ues(best_idx_in_avail) = [];
% end

% time_greedy_4 = toc;

% % =========================================================================
% % Tổng kết và so sánh với SOS
% % =========================================================================
% if completed_groups > 0
%     avg_score_greedy_4 = total_loop_score / completed_groups;
% else
%     avg_score_greedy_4 = 0;
% end

% fprintf('\n================== BẢNG SO SÁNH TỔNG HỢP ==================\n');
% fprintf('Tiêu chí                | SOS (Meta-heuristic) | Greedy (Exhaustive)\n');
% fprintf('------------------------------------------------------------\n');
% fprintf('Thời gian thực thi (s)  | %-20.4f | %-18.4f\n', timeSOS, time_greedy_4);
% fprintf('Điểm Orthogonality TB   | %-20.4f | %-18.4f\n', bestScore_SOS, avg_score_greedy_4);
% fprintf('Số nhóm hoàn thành      | %-20d | %-18d\n', floor(Actual_Pool_Size/4), completed_groups);
% fprintf('============================================================\n');

% % =========================================================================
% % Mô phỏng PHY cho Greedy (Nếu có nhóm)
% % =========================================================================
% if ~isempty(bestGroups_Greedy)
%     disp('--- Đang mô phỏng PHY Layer cho nhóm tốt nhất của Greedy ---');
%     % Sử dụng hàm simulateMuMimoGroup4UE đã viết ở trên
%     [gBER1, gBER2, gBER3, gBER4] = simulateMuMimoGroup4UE(W_pool, bestGroups_Greedy, phyConfig);
% end

% =========================================================================
% Greedy algorithms (Vét cạn 3 UEs)
% =========================================================================
disp('--- Bắt đầu thuật toán Vét cạn (Greedy) cho 3 UEs ---');

Actual_Pool_Size = size(W_pool, 3); 
available_ues = 1:Actual_Pool_Size; 
groupSize = 3;
num_groups_to_find = floor(Actual_Pool_Size / groupSize);

total_loop_score = 0;
completed_groups = 0;
bestGroups_Greedy = {}; 

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
                
                % Điểm trung bình nhóm 3 UE
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
    
    fprintf('Nhóm %d: Score = %.4f | IDs = [%s] | Time: %.2fs\n', ...
        g, best_group_score, num2str(actual_ids), toc);
    
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

if ~isempty(bestGroups_Greedy)
    [gBER1, gBER2, gBER3] = simulateMuMimoGroup3UE(W_pool, bestGroups_Greedy, phyConfig);
end

% =========================================================================
% LOCAL FUNCTIONS 
% =========================================================================

function [bestGroups, bestScore] = sosMUMIMOScheduling(W_all, groupSize, maxIter)
    NUE = size(W_all, 3);
    popSize = 50; 
    
    numGroups = floor(NUE / groupSize);
    population = zeros(popSize, NUE);
    for p = 1:popSize
        population(p, :) = randperm(NUE);
    end
    
    fitnessFunc = @(perm) computeScheduleFitness(perm, W_all, groupSize, numGroups);
    
    fitness = zeros(popSize, 1);
    for p = 1:popSize
        fitness(p) = fitnessFunc(population(p, :));
    end
    
    bestScore = max(fitness);
    [~, bestIdx] = max(fitness);
    bestPerm = population(bestIdx, :);
    
    for iter = 1:maxIter
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
        
        [curBest, curIdx] = max(fitness);
        if curBest > bestScore
            bestScore = curBest;
            bestPerm = population(curIdx, :);
        end
    end
    
    bestGroups = cell(numGroups, 1);
    for g = 1:numGroups
        idx = (g-1)*groupSize + 1 : g*groupSize;
        bestGroups{g} = bestPerm(idx);
    end
end

function score = computeScheduleFitness(perm, W_all, groupSize, numGroups)
    totalDist = 0;
    for g = 1:numGroups
        idx = (g-1)*groupSize + 1 : g*groupSize;
        ueIdx = perm(idx);
        groupDist = 0; cnt = 0;
        for a = 1:groupSize
            for b = a+1:groupSize
                Wa = W_all(:,:,ueIdx(a));
                Wb = W_all(:,:,ueIdx(b));
                groupDist = groupDist + chordalDistance(Wa, Wb);
                cnt = cnt + 1;
            end
        end
        totalDist = totalDist + groupDist / cnt;
    end
    score = totalDist / numGroups;
end

function newPerm = mutualismSwap(permA, permB)
    n = length(permA);
    newPerm = permA;
    pts = sort(randperm(n, 2));
    segment = permB(pts(1):pts(2));
    newPerm(ismember(newPerm, segment)) = [];
    insertPos = pts(1);
    newPerm = [newPerm(1:insertPos-1), segment, newPerm(insertPos:end)];
end

function newPerm = commensalismSwap(permA, ~)
    newPerm = permA;
    pts = randperm(length(permA), 2);
    newPerm(pts(1)) = permA(pts(2));
    newPerm(pts(2)) = permA(pts(1));
end

function parasite = parasitePerturb(perm)
    parasite = perm;
    n = length(perm);
    pts = sort(randperm(n, 2));
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

    [BER1, BER2, BER3, BER4] = muMimo(carrier, pdsch, W1, W2, W3, W4, MCS, SNR_dB);

    % 5. Hiển thị kết quả BER
    fprintf('\n================ KẾT QUẢ TRUYỀN DỮ LIỆU ================\n');
    fprintf('BER của UE 1 (ID: %d): %.6f\n', ue1_idx, BER1);
    fprintf('BER của UE 2 (ID: %d): %.6f\n', ue2_idx, BER2);
    fprintf('BER của UE 3 (ID: %d): %.6f\n', ue3_idx, BER3);
    fprintf('BER của UE 4 (ID: %d): %.6f\n', ue4_idx, BER4);
    disp('========================================================');
end

function val = getField(s, fname, default)
    if isfield(s, fname)
        val = s.(fname);
    else
        val = default;
    end
end

function [BER1, BER2, BER3, BER4] = muMimo(...
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