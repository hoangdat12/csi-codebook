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
config.CodeBookConfig.N2 = 1;
config.CodeBookConfig.cbMode = 1;
config.FileName = "Layer4_Port8_N1_4_N2-1_c1.txt";

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
threshold = 0.99999; % Ngưỡng trực giao
fprintf('\n[Pre-search] Finding feasible orthogonal UE pairs (score >= %.2f)...\n', threshold);

% Gọi hàm mới của bro (Trả về danh sách các nhóm)
[f_groups, f_W, f_scores, f_pmi] = findFeasibleOrthogonalGroups(W_pool, pool_pmi, numberOfUeToGroup, 50, threshold);

% Kiểm tra xem có tìm được cặp nào không
if ~isempty(f_W)
    fprintf('\n---> Đưa cặp ĐẦU TIÊN đạt chuẩn vào test BER Loopback...\n');
    
    % Lấy ma trận W của nhóm ĐẦU TIÊN trong danh sách
    W_test = f_W{1}; 

    % Chạy Test BER
    [BER1, BER2] = muMIMO2UE(baseConfig, W_test(:,:,1), W_test(:,:,2));
    
    fprintf('\n[KẾT QUẢ TEST BER MU-MIMO]\n');
    fprintf('BER UE 1: %.6f\n', BER1);
    fprintf('BER UE 2: %.6f\n', BER2);
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
    [bestGroups, ~] = sosMUMIMOScheduling(W_pool, num_users_to_group, maxIter);

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

function [bestGroups, bestScore] = sosMUMIMOScheduling(W_all, groupSize, maxIter)
    % Get number of UE in the Cell
    NUE = size(W_all, 3);
    
    % Size of each group
    popSize = 30; 

    % The total number of groups
    numGroups = floor(NUE / groupSize);
    
    % Initialize the population: Each organism is a random permutation of UE indices
    population = zeros(popSize, NUE);
    for p = 1:popSize
        population(p, :) = randperm(NUE);
    end
    
    % Precompute the distance matrix (Symmetric Matrix) to minimize recalculation overhead
    disp('      [SOS] Computing distance matrix...');
    distMat = zeros(NUE, NUE);
    for i = 1:NUE-1
        for j = i+1:NUE
            distMat(i, j) = chordalDistance(W_all(:,:,i), W_all(:,:,j));
            distMat(j, i) = distMat(i, j); 
        end
    end
    
    % Initialize the function handle for fitness evaluation
    fitnessFunc = @(perm) computeScheduleFitnessOptimize(perm, distMat, groupSize, numGroups);
    
    fitness = zeros(popSize, 1);
    for p = 1:popSize
        fitness(p) = fitnessFunc(population(p, :));
    end
    
    % Identify the initial best organism
    [bestScore, bestIdx] = max(fitness);
    bestPerm = population(bestIdx, :);
    
    no_improve_counter = 0;
    % Early stopping condition: No improvement after 15 iterations
    max_no_improve = 15; 
    
    disp('      [SOS] Starting evolutionary generations...');
    for iter = 1:maxIter        
        % ===== MUTUALISM PHASE =====
        for i = 1:popSize
            j = randi(popSize);
            while j == i, j = randi(popSize); end
            
            % Crossover between organism i and j
            newOrgI = mutualismSwap(population(i,:), population(j,:));
            newOrgJ = mutualismSwap(population(j,:), population(i,:));
            
            % Update if the new organism has a higher score (better orthogonality)
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
            
            % Random mutation on organism i
            newOrg = commensalismSwap(population(i,:), population(j,:));
            fNew = fitnessFunc(newOrg);
            if fNew > fitness(i)
                population(i,:) = newOrg;
                fitness(i) = fNew;
            end
        end
        
        % ===== PARASITISM PHASE =====
        for i = 1:popSize
            % Perturb the internal order of a segment to create a strong mutation
            parasite = parasitePerturb(population(i,:));
            host = randi(popSize);
            while host == i, host = randi(popSize); end
            
            % Parasite replaces the host if it has a higher fitness score
            fParasite = fitnessFunc(parasite);
            if fParasite > fitness(host)
                population(host,:) = parasite;
                fitness(host) = fParasite;
            end
        end
        
        % Check for convergence and update the global best
        [curBest, curIdx] = max(fitness);
        if curBest > bestScore
            bestScore = curBest;
            bestPerm = population(curIdx, :);
            no_improve_counter = 0; 
        else
            no_improve_counter = no_improve_counter + 1;
        end
        
        if no_improve_counter >= max_no_improve
            fprintf('      [SOS] Algorithm converged early at iteration %d (Score: %.4f)\n', iter, bestScore);
            break;
        end
    end
    
    % Extract the UE array into cell arrays based on group size
    bestGroups = cell(numGroups, 1);
    for g = 1:numGroups
        idx = (g-1)*groupSize + 1 : g*groupSize;
        bestGroups{g} = bestPerm(idx);
    end
end

% =========================================================================
% FITNESS FUNCTION 
% =========================================================================
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
    
    pt1 = randi(n);
    pt2 = randi(n);
    while pt1 == pt2
        pt2 = randi(n); % Đảm bảo 2 điểm không trùng nhau
    end
    
    if pt1 < pt2
        idx1 = pt1; idx2 = pt2;
    else
        idx1 = pt2; idx2 = pt1;
    end
    
    segment = permB(idx1:idx2); % Trích xuất một đoạn từ sinh vật B
    
    isInSegment = false(1, n); 
    isInSegment(segment) = true; % Đánh dấu 'true' cho những UE có trong segment
    
    remaining = permA(~isInSegment(permA));  
    
    maxInsert = length(remaining) + 1; 
    insertPos = randi(maxInsert);
    
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

function [BER1, BER2] = muMIMO2UE(baseConfig, W1, W2) 
    nLayers = baseConfig.NLAYERS;

    carrier = nrCarrierConfig;
    carrier.SubcarrierSpacing = baseConfig.SUBCARRIER_SPACING;  
    carrier.NSizeGrid         = baseConfig.NSIZE_GRID;
    carrier.CyclicPrefix      = baseConfig.CYCLIC_PREFIX;
    carrier.NSlot             = baseConfig.NSLOT;
    carrier.NFrame            = baseConfig.NFRAME;
    carrier.NCellID           = baseConfig.NCELL_ID;

    % ── PDSCH UE1 ────────────────────────────────────────────────────────
    pdsch1 = customPDSCHConfig(); 
    pdsch1.DMRS.DMRSConfigurationType   = baseConfig.DMRS_CONFIGURATION_TYPE; 
    pdsch1.DMRS.DMRSTypeAPosition       = baseConfig.DMRS_TYPEA_POSITION; 
    pdsch1.DMRS.NumCDMGroupsWithoutData = baseConfig.DMRS_NUMCDMGROUP_WITHOUT_DATA;
    pdsch1.DMRS.DMRSLength              = baseConfig.DMRS_LENGTH;
    pdsch1.DMRS.DMRSAdditionalPosition  = baseConfig.DMRS_ADDITIONAL_POSITION;
    pdsch1.NumLayers        = nLayers;
    pdsch1.MappingType      = baseConfig.PDSCH_MAPPING_TYPE;
    pdsch1.RNTI             = baseConfig.PDSCH_RNTI;
    pdsch1.PRBSet           = baseConfig.PDSCH_PRBSET;
    pdsch1.SymbolAllocation = [baseConfig.PDSCH_START_SYMBOL, 14 - baseConfig.PDSCH_START_SYMBOL];
    pdsch1                  = pdsch1.setMCS(baseConfig.MCS);
    pdsch1.DMRS.DMRSPortSet = 0:3;
    pdsch1.DMRS.NSCID       = 0;

    % ── PDSCH UE2 ────────────────────────────────────────────────────────
    pdsch2 = customPDSCHConfig(); 
    pdsch2.DMRS.DMRSConfigurationType   = baseConfig.DMRS_CONFIGURATION_TYPE; 
    pdsch2.DMRS.DMRSTypeAPosition       = baseConfig.DMRS_TYPEA_POSITION; 
    pdsch2.DMRS.NumCDMGroupsWithoutData = baseConfig.DMRS_NUMCDMGROUP_WITHOUT_DATA;
    pdsch2.DMRS.DMRSLength              = baseConfig.DMRS_LENGTH;
    pdsch2.DMRS.DMRSAdditionalPosition  = baseConfig.DMRS_ADDITIONAL_POSITION;
    pdsch2.NumLayers        = nLayers;
    pdsch2.MappingType      = baseConfig.PDSCH_MAPPING_TYPE;
    pdsch2.RNTI             = baseConfig.PDSCH_RNTI + 1; 
    pdsch2.PRBSet           = baseConfig.PDSCH_PRBSET;
    pdsch2.SymbolAllocation = [baseConfig.PDSCH_START_SYMBOL, 14 - baseConfig.PDSCH_START_SYMBOL];
    pdsch2                  = pdsch2.setMCS(baseConfig.MCS);
    pdsch2.DMRS.DMRSPortSet = 4:7;
    pdsch2.DMRS.NSCID       = 0;

    % ── Encode ───────────────────────────────────────────────────────────
    TBS1       = manualCalculateTBS(pdsch1);
    TBS2       = manualCalculateTBS(pdsch2);
    inputBits1 = ones(TBS1, 1);
    inputBits2 = zeros(TBS2, 1);

    [layerMappedSym1, pdschInd1] = myPDSCHEncode(pdsch1, carrier, inputBits1);
    [layerMappedSym2, pdschInd2] = myPDSCHEncode(pdsch2, carrier, inputBits2);

    dmrsSym1 = genDMRS(carrier, pdsch1);   dmrsInd1 = DMRSIndices(pdsch1, carrier);
    dmrsSym2 = genDMRS(carrier, pdsch2);   dmrsInd2 = DMRSIndices(pdsch2, carrier);

    % ── Resource grid (manual, supports any nPorts) ───────────────────────
    nPorts        = size(W1, 1); 
    nLayers1      = pdsch1.NumLayers;
    nLayers2      = pdsch2.NumLayers;
    symbolsPerSlot = carrier.SymbolsPerSlot;          % 14
    NFFT          = computeNFFT(carrier.SubcarrierSpacing);
    K             = carrier.NSizeGrid * 12;           % useful subcarriers

    % Layer grids  [K x symbolsPerSlot x nLayers]
    layerGrid_UE1 = zeros(K, symbolsPerSlot, nLayers1);
    layerGrid_UE2 = zeros(K, symbolsPerSlot, nLayers2);

    for layer = 1:nLayers1
        layerGrid_UE1(pdschInd1(:,layer)) = layerMappedSym1(:,layer);
        layerGrid_UE1(dmrsInd1(:,layer))  = dmrsSym1(:,layer);
    end
    for layer = 1:nLayers2
        layerGrid_UE2(pdschInd2(:,layer)) = layerMappedSym2(:,layer);
        layerGrid_UE2(dmrsInd2(:,layer))  = dmrsSym2(:,layer);
    end

    layerFlat_UE1   = reshape(layerGrid_UE1, K*symbolsPerSlot, nLayers1);
    layerFlat_UE2   = reshape(layerGrid_UE2, K*symbolsPerSlot, nLayers2);
    portFlat_UE1    = layerFlat_UE1 * W1.';   % [K*T x nPorts]
    portFlat_UE2    = layerFlat_UE2 * W2.';
    portFlat        = portFlat_UE1 + portFlat_UE2;

    portGrid        = reshape(portFlat, K, symbolsPerSlot, nPorts);

    txdataF_test  = subcarrierMap(portGrid(:,:,1), NFFT);
    txTest        = ofdmModulation(txdataF_test, NFFT);
    samplePerSlot = length(txTest);          % lấy size thực từ hàm của bạn
    txWaveform    = zeros(samplePerSlot, nPorts);
    for p = 1:nPorts
        txdataF_p        = subcarrierMap(portGrid(:,:,p), NFFT);
        txWaveform(:, p) = ofdmModulation(txdataF_p, NFFT);
    end
    for p = 1:nPorts
        txdataF_p        = subcarrierMap(portGrid(:,:,p), NFFT);  % [NFFT x nSymbols]
        txWaveform(:, p) = ofdmModulation(txdataF_p, NFFT);
    end

    % ── RX Decode ─────────────────────────────────────────────────────────
    [rxBits1, ~] = rxPDSCHDecode(carrier, pdsch1, txWaveform, TBS1, NFFT);
    [rxBits2, ~] = rxPDSCHDecode(carrier, pdsch2, txWaveform, TBS2, NFFT);

    numErrors  = biterr(double(inputBits1), double(rxBits1));
    BER1       = numErrors / TBS1;
    numErrors2 = biterr(double(inputBits2), double(rxBits2));
    BER2       = numErrors2 / TBS2;
end

function [rxBits, eqSymbols, Hest] = rxPDSCHDecode(carrier, pdsch, txWaveform, TBS, NFFT)
    K              = carrier.NSizeGrid * 12;
    symbolsPerSlot = carrier.SymbolsPerSlot;
    nPorts         = size(txWaveform, 2);
    nLayers        = pdsch.NumLayers;

    % ── OFDM demodulate ───────────────────────────────────────────────
    rxGrid = zeros(K, symbolsPerSlot, nPorts);
    for p = 1:nPorts
        rxdataF_p     = ofdmDemodulation(txWaveform(:, p), NFFT, K, ...
                                         carrier.SubcarrierSpacing);
        rxGrid(:,:,p) = rxdataF_p(:, 1:symbolsPerSlot);
    end

    % ── Lấy PDSCH RE của UE cần decode ────────────────────────────────
    pdschInd = nrPDSCHIndices(carrier, pdsch);
    planeSize = K * symbolsPerSlot;

    % Nếu index có offset theo layer thì bỏ offset
    pdschInd2D = pdschInd(:,1);
    if any(pdschInd2D > planeSize)
        pdschInd2D = pdschInd2D - 0*planeSize;   % cột 1 -> layer 1
    end

    nRE = size(pdschInd, 1);
    pdschRx = zeros(nRE, nPorts);
    for p = 1:nPorts
        grid_p        = rxGrid(:,:,p);
        pdschRx(:, p) = grid_p(pdschInd2D);
    end

    % ── DMRS-based channel estimation ─────────────────────────────────
    HportLayer = estimateChannelFromDMRS(rxGrid, carrier, pdsch);

    % Kênh lý tưởng hiện tại: replicate cho toàn bộ RE PDSCH
    Hest = repmat(reshape(HportLayer, [1, nPorts, nLayers]), [nRE, 1, 1]);

    noiseVar  = eps;
    eqSymbols = nrEqualizeMMSE(pdschRx, Hest, noiseVar);
    rxBits    = PDSCHDecode(pdsch, carrier, eqSymbols, TBS, noiseVar);
end

function HportLayer = estimateChannelFromDMRS(rxGrid, carrier, pdsch)
    K              = carrier.NSizeGrid * 12;
    symbolsPerSlot = carrier.SymbolsPerSlot;
    planeSize      = K * symbolsPerSlot;

    nPorts  = size(rxGrid, 3);
    nLayers = pdsch.NumLayers;

    dmrsInd = DMRSIndices(pdsch, carrier);   % [nDmrsRE x nLayers]
    dmrsTx  = genDMRS(carrier, pdsch);       % [nDmrsRE x nLayers]

    HportLayer = zeros(nPorts, nLayers);

    for l = 1:nLayers
        % Bỏ offset theo layer để map về mặt phẳng 2D [K x symbolsPerSlot]
        ind2D = dmrsInd(:, l);
        if any(ind2D > planeSize)
            ind2D = ind2D - (l-1)*planeSize;
        end

        for p = 1:nPorts
            rxTmp = rxGrid(:,:,p);
            y = rxTmp(ind2D);
            x = dmrsTx(:, l);

            h_ls = y ./ x;
            HportLayer(p, l) = mean(h_ls);
        end
    end
end

function rxdataF = ofdmDemodulation(rxdata, NFFT, K, SCS)
    mu          = log2(SCS / 15);          % numerology
    cp_samples0 = round(176 * NFFT / 2048);
    cp_samples  = round(144 * NFFT / 2048);
    nSymPerSlot = 14;                      % normal CP, one slot
    rxdataF = zeros(K, nSymPerSlot);
    idx     = 0;
    for i = 1:nSymPerSlot
        if mod(i, 7 * 2^mu) == 1
            cp_len = cp_samples0;
        else
            cp_len = cp_samples;
        end
        sym_start = idx + cp_len + 1;
        sym_end   = sym_start + NFFT - 1;
        time_sym  = rxdata(sym_start : sym_end);
        freq_sym  = fft(time_sym, NFFT);
        half      = K / 2;
        rxdataF(:, i) = [freq_sym(2 : half+1);                    % positive
                         freq_sym(NFFT - half + 1 : NFFT)];       % negative
        idx = idx + cp_len + NFFT;
    end
end

function txdataF = subcarrierMap(grid_K_T, NFFT)
    [K, nSym] = size(grid_K_T);
    half       = K / 2;
    txdataF    = zeros(NFFT, nSym);
    txdataF(2 : half+1,            :) = grid_K_T(1:half,      :);
    txdataF(NFFT-half+1 : NFFT,   :) = grid_K_T(half+1:end,  :);
end

function NFFT = computeNFFT(SCS)
    base = 2048;  % SCS=15 kHz
    NFFT = base * SCS / 15;
end