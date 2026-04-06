% =========================================================================
% SCRIPT: K-MEANS + SOS VS GREEDY MU-MIMO SCHEDULING FOR 60,000 UEs
% Antenna: 32T32R | Compare execution time between SOS and Greedy sweep
% =========================================================================
clear; clc; close all; 
setupPath();

% =========================================================================
% 1. Configuration for test — 32T32R
% =========================================================================
prepareDataConfig = struct();
prepareDataConfig.Num_UEs           = 20000;
prepareDataConfig.N1                = 2;
prepareDataConfig.N2                = 1;
prepareDataConfig.O1                = 4;
prepareDataConfig.O2                = 4;
prepareDataConfig.L                 = 2;
prepareDataConfig.NumLayers         = 2;
prepareDataConfig.subbandAmplitude  = true;
prepareDataConfig.PhaseAlphabetSize = 4;

% =========================================================================
% 2. Prepare precoder matrix W for all UEs
% =========================================================================
disp('--- Generating data for 20,000 UEs (32T32R) ---');
[W_all, UE_Reported_Indices] = prepareData(prepareDataConfig);

% =========================================================================
% 3. Pre-Processing: Build representative UE pool via K-Means clustering
% =========================================================================
poolConfig = struct();
poolConfig.numClusters    = 500;
poolConfig.targetPoolSize = 2000;
poolConfig.kmeansMaxIter  = 100;

disp('--- Running K-Means to build Representative Pool ---');
[W_pool, pool_indices, pool_pmi] = buildRepresentativePool(W_all, UE_Reported_Indices, poolConfig);

fprintf("Choose Random PMI\n");
disp(W_pool(:, :, 1));
disp(W_pool(:, :, 2));

disp(abs(PMIPair(W_pool(:,:,1), W_pool(:,:,2))));

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
% TÌM CẶP UE TRỰC GIAO NHẤT TRONG TOÀN BỘ POOL
% =========================================================================
fprintf('\n[Pre-search] Finding most orthogonal UE pair in pool...\n');
[ue1, ue2, W1, W2, pairDist, pmi1, pmi2] = findBestOrthogonalPair(W_pool, pool_pmi);

% =========================================================================
% IN PMI CỦA CẶP UE ĐƯỢC CHỌN
% =========================================================================
fprintf('\n========================================\n');
fprintf('  PMI of selected UE pair\n');
fprintf('========================================\n');

fprintf('\n--- PMI UE %d (pool index) ---\n', ue1);
disp(pmi1);

fprintf('\n--- PMI UE %d (pool index) ---\n', ue2);
disp(pmi2);


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
    fprintf('  Score = %.15f\n', bestScore);
    fprintf('========================================\n');

    fprintf('W1 (UE %d):\n', ue1_idx); disp(W1);
    fprintf('W2 (UE %d):\n', ue2_idx); disp(W2);

    % In PMI indices
    printPMI(pmi1, ue1_idx);
    printPMI(pmi2, ue2_idx);
end

function printPMI(pmi, ue_idx)
    fprintf('\n--- PMI of UE %d ---\n', ue_idx);
    fields = fieldnames(pmi);
    for f = 1:numel(fields)
        fname = fields{f};
        val   = pmi.(fname);
        
        if iscell(val)
            % Cell array: in từng phần tử
            fprintf('  %s = { ', fname);
            for k = 1:numel(val)
                item = val{k};
                if isnumeric(item)
                    fprintf('[');
                    fprintf(' %g', item(:));
                    fprintf(' ]');
                else
                    fprintf(' %s', mat2str(item));
                end
                if k < numel(val)
                    fprintf(', ');
                end
            end
            fprintf(' }\n');
        elseif isnumeric(val)
            if isscalar(val)
                fprintf('  %s = %g\n', fname, val);
            else
                fprintf('  %s = [', fname);
                fprintf(' %g', val(:));
                fprintf(' ]\n');
            end
        else
            fprintf('  %s = %s\n', fname, mat2str(val));
        end
    end
end

function [W_all, UE_Reported_Indices] = prepareData(config)
    % --- Đọc thông số ---
    Num_UEs           = getField(config, 'Num_UEs',           20000);
    N1                = getField(config, 'N1',                2); % 32T32R tuỳ config của bác
    N2                = getField(config, 'N2',                1);
    O1                = getField(config, 'O1',                4);
    O2                = getField(config, 'O2',                4);
    L                 = getField(config, 'L',                 2);
    NumLayers         = getField(config, 'NumLayers',         2);
    subbandAmplitude  = getField(config, 'subbandAmplitude',  true);
    PhaseAlphabetSize = getField(config, 'PhaseAlphabetSize', 4);

    % --- 1. SINH 1 BỘ PMI NGẪU NHIÊN ĐỂ LẤY CHUẨN W1 ---
    fprintf('Đang lấy 1 cấu hình W1 chuẩn để chốt cứng...\n');
    dummy_PMI = randomPMIConfig(1, N1, N2, O1, O2, L, NumLayers, subbandAmplitude);
    
    % %%% CỐ ĐỊNH W1 TẠI ĐÂY %%%
    % Trích xuất đúng cái i1 của nó ra làm chuẩn mực cho toàn bộ hệ thống
    FIXED_i1 = dummy_PMI{1}.i1; 
    disp('Cấu hình i1 (W1) đã được chốt cứng:');
    disp(FIXED_i1);

    % --- 2. TẠO 20.000 UE NHƯNG BẮT DÙNG CHUNG W1 ---
    fprintf('Tạo %d UEs (Chung W1, ngẫu nhiên W2)...\n', Num_UEs);
    UE_Reported_Indices = randomPMIConfig(Num_UEs, N1, N2, O1, O2, L, NumLayers, subbandAmplitude);
    
    for u = 1:Num_UEs
        % Ép toàn bộ UE phải xài chung cái FIXED_i1 này
        % Các UE giờ chỉ khác nhau ở biến i2 (W2)
        UE_Reported_Indices{u}.i1 = FIXED_i1; 
    end

    % --- 3. TÍNH TOÁN MA TRẬN W TỔNG ---
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

    fprintf('Đang tính toán ma trận W cho tất cả UEs...\n');
    for u = 1:Num_UEs
        indices_ue = UE_Reported_Indices{u};
        % Vì i1 giống hệt nhau, hàm này bản chất là sinh ra W dựa trên W1 cố định và W2 khác nhau
        W_all(:, :, u) = generateTypeIIPrecoder(cfg, indices_ue.i1, indices_ue.i2);
    end
    fprintf('Hoàn tất tính toán W: [%d x %d x %d]\n\n', size(W_all));
end

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
