% =========================================================================
% BENCHMARK: sosMUMIMOSchedulingOld vs sosMUMIMOSchedulingOptimize
% Pipeline: 60,000 UEs → K-Means pool → SOS scheduling
% Metrics : Runtime (s), Best fitness score, Score std across runs
% =========================================================================
clear; clc; close all;
setupPath();

% =========================================================================
% 1. Configuration — 32T32R (same as main script)
% =========================================================================
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

poolConfig = struct();
poolConfig.numClusters    = 100;
poolConfig.targetPoolSize = 500;
poolConfig.kmeansMaxIter  = 100;

% =========================================================================
% 2. Benchmark parameters
% =========================================================================
GROUP_SIZES  = [2, 4, 6, 8, 10, 12];   % sweep group sizes
NUM_RUNS     = 5;                        % independent runs per config
MAX_ITER     = 100;                      % SOS iterations

% =========================================================================
% 3. Prepare data (done ONCE — both versions use same W_pool)
% =========================================================================
disp('=== [SETUP] Generating data for 60,000 UEs ===');
[W_all, ~] = prepareData(prepareDataConfig);

disp('=== [SETUP] Building K-Means representative pool ===');
[W_pool, ~] = buildRepresentativePool(W_all, poolConfig);

NUE_pool = size(W_pool, 3);
fprintf('Pool size: %d UEs\n\n', NUE_pool);

% =========================================================================
% 4. Result storage
% =========================================================================
% Each cell: [NUM_RUNS x 1] vector — one value per run
results = struct();
for g = 1:length(GROUP_SIZES)
    gs = GROUP_SIZES(g);
    tag = sprintf('g%d', gs);
    results.(tag).old.time   = zeros(NUM_RUNS, 1);
    results.(tag).old.score  = zeros(NUM_RUNS, 1);
    results.(tag).new.time   = zeros(NUM_RUNS, 1);
    results.(tag).new.score  = zeros(NUM_RUNS, 1);
end

% =========================================================================
% 5. Benchmark loop
% =========================================================================
fprintf('=== BENCHMARK START: %d group sizes x %d runs ===\n\n', ...
        length(GROUP_SIZES), NUM_RUNS);

for g = 1:length(GROUP_SIZES)
    groupSize = GROUP_SIZES(g);
    tag       = sprintf('g%d', groupSize);

    fprintf('--- Group size = %d ---\n', groupSize);

    for r = 1:NUM_RUNS
        fprintf('  Run %d/%d ... ', r, NUM_RUNS);

        % ----- OLD version -----
        rng(r);  % fix seed for fair comparison
        t0 = tic;
        [~, scoreOld] = sosMUMIMOSchedulingOld(W_pool, groupSize, MAX_ITER);
        results.(tag).old.time(r)  = toc(t0);
        results.(tag).old.score(r) = scoreOld;

        % ----- NEW version -----
        rng(r);  % same seed → same initial population
        t0 = tic;
        [~, scoreNew] = sosMUMIMOSchedulingOptimize(W_pool, groupSize, MAX_ITER);
        results.(tag).new.time(r)  = toc(t0);
        results.(tag).new.score(r) = scoreNew;

        fprintf('Old: %.2fs / %.4f  |  New: %.2fs / %.4f\n', ...
                results.(tag).old.time(r), results.(tag).old.score(r), ...
                results.(tag).new.time(r), results.(tag).new.score(r));
    end
    fprintf('\n');
end

% =========================================================================
% 6. Aggregate statistics
% =========================================================================
fprintf('=== SUMMARY ===\n');
fprintf('%-10s | %-22s | %-22s | %-12s | %-12s\n', ...
        'GroupSize', 'Old time (mean±std)', 'New time (mean±std)', ...
        'Speedup', 'Score Δ');
fprintf('%s\n', repmat('-', 1, 90));

summaryTable = zeros(length(GROUP_SIZES), 6);
% cols: groupSize, oldTimeMean, newTimeMean, speedup, oldScoreMean, newScoreMean

for g = 1:length(GROUP_SIZES)
    groupSize = GROUP_SIZES(g);
    tag       = sprintf('g%d', groupSize);

    oldT  = results.(tag).old.time;
    newT  = results.(tag).new.time;
    oldS  = results.(tag).old.score;
    newS  = results.(tag).new.score;

    speedup   = mean(oldT) / mean(newT);
    scoreDiff = mean(newS) - mean(oldS);

    fprintf('%-10d | %8.2f ± %5.2f s      | %8.2f ± %5.2f s      | %8.2fx     | %+.4f\n', ...
            groupSize, ...
            mean(oldT), std(oldT), ...
            mean(newT), std(newT), ...
            speedup, scoreDiff);

    summaryTable(g,:) = [groupSize, mean(oldT), mean(newT), speedup, mean(oldS), mean(newS)];
end

% =========================================================================
% 7. Plots
% =========================================================================
figure('Name', 'SOS Benchmark', 'Position', [100 100 1200 500]);

% --- Plot 1: Runtime comparison ---
subplot(1, 3, 1);
bar(GROUP_SIZES, [summaryTable(:,2), summaryTable(:,3)], 'grouped');
legend('Old SOS', 'Optimized SOS', 'Location', 'northwest');
xlabel('Group size');
ylabel('Mean runtime (s)');
title('Runtime comparison');
grid on;

% --- Plot 2: Speedup ---
subplot(1, 3, 2);
bar(GROUP_SIZES, summaryTable(:,4), 'FaceColor', [0.2 0.6 0.4]);
xlabel('Group size');
ylabel('Speedup (×)');
title('Speedup factor (Old / New)');
yline(1, 'r--', 'Baseline');
grid on;

% --- Plot 3: Fitness score comparison ---
subplot(1, 3, 3);
bar(GROUP_SIZES, [summaryTable(:,5), summaryTable(:,6)], 'grouped');
legend('Old SOS', 'Optimized SOS', 'Location', 'northeast');
xlabel('Group size');
ylabel('Mean best fitness (chordal dist)');
title('Fitness score comparison');
grid on;

sgtitle('Benchmark: sosMUMIMOSchedulingOld vs sosMUMIMOSchedulingOptimize');

% =========================================================================
% 8. Save results to .mat for reporting
% =========================================================================
save('benchmark_results.mat', 'results', 'summaryTable', 'GROUP_SIZES');
fprintf('\n[Done] Results saved to benchmark_results.mat\n');




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

function val = getField(s, fname, default)
    if isfield(s, fname)
        val = s.(fname);
    else
        val = default;
    end
end
