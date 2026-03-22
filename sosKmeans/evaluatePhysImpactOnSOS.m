% =========================================================================
% SCRIPT: K-MEANS + SOS VS GREEDY MU-MIMO SCHEDULING FOR 60,000 UEs
% Antenna: 32T32R | Evaluate PHY Config impact on SOS algorithm
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
phyConfig.SNR_dB            = 30;
phyConfig.PRBSet            = 0:272;
phyConfig.SubcarrierSpacing = 30;
phyConfig.NSizeGrid         = 273;

% =========================================================================
% 5. PHY PARAMETER SWEEP FOR SOS ALGORITHM
% Evaluate the impact of MCS and SNR across different group sizes
% =========================================================================

% Define sweep parameter ranges
sweep_MCS_list = [4, 12, 20];   % QPSK, 16QAM, 64QAM
sweep_SNR_list = 20:2:30;       % SNR range: 20 dB to 30 dB
sweep_GS_list  = 2:12;          % Group size range: 2 to 12
maxIter_SOS    = 100;

% Run PHY sweep evaluation (returns struct with full 3D BER results)
phy_sweep_results = evaluatePhysImpact( ...
    W_pool,        ...
    phyConfig,     ...
    maxIter_SOS,   ...
    sweep_GS_list, ...
    sweep_MCS_list, ...
    sweep_SNR_list  ...
);

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
    % Port reuse is allowed when total streams exceed 12
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
            fprintf('[Note] %d ports requested. DMRS Port Reuse will be applied (5G NR supports max 12 orthogonal ports).\n', totalPorts);
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

        % --- APPLY DMRS PORT REUSE ---
        physicalPorts = mod(logicalPorts, maxPortIndex + 1);
        pd.DMRS.DMRSPortSet = physicalPorts;
        
        % Alternate NSCID to reduce inter-user interference under port reuse
        reuseFactor = floor(logicalPortStart / (maxPortIndex + 1));
        pd.DMRS.NSCID = mod(reuseFactor, 2);
        
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

    % MMSE Precoding (getMMSEPrecoder takes 2 arguments as updated)
    H_composite = cell2mat(cellfun(@(w) w', UE_W_list(:), 'UniformOutput', false));
    W_total_T   = getMMSEPrecoder(H_composite, SNR_dB);

    W_list = cell(numUE, 1);
    for u = 1:numUE
        rowStart  = (u-1)*nLayers + 1;
        W_list{u} = W_total_T(rowStart : u*nLayers, :);
    end

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

function results = evaluatePhysImpact(W_pool, phyConfig, maxIter, GS_list, MCS_list, SNR_list)
    fprintf('\n\n');
    disp('############################################################');
    disp('    STARTING PHY LAYER SWEEP EVALUATION FOR SOS             ');
    disp('############################################################');

    num_gs  = length(GS_list);
    num_mcs = length(MCS_list);
    num_snr = length(SNR_list);

    % Initialize 3D result array: (GroupSize x MCS x SNR)
    all_sweep_results = zeros(num_gs, num_mcs, num_snr);

    for gs_idx = 1:num_gs
        sweep_gs = GS_list(gs_idx);
        fprintf('\n--- Evaluating Group Size = %d ---\n', sweep_gs);

        % Run SOS scheduling for current group size
        [bestGroups_Sweep, ~] = sosMUMIMOScheduling(W_pool, sweep_gs, maxIter);

        if isempty(bestGroups_Sweep)
            fprintf('  [Warning] No SOS group found for GS=%d, skipping.\n', sweep_gs);
            all_sweep_results(gs_idx, :, :) = NaN;
            continue;
        end

        % Use the best group (first entry) for BER evaluation
        test_group = bestGroups_Sweep(1);

        for m_idx = 1:num_mcs
            current_mcs = MCS_list(m_idx);
            fprintf('  -> Sweeping MCS %d... ', current_mcs);

            for s_idx = 1:num_snr
                current_snr = SNR_list(s_idx);

                % Override PHY config for this sweep point
                tmpConfig        = phyConfig;
                tmpConfig.MCS    = current_mcs;
                tmpConfig.SNR_dB = current_snr;

                % Run PHY simulation and store average BER
                BER_arr = simulateMuMimoGroup(W_pool, test_group, tmpConfig, sweep_gs);
                all_sweep_results(gs_idx, m_idx, s_idx) = mean(BER_arr);
            end
            fprintf('Done.\n');
        end
    end

    % Pack results into output struct
    results = struct();
    results.BER      = all_sweep_results;
    results.GS_list  = GS_list;
    results.MCS_list = MCS_list;
    results.SNR_list = SNR_list;

    % Plot sweep results
    plotPhysSweepResults(results);

    fprintf('\nPHY Layer sweep evaluation complete!\n');
end

% =========================================================================
% LOCAL HELPER FUNCTION FOR PLOTTING
% =========================================================================
function plotPhysSweepResults(res)
    GS_list  = res.GS_list;
    MCS_list = res.MCS_list;
    SNR_list = res.SNR_list;
    ber_data = res.BER;

    num_gs    = length(GS_list);
    my_colors = lines(num_gs);
    markers   = {'o', '+', '*', '.', 'x', 's', 'd', '^', 'v', '>', '<', 'p', 'h'}; % Marker pool

    % --- Plot 1: BER vs SNR (one subplot per MCS value) ---
    figure('Name', 'BER vs SNR (All Group Sizes)', 'NumberTitle', 'off', 'Position', [100, 100, 1200, 400]);

    for m_idx = 1:length(MCS_list)
        subplot(1, length(MCS_list), m_idx);

        for gs_idx = 1:num_gs
            ber_vs_snr = squeeze(ber_data(gs_idx, m_idx, :));

            semilogy(SNR_list, ber_vs_snr + eps, 'Color', my_colors(gs_idx,:), ...
                'Marker', markers{mod(gs_idx-1, length(markers))+1}, ...
                'LineWidth', 1.5, 'MarkerSize', 6);
            hold on;
        end

        grid on;
        xlabel('SNR (dB)');
        ylabel('BER (Log Scale)');
        title(sprintf('MCS = %d', MCS_list(m_idx)));
        ylim([1e-6 1]);

        % Show legend only on the last subplot
        if m_idx == length(MCS_list)
            leg_str = arrayfun(@(x) sprintf('GS = %d', x), GS_list, 'UniformOutput', false);
            legend(leg_str, 'Location', 'bestoutside');
        end
    end
    sgtitle('Effect of SNR on BER Across All Group Sizes');

    % --- Plot 2: BER vs MCS (evaluated at the highest SNR point) ---
    snr_ref_idx = length(SNR_list);

    figure('Name', 'BER vs MCS (All Group Sizes)', 'NumberTitle', 'off');

    for gs_idx = 1:num_gs
        ber_vs_mcs = squeeze(ber_data(gs_idx, :, snr_ref_idx));

        semilogy(MCS_list, ber_vs_mcs + eps, 'Color', my_colors(gs_idx,:), ...
            'Marker', markers{mod(gs_idx-1, length(markers))+1}, ...
            'LineWidth', 1.5, 'MarkerSize', 7);
        hold on;
    end

    grid on;
    xlabel('MCS Index');
    ylabel('BER (Log Scale)');
    title(sprintf('Effect of MCS on BER at SNR = %d dB', SNR_list(snr_ref_idx)));

    xticks(MCS_list);
    % Auto-generate x-axis labels from actual MCS values
    xticklabels(arrayfun(@num2str, MCS_list, 'UniformOutput', false));

    leg_str = arrayfun(@(x) sprintf('GS = %d', x), GS_list, 'UniformOutput', false);
    legend(leg_str, 'Location', 'bestoutside');
    ylim([1e-6 1]);
end