% =========================================================================
% SCRIPT: PURE SOS STANDALONE — 60,000 UEs, 32T32R
% Measure runtime only, no comparison needed
% =========================================================================
clear; clc; close all;
setupPath();

prepareDataConfig = struct();
prepareDataConfig.Num_UEs           = 60000;
prepareDataConfig.N1                = 8;
prepareDataConfig.N2                = 4;
prepareDataConfig.O1                = 4;
prepareDataConfig.O2                = 4;
prepareDataConfig.L                 = 2;
prepareDataConfig.NumLayers         = 1;
prepareDataConfig.subbandAmplitude  = true;
prepareDataConfig.PhaseAlphabetSize = 8;

groupSizes = 2:12;
maxIter    = 100;

fprintf('[1/2] Generating W for %d UEs...\n', prepareDataConfig.Num_UEs);
t_data = tic;
[W_all, ~] = prepareData(prepareDataConfig);
fprintf('      Done. %.2f s\n\n', toc(t_data));

fprintf('[2/2] Running Pure SOS...\n');
fprintf('%-12s %-12s\n', 'GroupSize', 'Runtime(s)');
fprintf('%s\n', repmat('-', 1, 26));

% INITIALIZE ARRAY TO STORE RUNTIMES
runtime_results = zeros(length(groupSizes), 1);

t_total = tic;
for gi = 1:length(groupSizes)
    K  = groupSizes(gi);
    
    t_g = tic;
    sosMUMIMOScheduling_standalone(W_all, K, maxIter);
    rt = toc(t_g);
    
    % STORE RUNTIME INTO ARRAY
    runtime_results(gi) = rt;
    
    fprintf('%-12d %-12.2f\n', K, rt);
end

fprintf('%s\n', repmat('-', 1, 26));
fprintf('Total runtime: %.2f s\n', toc(t_total));

% --- PLOT RUNTIME CHART ---
figure;
plot(groupSizes, runtime_results, '-ob', 'LineWidth', 1.5, 'MarkerSize', 6, 'MarkerFaceColor', 'b');
grid on;
xlabel('Group Size (K)', 'FontSize', 11);
ylabel('Runtime (s)', 'FontSize', 11);
title('Pure SOS Runtime Evaluation by Group Size', 'FontSize', 12, 'FontWeight', 'bold');

% =========================================================================
% HELPER FUNCTION
% =========================================================================

function [W_all, UE_Reported_Indices] = prepareData(config)

    % --- Read configuration (with default values) ---
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

    % --- Compute W_all ---
    Num_Antennas = 2 * N1 * N2;
    W_all = zeros(Num_Antennas, NumLayers, Num_UEs);

    fprintf('Computing precoder matrix W_all...\n');
    for u = 1:Num_UEs
        indices_ue = UE_Reported_Indices{u};
        W_all(:, :, u) = generateTypeIIPrecoder(cfg, indices_ue.i1, indices_ue.i2);
    end
    fprintf('W_all completed: [%d x %d x %d]\n\n', size(W_all));

end

function val = getField(s, fname, default)
    if isfield(s, fname)
        val = s.(fname);
    else
        val = default;
    end
end

function [bestGroups, bestScore] = sosMUMIMOScheduling_standalone(W_all, groupSize, maxIter)

    NUE       = size(W_all, 3);
    numGroups = floor(NUE / groupSize);

    % =====================================================================
    %  -> Strategy: Evaluate only a small subset in each iteration
    %  -> Population does not store the full 60k UE permutations, but stores GROUP ASSIGNMENTS
    % =====================================================================

    % Sampling parameters — adjust to balance speed vs. quality
    sampleSize = 2000;   % Number of UEs sampled per fitness evaluation round
    popSize    = 20;     % Reduced compared to the K-Means version (smaller pool)
    max_no_improve = 15;

    fprintf('      [SOS-Standalone] NUE=%d | groupSize=%d | numGroups=%d\n', ...
        NUE, groupSize, numGroups);
    fprintf('      [SOS-Standalone] Strategy: Sampling %d UEs/round\n', sampleSize);

    % =====================================================================
    %  Each individual is a permutation vector [1..NUE], read sequentially into groups
    % =====================================================================
    population = zeros(popSize, NUE);
    for p = 1:popSize
        population(p, :) = randperm(NUE);
    end

    % =====================================================================
    %  Each time fitness is called, only sampleSize random UEs are used for calculation
    %  -> Reduces complexity from O(NUE^2) to O(sampleSize^2)
    % =====================================================================
    fitnessFunc = @(perm) computeFitness_sampled(perm, W_all, groupSize, sampleSize);

    % Calculate initial fitness
    fprintf('      [SOS-Standalone] Calculating initial fitness...\n');
    fitness = zeros(popSize, 1);
    parfor p = 1:popSize   % Use parfor if Parallel Computing Toolbox is available, change to for otherwise
        fitness(p) = fitnessFunc(population(p, :));
    end

    [bestScore, bestIdx] = max(fitness);
    bestPerm = population(bestIdx, :);

    % =====================================================================
    % =====================================================================
    no_improve_counter = 0;

    fprintf('      [SOS-Standalone] Starting %d evolutionary iterations...\n', maxIter);

    for iter = 1:maxIter

        % -----------------------------------------------------------------
        % MUTUALISM PHASE
        % -----------------------------------------------------------------
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

        % -----------------------------------------------------------------
        % COMMENSALISM PHASE
        % -----------------------------------------------------------------
        for i = 1:popSize
            j = randi(popSize);
            while j == i, j = randi(popSize); end

            newOrg = commensalismSwap(population(i,:), population(j,:));
            fNew   = fitnessFunc(newOrg);
            if fNew > fitness(i)
                population(i,:) = newOrg;
                fitness(i) = fNew;
            end
        end

        % -----------------------------------------------------------------
        % PARASITISM PHASE
        % -----------------------------------------------------------------
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

        % -----------------------------------------------------------------
        % Update best + early stopping
        % -----------------------------------------------------------------
        [curBest, curIdx] = max(fitness);
        if curBest > bestScore
            bestScore = curBest;
            bestPerm  = population(curIdx, :);
            no_improve_counter = 0;
        else
            no_improve_counter = no_improve_counter + 1;
        end

        if mod(iter, 10) == 0
            fprintf('      [SOS] Iter %d/%d | Best=%.4f | NoImprove=%d\n', ...
                iter, maxIter, bestScore, no_improve_counter);
        end

        if no_improve_counter >= max_no_improve
            fprintf('      [SOS] Early convergence at iter %d (Score=%.4f)\n', ...
                iter, bestScore);
            break;
        end
    end

    bestGroups = cell(numGroups, 1);
    for g = 1:numGroups
        idx = (g-1)*groupSize + 1 : g*groupSize;
        bestGroups{g} = bestPerm(idx);
    end

    fprintf('      [SOS-Standalone] Completed. Score=%.4f | Groups=%d\n', ...
        bestScore, numGroups);
end

function score = computeFitness_sampled(perm, W_all, groupSize, sampleSize)
% Instead of using a precomputed distMat (infeasible for 60k UEs),
% only evaluate fitness on a random subset of groups

    NUE       = length(perm);
    numGroups = floor(NUE / groupSize);

    % Randomly select a number of groups to evaluate (do not evaluate all)
    numEvalGroups = min(numGroups, floor(sampleSize / groupSize));
    evalGroupIdx  = randperm(numGroups, numEvalGroups);

    totalDist          = 0;
    numPairsPerGroup   = groupSize * (groupSize - 1) / 2;

    for gi = 1:numEvalGroups
        g      = evalGroupIdx(gi);
        idx    = (g-1)*groupSize + 1 : g*groupSize;
        ueIdx  = perm(idx);

        groupDist = 0;
        for a = 1:groupSize-1
            for b = a+1:groupSize
                % Calculate chordal distance directly (no caching)
                groupDist = groupDist + chordalDistance( ...
                    W_all(:,:,ueIdx(a)), W_all(:,:,ueIdx(b)));
            end
        end

        totalDist = totalDist + groupDist / numPairsPerGroup;
    end

    score = totalDist / numEvalGroups;
end

function newPerm = mutualismSwap(permA, permB)
    n = length(permA);
    pts = sort(randperm(n, 2));
    segment = permB(pts(1):pts(2));

    % TỐI ƯU: Dùng mảng logic (boolean) thay vì ismember
    toRemove = false(1, n);
    toRemove(segment) = true; 
    
    % Trích xuất cực nhanh các phần tử còn lại
    remaining = permA(~toRemove(permA)); 

    maxInsert = length(remaining) + 1;
    insertPos = randi(maxInsert);

    newPerm = [remaining(1:insertPos-1), segment, remaining(insertPos:end)];
end

function newPerm = commensalismSwap(permA, ~)
    newPerm      = permA;
    pts          = randperm(length(permA), 2);
    temp         = newPerm(pts(1));
    newPerm(pts(1)) = newPerm(pts(2));
    newPerm(pts(2)) = temp;
end

function parasite = parasitePerturb(perm)
    parasite       = perm;
    n              = length(perm);
    pts            = sort(randperm(n, 2));
    parasite(pts(1):pts(2)) = parasite(pts(1) + randperm(pts(2)-pts(1)+1) - 1);
end