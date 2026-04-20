% =========================================================================
% compareExecutionTime.m
%
% Benchmarks SOS vs PSO for MU-MIMO user scheduling on a 32T32R antenna
% system with 20,000 UEs. Compares execution time, average chordal distance
% score, and number of valid orthogonal pairs produced by each algorithm.
% =========================================================================
clear; clc; close all;
setupPath();


% ----------------------------------------------------------------------------
% The configuration parameters for the test
% ----------------------------------------------------------------------------
nLayers            = 4;
numberOfUeToGroup  = 2;
numberOfUE         = 20000;

config.CodeBookConfig.N1     = 4;
config.CodeBookConfig.N2     = 4;
config.CodeBookConfig.cbMode = 1;
config.FileName              = "Layer4_Port32_N1_4_N2-4_c1.txt";

baseConfig = struct( ...
    'desc', 'Case 1: Default', ...
    'NLAYERS', nLayers, ...
    'MCS', 27, ...
    'SUBCARRIER_SPACING', 30, ...
    'NSIZE_GRID', 273, ...
    'CYCLIC_PREFIX', "normal", ...
    'NSLOT', 0, ...
    'NFRAME', 0, ...
    'NCELL_ID', 20, ...
    'DMRS_CONFIGURATION_TYPE', 1, ...
    'DMRS_TYPEA_POSITION', 2, ...
    'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
    'DMRS_LENGTH', 2, ...
    'DMRS_ADDITIONAL_POSITION', 1, ...
    'PDSCH_MAPPING_TYPE', 'A', ...
    'PDSCH_RNTI', 20000, ...
    'PDSCH_PRBSET', 0:272, ...
    'PDSCH_START_SYMBOL', 0, ...
    'FILE_NAME', '2UE_Combine_PDSCH_Waveform_4P2V' ...
);

poolConfig = struct( ...
    'numClusters',    min(totalPMI, 500), ...
    'targetPoolSize', 2000, ...
    'kmeansMaxIter',  100 ...
);

% ----------------------------------------------------------------------------
% Papre Data 
% Load PMI codebook from file and randomly sample numberOfUE precoding
% matrices (with replacement) to simulate a realistic UE population.
% Output W_all: [nPort x nLayers x numberOfUE]
% ----------------------------------------------------------------------------
[W_all, UE_Reported_Indices, totalPMI] = ...
    prepareData(config, nLayers, numberOfUE);

% =========================================================================
% Pre-Processing: Build representative UE pool via K-Means clustering
% =========================================================================
disp('--- Running K-Means to build Representative Pool ---');
[W_pool, pool_indices, pool_pmi] = ...
    buildRepresentativePool(W_all, UE_Reported_Indices, poolConfig);


% =========================================================================
% Mesurement Time and Count Pair Number
% =========================================================================   
maxIter   = 50;
threshold = 0.90;

fprintf('\n--- BENCHMARK: SOS vs PSO (MaxIter = %d, Threshold = %.2f) ---\n', ...
    maxIter, threshold);

% Run SOS and measure wall-clock time
fprintf('\nRunning SOS...\n');
tic;
[bestGroupsSOS, scoreSOS] = ...
    sosMUMIMOScheduling(W_pool, numberOfUeToGroup, maxIter);
timeSOS = toc;
validPairsSOS = countValidPairs(bestGroupsSOS, W_pool, threshold);

% Run PSO and measure wall-clock time
fprintf('Running PSO...\n');
tic;
[bestGroupsPSO, scorePSO] = ...
    psoMUMIMOScheduling(W_pool, numberOfUeToGroup, maxIter);
timePSO = toc;
validPairsPSO = countValidPairs(bestGroupsPSO, W_pool, threshold);

% Print benchmark summary table
fprintf('\n================ BENCHMARK SUMMARY =================\n');
fprintf('%-25s | %-15s | %-15s\n', 'Metric', 'SOS', 'PSO');
fprintf('---------------------------------------------------\n');
fprintf('%-25s | %-15.4f | %-15.4f\n', 'Execution Time (s)', timeSOS, timePSO);
fprintf('%-25s | %-15.4f | %-15.4f\n', 'Average Score', scoreSOS, scorePSO);
fprintf('%-25s | %-15d | %-15d\n', ...
    sprintf('Pairs >= %.2f', threshold), validPairsSOS, validPairsPSO);
fprintf('===================================================\n');

% =========================================================================
% Visualization: SOS vs PSO performance comparison
% =========================================================================
figure('Name', 'SOS vs PSO Performance Comparison', 'Color', 'w', 'Position', [100, 100, 1000, 450]);

% Panel 1: Execution time (lower is better)
subplot(1, 2, 1);
bar_data_time = [timeSOS, timePSO];
b1 = bar(bar_data_time, 0.6, 'FaceColor', 'flat');
b1.CData(1,:) = [0.2 0.6 0.8];
b1.CData(2,:) = [0.8 0.2 0.2];
set(gca, 'XTickLabel', {'SOS', 'PSO'}, 'FontSize', 11);
ylabel('Execution Time (s)');
title('Runtime Comparison');
grid on;
text(1:2, bar_data_time, num2str(bar_data_time', '%.3f s'), ...
    'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');

% Panel 2: Valid orthogonal pairs at threshold (higher is better)
subplot(1, 2, 2);
bar_data_perf = [validPairsSOS, validPairsPSO];
b2 = bar(bar_data_perf, 0.6, 'FaceColor', 'flat');
b2.CData(1,:) = [0.2 0.7 0.3];
b2.CData(2,:) = [0.9 0.6 0];
set(gca, 'XTickLabel', {'SOS', 'PSO'}, 'FontSize', 11);
ylabel(['Valid Pairs (Chordal Dist >= ', num2str(threshold), ')']);
title(['Pairing Quality (Threshold = ', num2str(threshold), ')']);
grid on;
text(1:2, bar_data_perf, num2str(bar_data_perf'), ...
    'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');

sgtitle(['MU-MIMO Scheduling Benchmark: SOS vs PSO (Pool Size: ', num2str(poolConfig.targetPoolSize), ')']);

fprintf('\n[Done] Benchmark figure generated.\n');

% =========================================================================
% HELPER FUNCTION
% =========================================================================
function validPairs = countValidPairs(groups, W_pool, threshold)
    validPairs = 0;

    for i = 1:length(groups)
        ue_idx = groups{i};

        dist = chordalDistance( ...
            W_pool(:,:,ue_idx(1)), ...
            W_pool(:,:,ue_idx(2)) ...
        );

        if dist >= threshold
            validPairs = validPairs + 1;
        end
    end
end