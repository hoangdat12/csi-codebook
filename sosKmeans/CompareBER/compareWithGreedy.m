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
poolConfig.numClusters    = 100;
poolConfig.targetPoolSize = 500;
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
% 5. Run scheduling comparison across group sizes 2 to 12
% =========================================================================
maxIter    = 100;
groupSizes = 2:12;

final_results = runSchedulingComparison(W_pool, phyConfig, groupSizes, maxIter);

% =========================================================================
% LOCAL FUNCTIONS 
% =========================================================================

function [bestGroups, bestScore] = sosMUMIMOScheduling(W_all, groupSize, maxIter)
    NUE = size(W_all, 3);
    
    popSize = 30; 
    
    numGroups = floor(NUE / groupSize);
    population = zeros(popSize, NUE);
    for p = 1:popSize
        population(p, :) = randperm(NUE);
    end
    
    disp('      [SOS] Computing distance matrix...');
    distMat = zeros(NUE, NUE);
    for i = 1:NUE-1
        for j = i+1:NUE
            distMat(i, j) = chordalDistance(W_all(:,:,i), W_all(:,:,j));
            distMat(j, i) = distMat(i, j); % Symmetric matrix
        end
    end
    
    fitnessFunc = @(perm) computeScheduleFitnessOptimize(perm, distMat, groupSize, numGroups);
    
    fitness = zeros(popSize, 1);
    for p = 1:popSize
        fitness(p) = fitnessFunc(population(p, :));
    end
    
    [bestScore, bestIdx] = max(fitness);
    bestPerm = population(bestIdx, :);
    
    no_improve_counter = 0;
    max_no_improve = 15; % Stop if no improvement after 15 consecutive iterations
    
    disp('      [SOS] Starting evolutionary generations...');
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
        
        % Update best score
        [curBest, curIdx] = max(fitness);
        if curBest > bestScore
            bestScore = curBest;
            bestPerm = population(curIdx, :);
            no_improve_counter = 0; % Reset counter if improvement found
        else
            no_improve_counter = no_improve_counter + 1;
        end
        
        % Check early stopping condition
        if no_improve_counter >= max_no_improve
            fprintf('      [SOS] Algorithm converged early at iteration %d (Score: %.4f)\n', iter, bestScore);
            break;
        end
    end
    
    % Extract best group assignments
    bestGroups = cell(numGroups, 1);
    for g = 1:numGroups
        idx = (g-1)*groupSize + 1 : g*groupSize;
        bestGroups{g} = bestPerm(idx);
    end
end

% =========================================================================
% FITNESS FUNCTION (lookup from precomputed distance matrix)
% =========================================================================
function score = computeScheduleFitnessOptimize(perm, distMat, groupSize, numGroups)
    totalDist = 0;
    numPairsPerGroup = groupSize * (groupSize - 1) / 2;
    
    for g = 1:numGroups
        idx = (g-1)*groupSize + 1 : g*groupSize;
        ueIdx = perm(idx);
        groupDist = 0;
        
        % Direct lookup from distMat, bypassing chordalDistance function
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
% MUTATION / CROSSOVER OPERATORS
% =========================================================================
function newPerm = mutualismSwap(permA, permB)
    n = length(permA);
    pts = sort(randperm(n, 2));
    segment = permB(pts(1):pts(2));
    
    remaining = permA(~ismember(permA, segment));  
    
    maxInsert = length(remaining) + 1; 
    insertPos = randi(maxInsert);
    
    newPerm = [remaining(1:insertPos-1), segment, remaining(insertPos:end)];
    
    assert(length(newPerm) == n, 'Error: newPerm length mismatch after Swap!');
end

function newPerm = commensalismSwap(permA, ~)
    newPerm = permA;
    pts = randperm(length(permA), 2);
    % Swap two random elements
    temp = newPerm(pts(1));
    newPerm(pts(1)) = newPerm(pts(2));
    newPerm(pts(2)) = temp;
end

function parasite = parasitePerturb(perm)
    parasite = perm;
    n = length(perm);
    pts = sort(randperm(n, 2));
    % Randomly shuffle a sub-segment
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

function BER_list = simulateMuMimoGroup(W_pool, bestGroups, config, groupSize)
    fprintf('--- Starting MU-MIMO simulation for group of %d UEs ---\n', groupSize);

    best_group = bestGroups{1};
    ue_idx     = best_group(1:groupSize);

    fprintf('Selected UEs: '); fprintf('%d ', ue_idx); fprintf('from Sub-pool.\n');

    W_list  = cell(groupSize, 1);
    for u = 1:groupSize
        W_list{u} = W_pool(:, :, ue_idx(u));
    end

    nLayers     = size(W_list{1}, 2);
    totalPorts  = groupSize * nLayers;  % Total number of required DMRS ports
    MCS         = config.MCS;

    pdsch = customPDSCHConfig();
    pdsch.NumLayers = nLayers;
    pdsch.PRBSet    = config.PRBSet;
    pdsch.DMRS.DMRSAdditionalPosition = 1;

    % =========================================================
    % Select DMRS Type and Length
    % =========================================================
    if totalPorts <= 4
        pdsch.DMRS.DMRSConfigurationType = 1;
        pdsch.DMRS.DMRSLength            = 1;
    elseif totalPorts <= 8
        pdsch.DMRS.DMRSConfigurationType = 1;
        pdsch.DMRS.DMRSLength            = 2;
    else
        % Use Type 2, Length 2 to support up to 12 orthogonal ports
        pdsch.DMRS.DMRSConfigurationType = 2;
        pdsch.DMRS.DMRSLength            = 2;
        if totalPorts > 12
            fprintf('[Note] %d ports requested. DMRS Port Reuse and Scrambling will be applied.\n', totalPorts);
        end
    end

    carrier = nrCarrierConfig;
    carrier.SubcarrierSpacing = config.SubcarrierSpacing;
    carrier.NSizeGrid         = config.NSizeGrid;

    SNR_dB = config.SNR_dB;
    fprintf('Running MU-MIMO: SNR=%d dB, DMRSType=%d, DMRSLength=%d, TotalPorts=%d...\n', ...
        SNR_dB, pdsch.DMRS.DMRSConfigurationType, pdsch.DMRS.DMRSLength, totalPorts);

    BER_list = muMimo(carrier, pdsch, W_list, MCS, SNR_dB);

    fprintf('\n================ RESULTS ================\n');
    for u = 1:groupSize
        fprintf('BER UE %d (ID: %d): %.6f\n', u, ue_idx(u), BER_list(u));
    end
    disp('=========================================');
end

function BER_list = muMimo(carrier, basePDSCHConfig, UE_W_list, MCS, SNR_dB)

    numUE    = length(UE_W_list);
    nLayers  = size(UE_W_list{1}, 2);
    dmrsType = basePDSCHConfig.DMRS.DMRSConfigurationType;

    % Maximum ports per CDM group based on DMRS Type
    if dmrsType == 1
        portsPerSymbol = 4;   % Ports 0-3 (length=1), 0-7 (length=2)
    else
        portsPerSymbol = 6;   % Ports 0-5 (length=1), 0-11 (length=2)
    end
    
    maxPortIndex = portsPerSymbol * basePDSCHConfig.DMRS.DMRSLength - 1;

    pdsch_list     = cell(numUE, 1);
    inputBits_list = cell(numUE, 1);
    TBS_list       = zeros(numUE, 1);

    for u = 1:numUE
        pd = basePDSCHConfig;
        
        % Assign logical ports sequentially per UE
        logicalPortStart = (u-1) * nLayers;
        logicalPorts     = logicalPortStart : logicalPortStart + nLayers - 1;

        % --- CẬP NHẬT DMRS PORT REUSE & SCRAMBLING ---
        physicalPorts = mod(logicalPorts, maxPortIndex + 1);
        pd.DMRS.DMRSPortSet = physicalPorts;
        
        % Alternate NSCID to reduce inter-user interference under port reuse
        reuseFactor = floor(logicalPortStart / (maxPortIndex + 1));
        pd.DMRS.NSCID = mod(reuseFactor, 2);
        
        % Đảm bảo chuỗi DMRS được xáo trộn khác nhau khi tái sử dụng port
        pd.DMRS.NIDNSCID = pd.DMRS.NSCID; 
        
        % Configure CDM groups to prevent PDSCH from overlapping DMRS
        if dmrsType == 1
            pd.DMRS.NumCDMGroupsWithoutData = 2; 
        else
            pd.DMRS.NumCDMGroupsWithoutData = 3; 
        end
        % -----------------------------

        pd = pd.setMCS(MCS);
        [~, pInfo] = nrPDSCHIndices(carrier, pd);
        TBS = nrTBS(pd.Modulation, pd.NumLayers, length(pd.PRBSet), pInfo.NREPerPRB, pd.TargetCodeRate);

        pdsch_list{u}     = pd;
        TBS_list(u)       = TBS;
        inputBits_list{u} = randi([0 1], TBS, 1);
    end

    % MMSE Precoding
    H_composite = cell2mat(cellfun(@(w) w', UE_W_list(:), 'UniformOutput', false));
    W_total_T   = getMMSEPrecoder(H_composite, SNR_dB);

    % --- CẬP NHẬT CHUẨN HÓA VÀ PHÂN BỔ CÔNG SUẤT (EQUAL POWER ALLOCATION) ---
    % Chuẩn hóa tổng thể ma trận tiền mã hóa
    normFactor = norm(W_total_T, 'fro');
    W_total_T_norm = W_total_T / normFactor;

    W_list = cell(numUE, 1);
    for u = 1:numUE
        rowStart  = (u-1)*nLayers + 1;
        W_ue = W_total_T_norm(rowStart : u*nLayers, :);
        
        % Cân bằng năng lượng cho từng UE
        W_list{u} = W_ue / norm(W_ue, 'fro') * sqrt(1/numUE);
    end
    % -----------------------------

    % Resource mapping and OFDM modulation
    numTxPorts = size(W_list{1}, 2); % Number of transmit antenna ports
    txGrid   = nrResourceGrid(carrier, numTxPorts);

    for u = 1:numUE
        [sym, ind]           = PDSCHEncode(pdsch_list{u}, carrier, inputBits_list{u});
        [antSym, antInd]     = nrPDSCHPrecode(carrier, sym, ind, W_list{u});
        dSym                 = nrPDSCHDMRS(carrier, pdsch_list{u});
        dInd                 = nrPDSCHDMRSIndices(carrier, pdsch_list{u});
        [dAntSym, dAntInd]   = nrPDSCHPrecode(carrier, dSym, dInd, W_list{u});

        txGrid(antInd)  = txGrid(antInd)  + antSym;
        txGrid(dAntInd) = txGrid(dAntInd) + dAntSym;
    end

    txWaveform = nrOFDMModulate(carrier, txGrid);

    % =====================================================================
    % CHANNEL MODEL + PHYSICAL AWGN NOISE
    % =====================================================================
    BER_list = zeros(numUE, 1);
    
    % Measure average transmit signal power across all antennas
    txPower = mean(var(txWaveform)); 
    
    % Compute noise variance N0 from SNR
    SNR_linear = 10^(SNR_dB / 10);
    noiseVar = txPower / SNR_linear;
    numSamples = size(txWaveform, 1);

    for u = 1:numUE
        % Received signal at UE u = transmitted signal passed through effective channel
        rx_signal = txWaveform * H_composite(u,:).';
        
        % Add independent AWGN noise
        noise = sqrt(noiseVar/2) * (randn(numSamples, 1) + 1i*randn(numSamples, 1));
        rxWaveform_noisy = rx_signal + noise;
        
        % Decode and compute BER
        rxBits      = rxPDSCHDecode(carrier, pdsch_list{u}, rxWaveform_noisy, txWaveform, TBS_list(u));
        BER_list(u) = biterr(double(inputBits_list{u}), double(rxBits)) / TBS_list(u);
    end
end

function val = getField(s, fname, default)
    if isfield(s, fname)
        val = s.(fname);
    else
        val = default;
    end
end

function results = runSchedulingComparison(W_pool, phyConfig, groupSizes, maxIter)
    % =========================================================================
    % COMPARE SOS VS GREEDY ACROSS 4 METRICS
    % =========================================================================

    if nargin < 4
        maxIter = 100;
    end

    nScenarios = length(groupSizes);

    % Initialize result arrays
    results = struct();
    results.time_SOS          = zeros(1, nScenarios);
    results.time_Greedy       = zeros(1, nScenarios);
    results.score_SOS         = zeros(1, nScenarios);
    results.score_Greedy      = zeros(1, nScenarios);
    results.num_groups_SOS    = zeros(1, nScenarios);
    results.num_groups_Greedy = zeros(1, nScenarios);
    results.BER_SOS           = cell(1, nScenarios);
    results.BER_Greedy        = cell(1, nScenarios);

    % Arrays for average BER (used for plotting)
    results.avg_BER_SOS       = zeros(1, nScenarios);
    results.avg_BER_Greedy    = zeros(1, nScenarios);

    % =========================================================================
    % MAIN LOOP: RUN ALL SCENARIOS
    % =========================================================================
    for s = 1:nScenarios
        gs = groupSizes(s);

        fprintf('\n');
        disp('############################################################');
        fprintf('             SCENARIO %d: MU-MIMO GROUP SIZE = %d             \n', s, gs);
        disp('############################################################');

        % --- SOS Algorithm ---
        tic;
        [bestGroups_SOS, results.score_SOS(s)] = sosMUMIMOScheduling(W_pool, gs, maxIter);
        results.time_SOS(s) = toc;
        results.num_groups_SOS(s) = length(bestGroups_SOS);

        fprintf('--- PHY Layer simulation for best SOS group (%d UEs) ---\n', gs);
        BER_SOS = simulateMuMimoGroup(W_pool, bestGroups_SOS, phyConfig, gs);
        results.BER_SOS{s}      = BER_SOS;
        results.avg_BER_SOS(s)  = mean(BER_SOS);

        % --- Greedy Algorithm ---
        [bestGroups_Greedy, results.time_Greedy(s), results.score_Greedy(s), BER_Greedy] = ...
            runGreedyOptimize(W_pool, phyConfig, results.time_SOS(s), results.score_SOS(s), gs);

        results.num_groups_Greedy(s) = length(bestGroups_Greedy);
        results.BER_Greedy{s}        = BER_Greedy;
        results.avg_BER_Greedy(s)    = mean(BER_Greedy);

        fprintf('\n--- Average BER SOS    (GroupSize=%d): %.6f', gs, results.avg_BER_SOS(s));
        fprintf('\n--- Average BER Greedy (GroupSize=%d): %.6f\n', gs, results.avg_BER_Greedy(s));
    end

    % =========================================================================
    % SUMMARY TABLE — 4 METRICS
    % =========================================================================
    fprintf('\n');
    disp('================================================================================================================================');
    disp('                              SUMMARY TABLE — 4 METRICS: SOS VS GREEDY — 32T32R                                                 ');
    disp('================================================================================================================================');
    fprintf('%-10s | %-16s | %-26s | %-26s | %-26s\n', ...
        'Group Size', 'Groups Formed', 'Execution Time (s)', 'Orthogonality Score', 'Average BER');
    fprintf('%-10s | %-7s  %-7s | %-12s  %-11s | %-12s  %-11s | %-12s  %-11s\n', ...
        '', 'SOS', 'Greedy', 'SOS', 'Greedy', 'SOS', 'Greedy', 'SOS', 'Greedy');
    disp('--------------------------------------------------------------------------------------------------------------------------------');

    for s = 1:nScenarios
        groupLabel = sprintf('%d', groupSizes(s));

        fprintf('%-10s | %-7d  %-7d | %-12.4f  %-11.4f | %-12.4f  %-11.4f | %-12.6f  %-11.6f\n', ...
            groupLabel, ...
            results.num_groups_SOS(s),  results.num_groups_Greedy(s), ...
            results.time_SOS(s),        results.time_Greedy(s), ...
            results.score_SOS(s),       results.score_Greedy(s), ...
            results.avg_BER_SOS(s),     results.avg_BER_Greedy(s));
    end
    disp('================================================================================================================================');

    % =========================================================================
    % COMPARISON PLOTS — 4 METRICS
    % =========================================================================
    figure('Name', 'MU-MIMO Algorithm Comparison — 4 Metrics', 'NumberTitle', 'off', 'Position', [100, 50, 1000, 700]);

    % 1. Execution time (log scale to highlight differences)
    subplot(2, 2, 1);
    bar(groupSizes, [results.time_SOS; results.time_Greedy]');
    set(gca, 'YScale', 'log');
    legend('SOS', 'Greedy', 'Location', 'northwest');
    xlabel('Group Size (UEs)'); ylabel('Time (seconds) — Log Scale');
    title('1. Execution Time');
    set(gca, 'XTick', groupSizes);
    grid on;

    % 2. Orthogonality score
    subplot(2, 2, 2);
    bar(groupSizes, [results.score_SOS; results.score_Greedy]');
    legend('SOS', 'Greedy', 'Location', 'southwest');
    xlabel('Group Size (UEs)'); ylabel('Orthogonality Score');
    title('2. Spatial Orthogonality Score');
    set(gca, 'XTick', groupSizes);
    grid on;

    % 3. Number of groups formed
    subplot(2, 2, 3);
    bar(groupSizes, [results.num_groups_SOS; results.num_groups_Greedy]');
    legend('SOS', 'Greedy', 'Location', 'southwest');
    xlabel('Group Size (UEs)'); ylabel('Groups Completed');
    title('3. Grouping Capacity (User Drop Rate)');
    set(gca, 'XTick', groupSizes);
    grid on;

    % 4. Bit Error Rate (line plot to show trend, eps added to avoid log(0))
    subplot(2, 2, 4);
    semilogy(groupSizes, results.avg_BER_SOS    + eps, '-o', 'LineWidth', 2, 'MarkerSize', 6); hold on;
    semilogy(groupSizes, results.avg_BER_Greedy + eps, '-s', 'LineWidth', 2, 'MarkerSize', 6);
    legend('SOS', 'Greedy', 'Location', 'northwest');
    xlabel('Group Size (UEs)'); ylabel('Average BER — Log Scale');
    title('4. Bit Error Rate (BER)');
    set(gca, 'XTick', groupSizes);
    grid on;

    sgtitle(sprintf('SOS vs Greedy Comparison — 32T32R, Pool=%d UEs', size(W_pool, 3)), ...
        'FontSize', 14, 'FontWeight', 'bold');
end

function [bestGroups_Greedy, time_greedy, avg_score_greedy, BER_results] = runGreedyOptimize(W_pool, phyConfig, timeSOS, bestScore_SOS, groupSize)
    fprintf('--- Bắt đầu thuật toán Greedy TỐI ƯU HÓA cho %d UEs ---\n', groupSize);
    tic;

    Actual_Pool_Size  = size(W_pool, 3);
    available_ues     = 1:Actual_Pool_Size;
    num_groups_to_find = floor(Actual_Pool_Size / groupSize);

    % =========================================================
    % Tính trước Ma trận khoảng cách
    % =========================================================
    disp('Đang tính toán Ma trận khoảng cách...');
    distMat = zeros(Actual_Pool_Size, Actual_Pool_Size);
    for i = 1:Actual_Pool_Size-1
        for j = i+1:Actual_Pool_Size
            distMat(i,j) = chordalDistance(W_pool(:,:,i), W_pool(:,:,j));
            distMat(j,i) = distMat(i,j);
        end
    end

    total_loop_score  = 0;
    completed_groups  = 0;
    bestGroups_Greedy = {};
    BER_results       = [];
    timeout_limit     = 5 * 60;

    for g = 1:num_groups_to_find
        if toc > timeout_limit
            fprintf('\n[TIMEOUT] Dừng tại nhóm thứ %d\n', g);
            break;
        end

        N_avail = length(available_ues);
        if N_avail < groupSize, break; end

        best_group_score  = -1;
        best_idx_in_avail = 1:groupSize;
        found_any         = false;

        % =========================================================
        % Duyệt tổ hợp theo groupSize — vòng lặp tường minh O(1) lookup
        % Bổ sung cơ chế TIMEOUT 60 giây (1 phút)
        % =========================================================
        timeout_limit = 60; % Giới hạn 60 giây
        t_search = tic;     % Bắt đầu bấm giờ
        time_out_flag = false;
        loop_counter = 0;

        switch groupSize
            % case 2
            %     for i = 1:N_avail-1
            %         if time_out_flag, break; end
            %         idx_a = available_ues(i);
            %         for j = i+1:N_avail
            %             idx_b = available_ues(j);
            % 
            %             % --- KIỂM TRA TIMEOUT ---
            %             loop_counter = loop_counter + 1;
            %             if mod(loop_counter, 100000) == 0 && toc(t_search) > timeout_limit
            %                 fprintf('[TIMEOUT] Dừng quét nhóm 2 sau %.1f giây (%d tổ hợp).\n', toc(t_search), loop_counter);
            %                 time_out_flag = true; break;
            %             end
            % 
            %             avg_score = distMat(idx_a, idx_b);
            %             if avg_score > best_group_score
            %                 best_group_score  = avg_score;
            %                 best_idx_in_avail = [i, j];
            %                 found_any = true;
            %             end
            %         end
            %     end
            % 
            % case 3
            %     for i = 1:N_avail-2
            %         if time_out_flag, break; end
            %         idx_a = available_ues(i);
            %         for j = i+1:N_avail-1
            %             if time_out_flag, break; end
            %             idx_b = available_ues(j);
            %             d1 = distMat(idx_a, idx_b);
            %             for k = j+1:N_avail
            %                 idx_c = available_ues(k);
            % 
            %                 % --- KIỂM TRA TIMEOUT ---
            %                 loop_counter = loop_counter + 1;
            %                 if mod(loop_counter, 100000) == 0 && toc(t_search) > timeout_limit
            %                     fprintf('[TIMEOUT] Dừng quét nhóm 3 sau %.1f giây (%d tổ hợp).\n', toc(t_search), loop_counter);
            %                     time_out_flag = true; break;
            %                 end
            % 
            %                 avg_score = (d1 + distMat(idx_a,idx_c) + distMat(idx_b,idx_c)) / 3;
            %                 if avg_score > best_group_score
            %                     best_group_score  = avg_score;
            %                     best_idx_in_avail = [i, j, k];
            %                     found_any = true;
            %                 end
            %             end
            %         end
            %     end
            % 
            % case 4
            %     for i = 1:N_avail-3
            %         if time_out_flag, break; end
            %         idx_a = available_ues(i);
            %         for j = i+1:N_avail-2
            %             if time_out_flag, break; end
            %             idx_b = available_ues(j);
            %             d1 = distMat(idx_a, idx_b);
            %             for k = j+1:N_avail-1
            %                 if time_out_flag, break; end
            %                 idx_c = available_ues(k);
            %                 d2 = distMat(idx_a, idx_c);
            %                 d4 = distMat(idx_b, idx_c);
            %                 for l = k+1:N_avail
            %                     idx_d = available_ues(l);
            % 
            %                     % --- KIỂM TRA TIMEOUT ---
            %                     loop_counter = loop_counter + 1;
            %                     if mod(loop_counter, 100000) == 0 && toc(t_search) > timeout_limit
            %                         fprintf('[TIMEOUT] Dừng quét nhóm 4 sau %.1f giây (%d tổ hợp).\n', toc(t_search), loop_counter);
            %                         time_out_flag = true; break;
            %                     end
            % 
            %                     avg_score = (d1 + d2 + distMat(idx_a,idx_d) + ...
            %                                 d4 + distMat(idx_b,idx_d) + distMat(idx_c,idx_d)) / 6;
            %                     if avg_score > best_group_score
            %                         best_group_score  = avg_score;
            %                         best_idx_in_avail = [i, j, k, l];
            %                         found_any = true;
            %                     end
            %                 end
            %             end
            %         end
            %     end
            % 
            % % =========================================================
            % % CASE 5: 5 VÒNG LẶP LỒNG NHAU (10 CẶP KHOẢNG CÁCH)
            % % =========================================================
            % case 5
            %     for i = 1:N_avail-4
            %         if time_out_flag, break; end
            %         idx_a = available_ues(i);
            %         for j = i+1:N_avail-3
            %             if time_out_flag, break; end
            %             idx_b = available_ues(j);
            %             for k = j+1:N_avail-2
            %                 if time_out_flag, break; end
            %                 idx_c = available_ues(k);
            %                 for l = k+1:N_avail-1
            %                     if time_out_flag, break; end
            %                     idx_d = available_ues(l);
            %                     for m = l+1:N_avail
            %                         idx_e = available_ues(m);
            % 
            %                         % --- KIỂM TRA TIMEOUT ---
            %                         loop_counter = loop_counter + 1;
            %                         if mod(loop_counter, 100000) == 0 && toc(t_search) > timeout_limit
            %                             fprintf('[TIMEOUT] Dừng quét nhóm 5 sau %.1f giây (%d tổ hợp).\n', toc(t_search), loop_counter);
            %                             time_out_flag = true; break;
            %                         end
            % 
            %                         avg_score = (distMat(idx_a,idx_b) + distMat(idx_a,idx_c) + distMat(idx_a,idx_d) + distMat(idx_a,idx_e) + ...
            %                                     distMat(idx_b,idx_c) + distMat(idx_b,idx_d) + distMat(idx_b,idx_e) + ...
            %                                     distMat(idx_c,idx_d) + distMat(idx_c,idx_e) + ...
            %                                     distMat(idx_d,idx_e)) / 10;
            % 
            %                         if avg_score > best_group_score
            %                             best_group_score  = avg_score;
            %                             best_idx_in_avail = [i, j, k, l, m];
            %                             found_any = true;
            %                         end
            %                     end
            %                 end
            %             end
            %         end
            %     end
            % 
            % % =========================================================
            % % CASE 6: 6 VÒNG LẶP LỒNG NHAU (15 CẶP KHOẢNG CÁCH)
            % % =========================================================
            % case 6
            %     for i = 1:N_avail-5
            %         if time_out_flag, break; end
            %         idx_a = available_ues(i);
            %         for j = i+1:N_avail-4
            %             if time_out_flag, break; end
            %             idx_b = available_ues(j);
            %             for k = j+1:N_avail-3
            %                 if time_out_flag, break; end
            %                 idx_c = available_ues(k);
            %                 for l = k+1:N_avail-2
            %                     if time_out_flag, break; end
            %                     idx_d = available_ues(l);
            %                     for m = l+1:N_avail-1
            %                         if time_out_flag, break; end
            %                         idx_e = available_ues(m);
            %                         for n = m+1:N_avail
            %                             idx_f = available_ues(n);
            % 
            %                             % --- KIỂM TRA TIMEOUT ---
            %                             loop_counter = loop_counter + 1;
            %                             if mod(loop_counter, 100000) == 0 && toc(t_search) > timeout_limit
            %                                 fprintf('[TIMEOUT] Dừng quét nhóm 6 sau %.1f giây (%d tổ hợp).\n', toc(t_search), loop_counter);
            %                                 time_out_flag = true; break;
            %                             end
            % 
            %                             avg_score = (distMat(idx_a,idx_b) + distMat(idx_a,idx_c) + distMat(idx_a,idx_d) + distMat(idx_a,idx_e) + distMat(idx_a,idx_f) + ...
            %                                         distMat(idx_b,idx_c) + distMat(idx_b,idx_d) + distMat(idx_b,idx_e) + distMat(idx_b,idx_f) + ...
            %                                         distMat(idx_c,idx_d) + distMat(idx_c,idx_e) + distMat(idx_c,idx_f) + ...
            %                                         distMat(idx_d,idx_e) + distMat(idx_d,idx_f) + ...
            %                                         distMat(idx_e,idx_f)) / 15;
            % 
            %                             if avg_score > best_group_score
            %                                 best_group_score  = avg_score;
            %                                 best_idx_in_avail = [i, j, k, l, m, n];
            %                                 found_any = true;
            %                             end
            %                         end
            %                     end
            %                 end
            %             end
            %         end
            %     end
            % 
            % % =========================================================
            % % CASE 7: 7 VÒNG LẶP LỒNG NHAU (21 CẶP KHOẢNG CÁCH)
            % % =========================================================
            % case 7
            %     for i = 1:N_avail-6
            %         if time_out_flag, break; end
            %         idx_a = available_ues(i);
            %         for j = i+1:N_avail-5
            %             if time_out_flag, break; end
            %             idx_b = available_ues(j);
            %             for k = j+1:N_avail-4
            %                 if time_out_flag, break; end
            %                 idx_c = available_ues(k);
            %                 for l = k+1:N_avail-3
            %                     if time_out_flag, break; end
            %                     idx_d = available_ues(l);
            %                     for m = l+1:N_avail-2
            %                         if time_out_flag, break; end
            %                         idx_e = available_ues(m);
            %                         for n = m+1:N_avail-1
            %                             if time_out_flag, break; end
            %                             idx_f = available_ues(n);
            %                             for o = n+1:N_avail
            %                                 idx_g = available_ues(o);
            % 
            %                                 % --- KIỂM TRA TIMEOUT ---
            %                                 loop_counter = loop_counter + 1;
            %                                 if mod(loop_counter, 100000) == 0 && toc(t_search) > timeout_limit
            %                                     fprintf('[TIMEOUT] Dừng quét nhóm 7 sau %.1f giây (%d tổ hợp).\n', toc(t_search), loop_counter);
            %                                     time_out_flag = true; break;
            %                                 end
            % 
            %                                 avg_score = (distMat(idx_a,idx_b) + distMat(idx_a,idx_c) + distMat(idx_a,idx_d) + distMat(idx_a,idx_e) + distMat(idx_a,idx_f) + distMat(idx_a,idx_g) + ...
            %                                             distMat(idx_b,idx_c) + distMat(idx_b,idx_d) + distMat(idx_b,idx_e) + distMat(idx_b,idx_f) + distMat(idx_b,idx_g) + ...
            %                                             distMat(idx_c,idx_d) + distMat(idx_c,idx_e) + distMat(idx_c,idx_f) + distMat(idx_c,idx_g) + ...
            %                                             distMat(idx_d,idx_e) + distMat(idx_d,idx_f) + distMat(idx_d,idx_g) + ...
            %                                             distMat(idx_e,idx_f) + distMat(idx_e,idx_g) + ...
            %                                             distMat(idx_f,idx_g)) / 21;
            % 
            %                                 if avg_score > best_group_score
            %                                     best_group_score  = avg_score;
            %                                     best_idx_in_avail = [i, j, k, l, m, n, o];
            %                                     found_any = true;
            %                                 end
            %                             end
            %                         end
            %                     end
            %                 end
            %             end
            %         end
            %     end
            % 
            % % =========================================================
            % % CASE 8: 8 VÒNG LẶP LỒNG NHAU (28 CẶP KHOẢNG CÁCH)
            % % =========================================================
            % case 8
            %     for i = 1:N_avail-7
            %         if time_out_flag, break; end
            %         idx_a = available_ues(i);
            %         for j = i+1:N_avail-6
            %             if time_out_flag, break; end
            %             idx_b = available_ues(j);
            %             for k = j+1:N_avail-5
            %                 if time_out_flag, break; end
            %                 idx_c = available_ues(k);
            %                 for l = k+1:N_avail-4
            %                     if time_out_flag, break; end
            %                     idx_d = available_ues(l);
            %                     for m = l+1:N_avail-3
            %                         if time_out_flag, break; end
            %                         idx_e = available_ues(m);
            %                         for n = m+1:N_avail-2
            %                             if time_out_flag, break; end
            %                             idx_f = available_ues(n);
            %                             for o = n+1:N_avail-1
            %                                 if time_out_flag, break; end
            %                                 idx_g = available_ues(o);
            %                                 for p = o+1:N_avail
            %                                     idx_h = available_ues(p);
            % 
            %                                     % --- KIỂM TRA TIMEOUT ---
            %                                     loop_counter = loop_counter + 1;
            %                                     if mod(loop_counter, 100000) == 0 && toc(t_search) > timeout_limit
            %                                         fprintf('[TIMEOUT] Dừng quét nhóm 8 sau %.1f giây (%d tổ hợp).\n', toc(t_search), loop_counter);
            %                                         time_out_flag = true; break;
            %                                     end
            % 
            %                                     avg_score = (distMat(idx_a,idx_b) + distMat(idx_a,idx_c) + distMat(idx_a,idx_d) + distMat(idx_a,idx_e) + distMat(idx_a,idx_f) + distMat(idx_a,idx_g) + distMat(idx_a,idx_h) + ...
            %                                                 distMat(idx_b,idx_c) + distMat(idx_b,idx_d) + distMat(idx_b,idx_e) + distMat(idx_b,idx_f) + distMat(idx_b,idx_g) + distMat(idx_b,idx_h) + ...
            %                                                 distMat(idx_c,idx_d) + distMat(idx_c,idx_e) + distMat(idx_c,idx_f) + distMat(idx_c,idx_g) + distMat(idx_c,idx_h) + ...
            %                                                 distMat(idx_d,idx_e) + distMat(idx_d,idx_f) + distMat(idx_d,idx_g) + distMat(idx_d,idx_h) + ...
            %                                                 distMat(idx_e,idx_f) + distMat(idx_e,idx_g) + distMat(idx_e,idx_h) + ...
            %                                                 distMat(idx_f,idx_g) + distMat(idx_f,idx_h) + ...
            %                                                 distMat(idx_g,idx_h)) / 28;
            % 
            %                                     if avg_score > best_group_score
            %                                         best_group_score  = avg_score;
            %                                         best_idx_in_avail = [i, j, k, l, m, n, o, p];
            %                                         found_any = true;
            %                                     end
            %                                 end
            %                             end
            %                         end
            %                     end
            %                 end
            %             end
            %         end
            %     end
            % 
            % % =========================================================
            % % CASE 9: 9 VÒNG LẶP LỒNG NHAU (36 CẶP KHOẢNG CÁCH)
            % % =========================================================
            % case 9
            %     for i = 1:N_avail-8
            %         if time_out_flag, break; end; idx_a = available_ues(i);
            %         for j = i+1:N_avail-7
            %             if time_out_flag, break; end; idx_b = available_ues(j);
            %             for k = j+1:N_avail-6
            %                 if time_out_flag, break; end; idx_c = available_ues(k);
            %                 for l = k+1:N_avail-5
            %                     if time_out_flag, break; end; idx_d = available_ues(l);
            %                     for m = l+1:N_avail-4
            %                         if time_out_flag, break; end; idx_e = available_ues(m);
            %                         for n = m+1:N_avail-3
            %                             if time_out_flag, break; end; idx_f = available_ues(n);
            %                             for o = n+1:N_avail-2
            %                                 if time_out_flag, break; end; idx_g = available_ues(o);
            %                                 for p = o+1:N_avail-1
            %                                     if time_out_flag, break; end; idx_h = available_ues(p);
            %                                     for q = p+1:N_avail
            %                                         idx_i = available_ues(q);
            % 
            %                                         loop_counter = loop_counter + 1;
            %                                         if mod(loop_counter, 10000) == 0 && toc(t_search) > timeout_limit
            %                                             fprintf('[TIMEOUT] Dừng quét nhóm 9 sau %.1f s.\n', toc(t_search));
            %                                             time_out_flag = true; break;
            %                                         end
            % 
            %                                         avg_score = (distMat(idx_a,idx_b)+distMat(idx_a,idx_c)+distMat(idx_a,idx_d)+distMat(idx_a,idx_e)+distMat(idx_a,idx_f)+distMat(idx_a,idx_g)+distMat(idx_a,idx_h)+distMat(idx_a,idx_i) + ...
            %                                                     distMat(idx_b,idx_c)+distMat(idx_b,idx_d)+distMat(idx_b,idx_e)+distMat(idx_b,idx_f)+distMat(idx_b,idx_g)+distMat(idx_b,idx_h)+distMat(idx_b,idx_i) + ...
            %                                                     distMat(idx_c,idx_d)+distMat(idx_c,idx_e)+distMat(idx_c,idx_f)+distMat(idx_c,idx_g)+distMat(idx_c,idx_h)+distMat(idx_c,idx_i) + ...
            %                                                     distMat(idx_d,idx_e)+distMat(idx_d,idx_f)+distMat(idx_d,idx_g)+distMat(idx_d,idx_h)+distMat(idx_d,idx_i) + ...
            %                                                     distMat(idx_e,idx_f)+distMat(idx_e,idx_g)+distMat(idx_e,idx_h)+distMat(idx_e,idx_i) + ...
            %                                                     distMat(idx_f,idx_g)+distMat(idx_f,idx_h)+distMat(idx_f,idx_i) + ...
            %                                                     distMat(idx_g,idx_h)+distMat(idx_g,idx_i) + ...
            %                                                     distMat(idx_h,idx_i)) / 36;
            % 
            %                                         if avg_score > best_group_score
            %                                             best_group_score = avg_score; best_idx_in_avail = [i, j, k, l, m, n, o, p, q]; found_any = true;
            %                                         end
            %                                     end
            %                                 end
            %                             end
            %                         end
            %                     end
            %                 end
            %             end
            %         end
            %     end
            % 
            % % =========================================================
            % % CASE 10: 10 VÒNG LẶP LỒNG NHAU (45 CẶP KHOẢNG CÁCH)
            % % =========================================================
            % case 10
            %     for i = 1:N_avail-9
            %         if time_out_flag, break; end; idx_a = available_ues(i);
            %         for j = i+1:N_avail-8
            %             if time_out_flag, break; end; idx_b = available_ues(j);
            %             for k = j+1:N_avail-7
            %                 if time_out_flag, break; end; idx_c = available_ues(k);
            %                 for l = k+1:N_avail-6
            %                     if time_out_flag, break; end; idx_d = available_ues(l);
            %                     for m = l+1:N_avail-5
            %                         if time_out_flag, break; end; idx_e = available_ues(m);
            %                         for n = m+1:N_avail-4
            %                             if time_out_flag, break; end; idx_f = available_ues(n);
            %                             for o = n+1:N_avail-3
            %                                 if time_out_flag, break; end; idx_g = available_ues(o);
            %                                 for p = o+1:N_avail-2
            %                                     if time_out_flag, break; end; idx_h = available_ues(p);
            %                                     for q = p+1:N_avail-1
            %                                         if time_out_flag, break; end; idx_i = available_ues(q);
            %                                         for r = q+1:N_avail
            %                                             idx_j = available_ues(r);
            % 
            %                                             loop_counter = loop_counter + 1;
            %                                             if mod(loop_counter, 10000) == 0 && toc(t_search) > timeout_limit
            %                                                 fprintf('[TIMEOUT] Dừng quét nhóm 10 sau %.1f s.\n', toc(t_search));
            %                                                 time_out_flag = true; break;
            %                                             end
            % 
            %                                             avg_score = (distMat(idx_a,idx_b)+distMat(idx_a,idx_c)+distMat(idx_a,idx_d)+distMat(idx_a,idx_e)+distMat(idx_a,idx_f)+distMat(idx_a,idx_g)+distMat(idx_a,idx_h)+distMat(idx_a,idx_i)+distMat(idx_a,idx_j) + ...
            %                                                         distMat(idx_b,idx_c)+distMat(idx_b,idx_d)+distMat(idx_b,idx_e)+distMat(idx_b,idx_f)+distMat(idx_b,idx_g)+distMat(idx_b,idx_h)+distMat(idx_b,idx_i)+distMat(idx_b,idx_j) + ...
            %                                                         distMat(idx_c,idx_d)+distMat(idx_c,idx_e)+distMat(idx_c,idx_f)+distMat(idx_c,idx_g)+distMat(idx_c,idx_h)+distMat(idx_c,idx_i)+distMat(idx_c,idx_j) + ...
            %                                                         distMat(idx_d,idx_e)+distMat(idx_d,idx_f)+distMat(idx_d,idx_g)+distMat(idx_d,idx_h)+distMat(idx_d,idx_i)+distMat(idx_d,idx_j) + ...
            %                                                         distMat(idx_e,idx_f)+distMat(idx_e,idx_g)+distMat(idx_e,idx_h)+distMat(idx_e,idx_i)+distMat(idx_e,idx_j) + ...
            %                                                         distMat(idx_f,idx_g)+distMat(idx_f,idx_h)+distMat(idx_f,idx_i)+distMat(idx_f,idx_j) + ...
            %                                                         distMat(idx_g,idx_h)+distMat(idx_g,idx_i)+distMat(idx_g,idx_j) + ...
            %                                                         distMat(idx_h,idx_i)+distMat(idx_h,idx_j) + ...
            %                                                         distMat(idx_i,idx_j)) / 45;
            % 
            %                                             if avg_score > best_group_score
            %                                                 best_group_score = avg_score; best_idx_in_avail = [i, j, k, l, m, n, o, p, q, r]; found_any = true;
            %                                             end
            %                                         end
            %                                     end
            %                                 end
            %                             end
            %                         end
            %                     end
            %                 end
            %             end
            %         end
            %     end
            % 
            % % =========================================================
            % % CASE 11: 11 VÒNG LẶP LỒNG NHAU (55 CẶP KHOẢNG CÁCH)
            % % =========================================================
            % case 11
            %     for i = 1:N_avail-10
            %         if time_out_flag, break; end; idx_a = available_ues(i);
            %         for j = i+1:N_avail-9
            %             if time_out_flag, break; end; idx_b = available_ues(j);
            %             for k = j+1:N_avail-8
            %                 if time_out_flag, break; end; idx_c = available_ues(k);
            %                 for l = k+1:N_avail-7
            %                     if time_out_flag, break; end; idx_d = available_ues(l);
            %                     for m = l+1:N_avail-6
            %                         if time_out_flag, break; end; idx_e = available_ues(m);
            %                         for n = m+1:N_avail-5
            %                             if time_out_flag, break; end; idx_f = available_ues(n);
            %                             for o = n+1:N_avail-4
            %                                 if time_out_flag, break; end; idx_g = available_ues(o);
            %                                 for p = o+1:N_avail-3
            %                                     if time_out_flag, break; end; idx_h = available_ues(p);
            %                                     for q = p+1:N_avail-2
            %                                         if time_out_flag, break; end; idx_i = available_ues(q);
            %                                         for r = q+1:N_avail-1
            %                                             if time_out_flag, break; end; idx_j = available_ues(r);
            %                                             for s = r+1:N_avail
            %                                                 idx_k = available_ues(s);
            % 
            %                                                 loop_counter = loop_counter + 1;
            %                                                 if mod(loop_counter, 10000) == 0 && toc(t_search) > timeout_limit
            %                                                     fprintf('[TIMEOUT] Dừng quét nhóm 11 sau %.1f s.\n', toc(t_search));
            %                                                     time_out_flag = true; break;
            %                                                 end
            % 
            %                                                 avg_score = (distMat(idx_a,idx_b)+distMat(idx_a,idx_c)+distMat(idx_a,idx_d)+distMat(idx_a,idx_e)+distMat(idx_a,idx_f)+distMat(idx_a,idx_g)+distMat(idx_a,idx_h)+distMat(idx_a,idx_i)+distMat(idx_a,idx_j)+distMat(idx_a,idx_k) + ...
            %                                                             distMat(idx_b,idx_c)+distMat(idx_b,idx_d)+distMat(idx_b,idx_e)+distMat(idx_b,idx_f)+distMat(idx_b,idx_g)+distMat(idx_b,idx_h)+distMat(idx_b,idx_i)+distMat(idx_b,idx_j)+distMat(idx_b,idx_k) + ...
            %                                                             distMat(idx_c,idx_d)+distMat(idx_c,idx_e)+distMat(idx_c,idx_f)+distMat(idx_c,idx_g)+distMat(idx_c,idx_h)+distMat(idx_c,idx_i)+distMat(idx_c,idx_j)+distMat(idx_c,idx_k) + ...
            %                                                             distMat(idx_d,idx_e)+distMat(idx_d,idx_f)+distMat(idx_d,idx_g)+distMat(idx_d,idx_h)+distMat(idx_d,idx_i)+distMat(idx_d,idx_j)+distMat(idx_d,idx_k) + ...
            %                                                             distMat(idx_e,idx_f)+distMat(idx_e,idx_g)+distMat(idx_e,idx_h)+distMat(idx_e,idx_i)+distMat(idx_e,idx_j)+distMat(idx_e,idx_k) + ...
            %                                                             distMat(idx_f,idx_g)+distMat(idx_f,idx_h)+distMat(idx_f,idx_i)+distMat(idx_f,idx_j)+distMat(idx_f,idx_k) + ...
            %                                                             distMat(idx_g,idx_h)+distMat(idx_g,idx_i)+distMat(idx_g,idx_j)+distMat(idx_g,idx_k) + ...
            %                                                             distMat(idx_h,idx_i)+distMat(idx_h,idx_j)+distMat(idx_h,idx_k) + ...
            %                                                             distMat(idx_i,idx_j)+distMat(idx_i,idx_k) + ...
            %                                                             distMat(idx_j,idx_k)) / 55;
            % 
            %                                                 if avg_score > best_group_score
            %                                                     best_group_score = avg_score; best_idx_in_avail = [i, j, k, l, m, n, o, p, q, r, s]; found_any = true;
            %                                                 end
            %                                             end
            %                                         end
            %                                     end
            %                                 end
            %                             end
            %                         end
            %                     end
            %                 end
            %             end
            %         end
            %     end
            % 
            % % =========================================================
            % % CASE 12: 12 VÒNG LẶP LỒNG NHAU (66 CẶP KHOẢNG CÁCH)
            % % =========================================================
            % case 12
            %     for i = 1:N_avail-11
            %         if time_out_flag, break; end; idx_a = available_ues(i);
            %         for j = i+1:N_avail-10
            %             if time_out_flag, break; end; idx_b = available_ues(j);
            %             for k = j+1:N_avail-9
            %                 if time_out_flag, break; end; idx_c = available_ues(k);
            %                 for l = k+1:N_avail-8
            %                     if time_out_flag, break; end; idx_d = available_ues(l);
            %                     for m = l+1:N_avail-7
            %                         if time_out_flag, break; end; idx_e = available_ues(m);
            %                         for n = m+1:N_avail-6
            %                             if time_out_flag, break; end; idx_f = available_ues(n);
            %                             for o = n+1:N_avail-5
            %                                 if time_out_flag, break; end; idx_g = available_ues(o);
            %                                 for p = o+1:N_avail-4
            %                                     if time_out_flag, break; end; idx_h = available_ues(p);
            %                                     for q = p+1:N_avail-3
            %                                         if time_out_flag, break; end; idx_i = available_ues(q);
            %                                         for r = q+1:N_avail-2
            %                                             if time_out_flag, break; end; idx_j = available_ues(r);
            %                                             for s = r+1:N_avail-1
            %                                                 if time_out_flag, break; end; idx_k = available_ues(s);
            %                                                 for t = s+1:N_avail
            %                                                     idx_l = available_ues(t);
            % 
            %                                                     loop_counter = loop_counter + 1;
            %                                                     if mod(loop_counter, 10000) == 0 && toc(t_search) > timeout_limit
            %                                                         fprintf('[TIMEOUT] Dừng quét nhóm 12 sau %.1f s.\n', toc(t_search));
            %                                                         time_out_flag = true; break;
            %                                                     end
            % 
            %                                                     avg_score = (distMat(idx_a,idx_b)+distMat(idx_a,idx_c)+distMat(idx_a,idx_d)+distMat(idx_a,idx_e)+distMat(idx_a,idx_f)+distMat(idx_a,idx_g)+distMat(idx_a,idx_h)+distMat(idx_a,idx_i)+distMat(idx_a,idx_j)+distMat(idx_a,idx_k)+distMat(idx_a,idx_l) + ...
            %                                                                 distMat(idx_b,idx_c)+distMat(idx_b,idx_d)+distMat(idx_b,idx_e)+distMat(idx_b,idx_f)+distMat(idx_b,idx_g)+distMat(idx_b,idx_h)+distMat(idx_b,idx_i)+distMat(idx_b,idx_j)+distMat(idx_b,idx_k)+distMat(idx_b,idx_l) + ...
            %                                                                 distMat(idx_c,idx_d)+distMat(idx_c,idx_e)+distMat(idx_c,idx_f)+distMat(idx_c,idx_g)+distMat(idx_c,idx_h)+distMat(idx_c,idx_i)+distMat(idx_c,idx_j)+distMat(idx_c,idx_k)+distMat(idx_c,idx_l) + ...
            %                                                                 distMat(idx_d,idx_e)+distMat(idx_d,idx_f)+distMat(idx_d,idx_g)+distMat(idx_d,idx_h)+distMat(idx_d,idx_i)+distMat(idx_d,idx_j)+distMat(idx_d,idx_k)+distMat(idx_d,idx_l) + ...
            %                                                                 distMat(idx_e,idx_f)+distMat(idx_e,idx_g)+distMat(idx_e,idx_h)+distMat(idx_e,idx_i)+distMat(idx_e,idx_j)+distMat(idx_e,idx_k)+distMat(idx_e,idx_l) + ...
            %                                                                 distMat(idx_f,idx_g)+distMat(idx_f,idx_h)+distMat(idx_f,idx_i)+distMat(idx_f,idx_j)+distMat(idx_f,idx_k)+distMat(idx_f,idx_l) + ...
            %                                                                 distMat(idx_g,idx_h)+distMat(idx_g,idx_i)+distMat(idx_g,idx_j)+distMat(idx_g,idx_k)+distMat(idx_g,idx_l) + ...
            %                                                                 distMat(idx_h,idx_i)+distMat(idx_h,idx_j)+distMat(idx_h,idx_k)+distMat(idx_h,idx_l) + ...
            %                                                                 distMat(idx_i,idx_j)+distMat(idx_i,idx_k)+distMat(idx_i,idx_l) + ...
            %                                                                 distMat(idx_j,idx_k)+distMat(idx_j,idx_l) + ...
            %                                                                 distMat(idx_k,idx_l)) / 66;
            % 
            %                                                     if avg_score > best_group_score
            %                                                         best_group_score = avg_score; best_idx_in_avail = [i, j, k, l, m, n, o, p, q, r, s, t]; found_any = true;
            %                                                     end
            %                                                 end
            %                                             end
            %                                         end
            %                                     end
            %                                 end
            %                             end
            %                         end
            %                     end
            %                 end
            %             end
            %         end
            %     end
        end
        % =========================================================

        if ~found_any, break; end

        actual_ids = available_ues(best_idx_in_avail);
        bestGroups_Greedy{end+1} = actual_ids;
        total_loop_score = total_loop_score + best_group_score;
        completed_groups = completed_groups + 1;
        available_ues(best_idx_in_avail) = [];
    end

    time_greedy      = toc;
    avg_score_greedy = total_loop_score / max(1, completed_groups);

    fprintf('\n========== BẢNG SO SÁNH (%d UEs) ==========\n', groupSize);
    fprintf('Tiêu chí                | SOS                  | Greedy\n');
    fprintf('------------------------------------------------------------\n');
    fprintf('Thời gian thực thi (s)  | %-20.4f | %.4f\n', timeSOS,       time_greedy);
    fprintf('Điểm Orthogonality TB   | %-20.4f | %.4f\n', bestScore_SOS, avg_score_greedy);
    fprintf('Số nhóm hoàn thành      | %-20d | %d\n',     floor(Actual_Pool_Size/groupSize), completed_groups);
    fprintf('============================================================\n');

    if ~isempty(bestGroups_Greedy)
        fprintf('--- Mô phỏng PHY Layer cho nhóm tốt nhất (%d UEs) ---\n', groupSize);
        BER_results = simulateMuMimoGroup(W_pool, bestGroups_Greedy, phyConfig, groupSize);
    end
end