% =========================================================================
% SCRIPT: K-MEANS + SOS VS GREEDY MU-MIMO SCHEDULING FOR 60,000 UEs
% Antenna: 32T32R | Compare execution time between SOS and Greedy sweep
% =========================================================================
clear; clc; close all; 
setupPath();

nLayers = 4;

NumUEs = 20000;

% Cấu hình Codebook cho 4 Port (P_CSI-RS = 2 * N1 * N2 = 4)
cfg.CodeBookConfig.CodebookType = 'typeII-r16';
cfg.CodeBookConfig.N1 = 4;
cfg.CodeBookConfig.N2 = 1; 

% Bắt buộc paramCombination = 1 hoặc 2 khi cấu hình 4 Port
cfg.CodeBookConfig.ParamCombination = 2; % L=2, Beta=1/2, pv=1/8 (cho 4 layer)
cfg.CodeBookConfig.NumberOfPMISubbandsPerCQISubband = 1; % R = 1
cfg.CodeBookConfig.TypeIIRIRestriction = []; 
cfg.CodeBookConfig.SubbandAmplitude = true;

% O1, O2 tương ứng cho N1=2, N2=1
cfg.CodeBookConfig.O1 = 4;
cfg.CodeBookConfig.O2 = 1;

% Cấu hình Grid (Để ra N3 = 32)
cfg.CSIReportConfig.SubbandSize = 4; 
cfg.CarrierConfig.NStartGrid = 0;
cfg.CarrierConfig.NSizeGrid = 128; 

% =========================================================================
% 2. Prepare precoder matrix W for all UEs
% =========================================================================
disp('--- Generating data for 20,000 UEs (32T32R) ---');
[W_all, UE_Reported_Indices] = prepareData(cfg, nLayers, NumUEs);

% =========================================================================
% 3. Pre-Processing: Build representative UE pool via K-Means clustering
% =========================================================================
poolConfig = struct();
poolConfig.numClusters    = 50;
poolConfig.targetPoolSize = 200;
poolConfig.kmeansMaxIter  = 100;

disp('--- Running K-Means to build Representative Pool ---');
[W_pool, pool_indices, pool_pmi] = buildRepresentativePool(W_all, UE_Reported_Indices, poolConfig);

W1 = W_pool(:, :, 1);
W2 = W_pool(:, :, 2);
disp(W1);
disp(W2);
disp(abs(PMIPair(W1, W2)));

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

    bestScore = 1;
    ue1_idx   = -1;
    ue2_idx   = -1;

    fprintf('[PairSearch] Scanning %d UE pairs...\n', NUE*(NUE-1)/2);

    for i = 1:NUE-1
        for j = i+1:NUE
            Wi = W_pool(:, :, i);
            Wj = W_pool(:, :, j);

            results = PMIPair(Wi, Wj);
            score = abs(results);

            if score < bestScore
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
    fprintf('  Score = %.6f\n', bestScore);
    fprintf('========================================\n');

    fprintf('W1 (UE %d):\n', ue1_idx); disp(W1);
    fprintf('W2 (UE %d):\n', ue2_idx); disp(W2);
end

function [W_all, UE_Reported_Indices] = prepareData(config, nLayers, Num_UEs)
    N1 = config.CodeBookConfig.N1;
    N2 = config.CodeBookConfig.N2;

    Num_Antennas = 2 * N1 * N2;
    W_all = zeros(Num_Antennas, nLayers, Num_UEs);

    fprintf('Computing precoder matrix W_all...\n');
    for u = 1:Num_UEs
        PMI = randomTypeIIEnhancedPMI(config, nLayers);
        UE_Reported_Indices{u} = PMI;

        W_all(:, :, u) = generateEnhancedTypeIIPrecoder(config, nLayers, PMI.i1, PMI.i2);
    end
    fprintf('W_all completed: [%d x %d x %d]\n\n', size(W_all));

end % end prepareData

function [W_pool, pool_indices, pool_pmi] = buildRepresentativePool(W_all, UE_Reported_Indices, config)
% Thêm output pool_pmi và input UE_Reported_Indices

    numClusters    = getField(config, 'numClusters',    50);
    targetPoolSize = getField(config, 'targetPoolSize', 200);
    kmeansMaxIter  = getField(config, 'kmeansMaxIter',  100);

    [Num_Antennas, NumLayers, Num_UEs] = size(W_all);

    W_flat     = reshape(W_all, Num_Antennas * NumLayers, Num_UEs).';
    W_features = [real(W_flat), imag(W_flat)];

    fprintf('Running K-means (%d clusters) on %d UEs...\n', numClusters, Num_UEs);
    [cluster_idx, ~] = kmeans(W_features, numClusters, ...
                            'Distance', 'cosine',    ...
                            'MaxIter',  kmeansMaxIter);

    ues_per_cluster = ceil(targetPoolSize / numClusters);
    pool_indices = [];
    for c = 1:numClusters
        members     = find(cluster_idx == c);
        members     = members(randperm(length(members)));
        num_to_pick = min(ues_per_cluster, length(members));
        pool_indices = [pool_indices; members(1:num_to_pick)];
    end

    W_pool   = W_all(:, :, pool_indices);
    pool_pmi = UE_Reported_Indices(pool_indices);   % <-- cell array PMI theo pool

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
