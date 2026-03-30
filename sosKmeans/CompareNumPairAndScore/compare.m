% =========================================================================
% SCRIPT: SO SÁNH TRỰC TIẾP K-MEANS THUẦN VÀ K-MEANS + SOS (MU-MIMO)
% Dataset: 60,000 UEs (32T32R) -> Pool: 2000 UEs
% ĐÁNH GIÁ KHẮT KHE: DÙNG MIN (Khoảng cách tồi nhất) thay vì MEAN
% =========================================================================
clear; clc; close all;
setupPath();

% =========================================================================
% 1. Cấu hình Dữ liệu (32T32R)
% =========================================================================
prepareDataConfig = struct();
prepareDataConfig.Num_UEs           = 20000;
prepareDataConfig.N1                = 4;   
prepareDataConfig.N2                = 2;
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
poolConfig.targetPoolSize = 2000;  
poolConfig.kmeansMaxIter  = 100;


% =========================================================================
% LOCAL FUNCTIONS
% =========================================================================
function [validGroups, numValidGroups, avgValidScore, avgTotalScore] = scheduleAllUEsWithThreshold(W_matrix, groupSize, numClusters, threshold)
    [Num_Antennas, NumLayers, NUE] = size(W_matrix);
    maxPossibleGroups = floor(NUE / groupSize); 
    W_flat = reshape(W_matrix, Num_Antennas * NumLayers, NUE).';
    [cluster_idx, ~] = kmeans([real(W_flat), imag(W_flat)], numClusters, 'Distance', 'cosine', 'MaxIter', 100);
    
    cluster_ues = cell(numClusters, 1);
    for c = 1:numClusters
        members = find(cluster_idx == c);
        cluster_ues{c} = members(randperm(length(members))); 
    end
    
    validGroups = {}; validScores = []; allScores = []; 
    upperTriIdx = triu(true(groupSize), 1);
    
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
        distMatrix = 1 - (abs(W_group' * W_group).^2) ./ (sum(abs(W_group).^2, 1)' * sum(abs(W_group).^2, 1));
        
        % ĐỔI TỪ SUM/MEAN SANG MIN
        groupScore = min(distMatrix(upperTriIdx)); 
        
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
end
function [W_pool, pool_indices] = buildRepresentativePool(W_all, config)
    numClusters    = getField(config, 'numClusters',    50);
    targetPoolSize = getField(config, 'targetPoolSize', 200);
    kmeansMaxIter  = getField(config, 'kmeansMaxIter',  100);
    [Num_Antennas, NumLayers, Num_UEs] = size(W_all);
    W_flat     = reshape(W_all, Num_Antennas * NumLayers, Num_UEs).';
    W_features = [real(W_flat), imag(W_flat)];
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
end
function val = getField(s, fname, default)
    if isfield(s, fname), val = s.(fname); else, val = default; end
end