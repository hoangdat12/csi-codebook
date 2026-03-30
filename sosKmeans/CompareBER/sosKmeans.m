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
prepareDataConfig.Num_UEs           = 10000;
prepareDataConfig.N1                = 4;   % 8x4 = 32 Tx ports
prepareDataConfig.N2                = 2;
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
poolConfig.targetPoolSize = 2000;
poolConfig.kmeansMaxIter  = 100;

disp('--- Running K-Means to build Representative Pool ---');
[W_pool, pool_indices] = buildRepresentativePool(W_all, poolConfig);

% =========================================================================
% 4. PHY Layer Configuration — 32T32R
% =========================================================================
phyConfig = struct();
phyConfig.MCS               = 27;
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
    end

    
end
