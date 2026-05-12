% =========================================================================
% simulateRandomMUMIMOScheduling.m
%
% Top-level script for MU-MIMO user scheduling and BER evaluation.
% Loads a 3GPP Type I PMI codebook, builds a representative UE pool via
% K-Means clustering, runs SOS orthogonal group search, and evaluates
% time complexity and accuracy of the scheduling algorithms across
% group sizes (numberOfUeToGroup = 2, 3, 4, 5) at a fixed SNR of 20 dB.
% =========================================================================
clear; clc; close all;
setupPath();

% ----------------------------------------------------------------------------
% Configuration parameters
% ----------------------------------------------------------------------------
nLayers      = 4;
numberOfUE   = 1000;
FIXED_SNR_dB = 20;

config.CodeBookConfig.N1   = 4;
config.CodeBookConfig.N2   = 4;
config.CodeBookConfig.cbMode = 1;
config.FileName = "Layer4_Port32_N1_4_N2-4_c1.txt";

% ----------------------------------------------------------------------------
% Load PMI codebook and build synthetic UE population
% W_all: [nPort x nLayers x numberOfUE]
% ----------------------------------------------------------------------------
[W_all, UE_Reported_Indices, totalPMI] = prepareData(config, nLayers, numberOfUE);

% ----------------------------------------------------------------------------
% Base PDSCH/DMRS config (shared across all group-size tests)
% ----------------------------------------------------------------------------
baseConfig = struct( ...
    'desc',                      'MU-MIMO Group Size Sweep', ...
    'NLAYERS',                   nLayers, ...
    'MCS',                       27, ...
    'SUBCARRIER_SPACING',        30, ...
    'NSIZE_GRID',                273, ...
    'CYCLIC_PREFIX',             "normal", ...
    'NSLOT',                     0, ...
    'NFRAME',                    0, ...
    'NCELL_ID',                  20, ...
    'DMRS_CONFIGURATION_TYPE',   1, ...
    'DMRS_TYPEA_POSITION',       2, ...
    'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
    'DMRS_LENGTH',               2, ...
    'DMRS_ADDITIONAL_POSITION',  1, ...
    'PDSCH_MAPPING_TYPE',        'A', ...
    'PDSCH_RNTI',                20000, ...
    'PDSCH_PRBSET',              0:272, ...
    'PDSCH_START_SYMBOL',        0, ...
    'FILE_NAME',                 '2UE_Combine_PDSCH_Waveform_4P2V');

% =========================================================================
% Build representative UE pool via K-Means clustering (done once)
% =========================================================================
poolConfig.numClusters    = min(totalPMI, 100);
poolConfig.targetPoolSize = 200;
poolConfig.kmeansMaxIter  = 100;

disp('--- Running K-Means to build Representative Pool ---');
[W_pool, pool_indices, pool_pmi] = buildRepresentativePool(W_all, UE_Reported_Indices, poolConfig);

% =========================================================================
% Group-size sweep: numberOfUeToGroup = 2, 3, 4, 5
% =========================================================================
groupSizes  = [2, 3, 4, 5];
maxIter     = 50;
numMethods  = 2;
methodNames = {'SOS', 'BF Lookup'};

% Pre-allocate result matrices [numMethods x numGroupSizes]
allTimes    = zeros(numMethods, length(groupSizes));
allScores   = zeros(numMethods, length(groupSizes));
allAccuracy = nan(numMethods, length(groupSizes));   % NaN by default
bfTimeout   = false(1, length(groupSizes));          % timeout flag per group size

fprintf('\n========================================================\n');
fprintf('  GROUP SIZE SWEEP  (Fixed SNR = %d dB)\n', FIXED_SNR_dB);
fprintf('========================================================\n');

for gIdx = 1:length(groupSizes)
    K = groupSizes(gIdx);
    fprintf('\n--- Group Size K = %d ---\n', K);

    % Timeout: 180s only for K=5
    if K == 5
        maxTimeLimit = 180;
    else
        maxTimeLimit = Inf;
    end

    % ---- SOS ----
    t = tic;
    [g1, s1] = sosMUMIMOScheduling(W_pool, K, maxIter);
    allTimes(1, gIdx)  = toc(t);
    allScores(1, gIdx) = s1;

    % ---- Brute-Force + Lookup Table ----
    t = tic;
    [g2, s2, timedOut] = bruteForceMUMIMOSchedulingWithLookup(W_pool, K, maxTimeLimit);
    allTimes(2, gIdx)  = toc(t);
    allScores(2, gIdx) = s2;
    bfTimeout(gIdx)    = timedOut;

    % Accuracy: only valid when BF completed fully
    if ~timedOut
        allAccuracy(:, gIdx) = (allScores(:, gIdx) / allScores(2, gIdx)) * 100;
        fprintf('  %-20s | Time: %.4f s | Score: %.4f | Acc: %.2f%%\n', ...
            methodNames{1}, allTimes(1,gIdx), allScores(1,gIdx), allAccuracy(1,gIdx));
        fprintf('  %-20s | Time: %.4f s | Score: %.4f | Acc: 100%% (reference)\n', ...
            methodNames{2}, allTimes(2,gIdx), allScores(2,gIdx));
    else
        fprintf('  %-20s | Time: %.4f s | Score: %.4f | Acc: N/A (BF timeout)\n', ...
            methodNames{1}, allTimes(1,gIdx), allScores(1,gIdx));
        fprintf('  %-20s | Time: %.4f s | Score: %.4f | TIMEOUT\n', ...
            methodNames{2}, allTimes(2,gIdx), allScores(2,gIdx));
    end
end

% =========================================================================
% BER evaluation at SNR = 20 dB for the best SOS pair (K=2)
% =========================================================================
fprintf('\n--- BER at SNR = %d dB for best SOS pair (K=2) ---\n', FIXED_SNR_dB);
[gBER, ~] = sosMUMIMOScheduling(W_pool, 2, maxIter);
if ~isempty(gBER)
    bestGroup = gBER{1};
    W_UE1 = W_pool(:,:,bestGroup(1));
    W_UE2 = W_pool(:,:,bestGroup(2));
    [ber1, ber2] = muMIMO2UE(baseConfig, W_UE1, W_UE2, FIXED_SNR_dB);
    fprintf('  UE 1 BER = %.6f\n', ber1);
    fprintf('  UE 2 BER = %.6f\n', ber2);
end

% =========================================================================
% FIGURE 1 — Time Complexity vs Group Size
% =========================================================================
colors  = [0.12 0.47 0.71;   % blue  – SOS
           0.60 0.60 0.60];  % grey  – BF Lookup
markers = {'o-', 'd-'};

figure('Name', 'Figure 1: Time Complexity vs Group Size', ...
       'Color', 'w', 'Position', [100, 100, 700, 480]);

for m = 1:numMethods
    semilogy(groupSizes, allTimes(m,:), markers{m}, ...
        'LineWidth', 2, 'MarkerSize', 8, ...
        'Color', colors(m,:), 'MarkerFaceColor', colors(m,:));
    hold on;
end

% Mark BF timeout point with red circle
for gIdx = 1:length(groupSizes)
    if bfTimeout(gIdx)
        semilogy(groupSizes(gIdx), allTimes(2, gIdx), 'ro', ...
            'MarkerSize', 12, 'LineWidth', 2);
        text(groupSizes(gIdx), allTimes(2, gIdx) * 1.5, ...
             'Timeout', 'FontSize', 8, 'Color', 'r', ...
             'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    end
end

grid on;
set(gca, 'YMinorGrid', 'on', 'FontSize', 11, ...
    'XColor', 'k', 'YColor', 'k', ...
    'GridColor', [0.5 0.5 0.5], 'MinorGridColor', [0.7 0.7 0.7], 'Color', 'w');
xticks(groupSizes);
xticklabels({'K=2', 'K=3', 'K=4', 'K=5'});
xlabel('Number of UEs per Group (K)', 'FontWeight', 'bold', 'FontSize', 12, 'Color', 'k');
ylabel('Execution Time (s) — Log Scale', 'FontWeight', 'bold', 'FontSize', 12, 'Color', 'k');
title('Time Complexity vs MU-MIMO Group Size', 'FontSize', 13, 'FontWeight', 'bold', 'Color', 'k');
lg1 = legend(methodNames, 'Location', 'northwest', 'FontSize', 10);
set(lg1, 'TextColor', 'k', 'Color', 'w', 'EdgeColor', [0.5 0.5 0.5]);

% Annotate data points
for m = 1:numMethods
    for gIdx = 1:length(groupSizes)
        text(groupSizes(gIdx), allTimes(m, gIdx) * 1.15, ...
             sprintf('%.3fs', allTimes(m, gIdx)), ...
             'FontSize', 7.5, 'HorizontalAlignment', 'center', 'Color', colors(m,:));
    end
end

% =========================================================================
% FIGURE 2 — Accuracy (% vs Brute-Force) vs Group Size
% =========================================================================
figure('Name', 'Figure 2: Scheduling Accuracy vs Group Size', ...
       'Color', 'w', 'Position', [820, 100, 700, 480]);

% Only plot valid (non-NaN) accuracy points
validIdx = ~isnan(allAccuracy(1,:));

if any(validIdx)
    plot(groupSizes(validIdx), allAccuracy(1, validIdx), markers{1}, ...
        'LineWidth', 2, 'MarkerSize', 8, ...
        'Color', colors(1,:), 'MarkerFaceColor', colors(1,:));
    hold on;
end

% Brute-force 100% reference line
yline(100, '--k', 'Brute-Force (100%)', 'LabelHorizontalAlignment', 'left', ...
      'FontSize', 10, 'LineWidth', 1.5);
hold on;

% Annotate valid accuracy values
for gIdx = 1:length(groupSizes)
    if ~isnan(allAccuracy(1, gIdx))
        text(groupSizes(gIdx), allAccuracy(1, gIdx) + 0.2, ...
             sprintf('%.1f%%', allAccuracy(1, gIdx)), ...
             'FontSize', 8, 'HorizontalAlignment', 'center', 'Color', colors(1,:));
    end
end

% Annotate timeout points with red X marker and label
for gIdx = 1:length(groupSizes)
    if bfTimeout(gIdx)
        plot(groupSizes(gIdx), 98.5, 'rx', 'MarkerSize', 14, 'LineWidth', 2.5);
        text(groupSizes(gIdx), 98.0, ...
             sprintf('N/A\n(BF Timeout)'), ...
             'FontSize', 8, 'HorizontalAlignment', 'center', ...
             'Color', 'r', 'FontWeight', 'bold');
    end
end

grid on;
set(gca, 'FontSize', 11, ...
    'XColor', 'k', 'YColor', 'k', 'GridColor', [0.5 0.5 0.5], 'Color', 'w');
xticks(groupSizes);
xticklabels({'K=2', 'K=3', 'K=4', 'K=5'});
ylim([97, 102]);
xlabel('Number of UEs per Group (K)', 'FontWeight', 'bold', 'FontSize', 12, 'Color', 'k');
ylabel('Accuracy vs Brute-Force (%)', 'FontWeight', 'bold', 'FontSize', 12, 'Color', 'k');
title('Scheduling Accuracy vs MU-MIMO Group Size', 'FontSize', 13, 'FontWeight', 'bold', 'Color', 'k');
lg2 = legend([methodNames(1), {'Brute-Force'}], 'Location', 'southwest', 'FontSize', 10);
set(lg2, 'TextColor', 'k', 'Color', 'w', 'EdgeColor', [0.5 0.5 0.5]);

fprintf('\n[DONE] Both figures generated.\n');


% =========================================================================
% LOCAL HELPER — Brute-Force with Distance Lookup Table & Timeout
% =========================================================================
function [bestGroups, bestScore, timedOut] = bruteForceMUMIMOSchedulingWithLookup(W_all, groupSize, maxTimeLimit)
    if nargin < 3
        maxTimeLimit = Inf;
    end

    timedOut = false;
    NUE      = size(W_all, 3);

    % Stage 1 — build full pairwise distance matrix
    fprintf('      [BF Lookup] Computing %dx%d distance matrix...\n', NUE, NUE);
    distMat = zeros(NUE, NUE);
    for i = 1:NUE-1
        for j = i+1:NUE
            d = chordalDistance(W_all(:,:,i), W_all(:,:,j));
            distMat(i,j) = d;
            distMat(j,i) = d;
        end
    end

    % Stage 2 — exhaustive combination search with O(1) lookup
    if isinf(maxTimeLimit)
        fprintf('      [BF Lookup] Evaluating all C(%d,%d) combinations...\n', NUE, groupSize);
    else
        fprintf('      [BF Lookup] Evaluating combinations (Timeout: %d s)...\n', maxTimeLimit);
    end

    bestScore        = -1;
    bestGroup        = [];
    numPairsPerGroup = groupSize * (groupSize - 1) / 2;

    group    = 1:groupSize;
    idxLimit = (NUE - groupSize + 1):NUE;

    tBF       = tic;
    iterCount = 0;

    while true
        iterCount = iterCount + 1;

        % Check timeout every 500,000 iterations to reduce toc() overhead
        if mod(iterCount, 500000) == 0 && toc(tBF) > maxTimeLimit
            fprintf('      [BF Lookup] TIMEOUT after %.1f s (%.0f combinations checked).\n', ...
                toc(tBF), iterCount);
            timedOut = true;
            break;
        end

        % Evaluate current group
        groupDist = 0;
        for a = 1:groupSize-1
            for b = a+1:groupSize
                groupDist = groupDist + distMat(group(a), group(b));
            end
        end
        avgDist = groupDist / numPairsPerGroup;

        if avgDist > bestScore
            bestScore = avgDist;
            bestGroup = group;
        end

        % Generate next combination in lexicographical order
        ptr = groupSize;
        while ptr > 0 && group(ptr) == idxLimit(ptr)
            ptr = ptr - 1;
        end

        if ptr == 0
            break; % All combinations exhausted
        end

        group(ptr) = group(ptr) + 1;
        for j = ptr+1:groupSize
            group(j) = group(j-1) + 1;
        end
    end

    if ~timedOut
        fprintf('      [BF Lookup] Done. Best score: %.4f\n', bestScore);
    end

    bestGroups = {bestGroup};
end