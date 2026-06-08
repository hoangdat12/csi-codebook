% =========================================================================
% simulateRandomMUMIMOScheduling.m
% =========================================================================
clear; clc; close all;
setupPath();

nLayers      = 4;
numberOfUE   = 1000;

config.CodeBookConfig.N1     = 4;
config.CodeBookConfig.N2     = 4;
config.CodeBookConfig.cbMode = 1;
config.FileName = "Layer4_Port32_N1_4_N2-4_c1.txt";

[W_all, UE_Reported_Indices, totalPMI] = prepareData(config, nLayers, numberOfUE);

% =========================================================================
% Build representative UE pool
% =========================================================================
poolConfig.numClusters    = min(totalPMI, 50);
poolConfig.targetPoolSize = 200;
poolConfig.kmeansMaxIter  = 100;

disp('--- Running K-Means to build Representative Pool ---');
[W_pool, pool_indices, pool_pmi] = buildRepresentativePool( ...
    W_all, UE_Reported_Indices, poolConfig);

% =========================================================================
% Pre-compute distance matrix
% =========================================================================
NUE_pool = size(W_pool, 3);
fprintf('--- Pre-computing %dx%d distance matrix for W_pool ---\n', NUE_pool, NUE_pool);
distMat = zeros(NUE_pool, NUE_pool);
for i = 1:NUE_pool-1
    for j = i+1:NUE_pool
        d = chordalDistance(W_pool(:,:,i), W_pool(:,:,j));
        distMat(i,j) = d;
        distMat(j,i) = d;
    end
end
fprintf('--- Distance matrix ready ---\n');

% =========================================================================
% Configuration
% =========================================================================
groupSizes  = [2, 3, 4, 5];
maxIter     = 50;
threshold   = 0.90;

methodNames = {'Symbiotic Organisms Search (SOS)', 'Brute Force (BF)'};

% NaN = not run / skipped
allTimes  = NaN(2, length(groupSizes));
allScores = NaN(2, length(groupSizes));
allCounts = zeros(2, length(groupSizes));

bfFindAllOOM = false(1, length(groupSizes));

fprintf('\n========================================================\n');
fprintf('  GROUP SIZE SWEEP — FindAll Comparison\n');
fprintf('  Fixed threshold = %.2f\n', threshold);
fprintf('========================================================\n');

for gIdx = 1:length(groupSizes)
    K = groupSizes(gIdx);
    fprintf('\n--- Group Size K = %d ---\n', K);
    fprintf('  [FindAll] Fixed threshold = %.2f\n', threshold);

    % ── SOS FindAll ──────────────────────────────────────────────────────
    t = tic;
    [~, ~, sosValidGroups, sosValidScores] = sosMUMIMOSchedulingV2( ...
        W_pool, K, maxIter, threshold);
    allTimes(1, gIdx)  = toc(t);
    allCounts(1, gIdx) = length(sosValidScores);
    if ~isempty(sosValidScores)
        allScores(1, gIdx) = mean(sosValidScores);
    else
        allScores(1, gIdx) = 0;
    end

    % ── BF FindAll — K=5 skip (Out of Memory) ────────────────────────────
    if K < 5
        t = tic;
        [bfValidGroups, bfValidScores, numBFFound] = bruteForceFindAll( ...
            distMat, NUE_pool, K, threshold, Inf);
        allTimes(2, gIdx)  = toc(t);
        allCounts(2, gIdx) = numBFFound;
        if numBFFound > 0
            allScores(2, gIdx) = mean(bfValidScores);
        else
            allScores(2, gIdx) = 0;
        end
        bfFindAllOOM(gIdx) = false;
    else
        fprintf('  [BF FindAll] K=5: Skipped (Out of Memory)\n');
        allCounts(2, gIdx) = 0;
        bfFindAllOOM(gIdx) = true;
    end

    % ── Print summary ─────────────────────────────────────────────────────
    fprintf('\n  %-38s | Time: %7.3f s | MeanScore: %.4f | Found: %5d\n', ...
        methodNames{1}, allTimes(1,gIdx), allScores(1,gIdx), allCounts(1,gIdx));
    if ~bfFindAllOOM(gIdx)
        fprintf('  %-38s | Time: %7.3f s | MeanScore: %.4f | Found: %5d\n', ...
            methodNames{2}, allTimes(2,gIdx), allScores(2,gIdx), allCounts(2,gIdx));
    else
        fprintf('  %-38s | Time:     N/A   | MeanScore:    N/A | Found:   N/A  [Out of Memory]\n', ...
            methodNames{2});
    end
end

% =========================================================================
% FIGURES
% =========================================================================
cSOS = [0.17 0.63 0.17];   % xanh lá — SOS
cBF  = [1.00 0.50 0.05];   % cam     — BF

figPos = {[50  100 750 460], [50  600 750 460]};
xLbls  = {'K=2','K=3','K=4','K=5'};
k5idx  = find(groupSizes == 5);

% ── Figure 1: Execution Time ──────────────────────────────────────────────
figure('Name','Fig 1: Execution Time – FindAll','Color','w','Position',figPos{1});
ax = gca;

t_sos = allTimes(1,:);
t_bf  = allTimes(2,:);   % NaN at K=5

semilogy(groupSizes, t_sos, 's-','LineWidth',2,'MarkerSize',8, ...
    'Color',cSOS,'MarkerFaceColor',cSOS); hold on;

validBF = ~isnan(t_bf);
semilogy(groupSizes(validBF), t_bf(validBF), '^-','LineWidth',2,'MarkerSize',8, ...
    'Color',cBF,'MarkerFaceColor',cBF);

% Annotate OOM at K=5
semilogy(groupSizes(k5idx), t_sos(k5idx)*2, 'rx','MarkerSize',14,'LineWidth',2.5);
text(groupSizes(k5idx), t_sos(k5idx)*3.5, 'BF: Out of Memory', ...
    'FontSize',13,'FontName','Times New Roman','Color','r', ...
    'HorizontalAlignment','center','FontWeight','bold');

% Value labels
for gIdx = 1:length(groupSizes)
    if ~isnan(t_sos(gIdx))
        text(groupSizes(gIdx), t_sos(gIdx)*1.25, sprintf('%.2fs',t_sos(gIdx)), ...
            'FontSize',13,'FontName','Times New Roman', ...
            'HorizontalAlignment','center','Color',cSOS);
    end
    if ~isnan(t_bf(gIdx))
        text(groupSizes(gIdx), t_bf(gIdx)*0.6, sprintf('%.2fs',t_bf(gIdx)), ...
            'FontSize',13,'FontName','Times New Roman', ...
            'HorizontalAlignment','center','Color',cBF);
    end
end

grid on;
set(ax,'YMinorGrid','on','FontSize',18,'XColor','k','YColor','k', ...
    'GridColor',[0.5 0.5 0.5],'Color','w', ...
    'FontName','Times New Roman','LineWidth',1.2);
xticks(groupSizes); xticklabels(xLbls);
xlabel('Number of UEs per Group ($K$)','Interpreter','latex', ...
    'FontName','Times New Roman','FontSize',18,'Color','k');
ylabel('Execution Time (s) -- Log Scale','Interpreter','latex', ...
    'FontName','Times New Roman','FontSize',18,'Color','k');
title('Execution Time: FindAll --- SOS vs Brute Force', ...
    'FontSize',18,'FontWeight','bold','Color','k','FontName','Times New Roman');
lg = legend({'SOS FindAll','BF FindAll ($K$=2..4)'},'Location','northwest', ...
    'Interpreter','latex','FontSize',18);
set(lg,'TextColor','k','Color','w','EdgeColor',[0.5 0.5 0.5], ...
    'FontName','Times New Roman');

% ── Figure 2: Mean Score ──────────────────────────────────────────────────
figure('Name','Fig 2: Mean Score – FindAll','Color','w','Position',figPos{2});
ax = gca;

sc_sos = allScores(1,:);
sc_bf  = allScores(2,:);   % NaN at K=5

plot(groupSizes, sc_sos, 's-','LineWidth',2,'MarkerSize',8, ...
    'Color',cSOS,'MarkerFaceColor',cSOS); hold on;

validBF = ~isnan(sc_bf);
plot(groupSizes(validBF), sc_bf(validBF), '^-','LineWidth',2,'MarkerSize',8, ...
    'Color',cBF,'MarkerFaceColor',cBF);

% Annotate OOM at K=5
plot(groupSizes(k5idx), sc_sos(k5idx), 'rx','MarkerSize',14,'LineWidth',2.5);
text(groupSizes(k5idx), sc_sos(k5idx)-0.015, 'BF: Out of Memory', ...
    'FontSize',13,'FontName','Times New Roman','Color','r', ...
    'HorizontalAlignment','center','FontWeight','bold');

% Value labels
for gIdx = 1:length(groupSizes)
    if ~isnan(sc_sos(gIdx))
        text(groupSizes(gIdx), sc_sos(gIdx)+0.008, sprintf('%.4f',sc_sos(gIdx)), ...
            'FontSize',13,'FontName','Times New Roman', ...
            'HorizontalAlignment','center','Color',cSOS);
    end
    if ~isnan(sc_bf(gIdx))
        text(groupSizes(gIdx), sc_bf(gIdx)-0.010, sprintf('%.4f',sc_bf(gIdx)), ...
            'FontSize',13,'FontName','Times New Roman', ...
            'HorizontalAlignment','center','Color',cBF);
    end
end

grid on;
set(ax,'FontSize',18,'XColor','k','YColor','k','GridColor',[0.5 0.5 0.5],'Color','w', ...
    'FontName','Times New Roman','LineWidth',1.2);
xticks(groupSizes); xticklabels(xLbls);
allValid = [sc_sos(~isnan(sc_sos)), sc_bf(~isnan(sc_bf))];
if ~isempty(allValid)
    ylim([max(0, min(allValid)-0.05), min(1.05, max(allValid)+0.05)]);
end
xlabel('Number of UEs per Group ($K$)','Interpreter','latex', ...
    'FontName','Times New Roman','FontSize',18,'Color','k');
ylabel('Mean Score (Avg Chordal Distance)','Interpreter','latex', ...
    'FontName','Times New Roman','FontSize',18,'Color','k');
title('Mean Score: FindAll --- SOS vs Brute Force', ...
    'FontSize',18,'FontWeight','bold','Color','k','FontName','Times New Roman');
lg = legend({'SOS FindAll','BF FindAll ($K$=2..4)'},'Location','southwest', ...
    'Interpreter','latex','FontSize',18);
set(lg,'TextColor','k','Color','w','EdgeColor',[0.5 0.5 0.5], ...
    'FontName','Times New Roman');

fprintf('\n[DONE] All figures generated.\n');

% =========================================================================
% LOCAL HELPERS
% =========================================================================
function [validGroups, validScores, numFound] = bruteForceFindAll( ...
        distMat, NUE, groupSize, threshold, maxTimeLimit)

    if nargin < 5, maxTimeLimit = Inf; end

    numGroups        = floor(NUE / groupSize);
    numPairsPerGroup = groupSize*(groupSize-1)/2;

    fprintf('      [BF FindAll] Evaluating all C(%d,%d) combinations (K=%d)...\n', ...
        NUE, groupSize, groupSize);

    numCombos  = nchoosek(NUE, groupSize);
    combScores = zeros(numCombos, 1);
    combGroups = zeros(numCombos, groupSize);

    idx      = 0;
    group    = 1:groupSize;
    idxLimit = (NUE-groupSize+1):NUE;
    tStart   = tic;
    timedOut = false;

    while true
        if toc(tStart) > maxTimeLimit
            fprintf('      [BF FindAll] TIMEOUT after %.1fs (%d/%d combos).\n', ...
                toc(tStart), idx, numCombos);
            timedOut = true; break;
        end
        idx = idx + 1;
        d   = 0;
        for a = 1:groupSize-1
            for b = a+1:groupSize
                d = d + distMat(group(a), group(b));
            end
        end
        combScores(idx)    = d / numPairsPerGroup;
        combGroups(idx, :) = group;
        ptr = groupSize;
        while ptr>0 && group(ptr)==idxLimit(ptr), ptr=ptr-1; end
        if ptr==0, break; end
        group(ptr) = group(ptr)+1;
        for j = ptr+1:groupSize, group(j)=group(j-1)+1; end
    end

    combScores = combScores(1:idx);
    combGroups = combGroups(1:idx, :);

    [combScores, si] = sort(combScores, 'descend');
    combGroups       = combGroups(si, :);

    usedUE    = false(1, NUE);
    allGroups = cell(numGroups, 1);
    allScores = zeros(numGroups, 1);
    filled    = 0;

    for c = 1:size(combGroups, 1)
        grp = combGroups(c, :);
        if any(usedUE(grp)), continue; end
        filled            = filled + 1;
        allGroups{filled} = grp;
        allScores(filled) = combScores(c);
        usedUE(grp)       = true;
        if filled == numGroups, break; end
    end

    allGroups = allGroups(1:filled);
    allScores = allScores(1:filled);

    validMask   = allScores >= threshold;
    validGroups = allGroups(validMask);
    validScores = allScores(validMask);
    numFound    = length(validGroups);

    fprintf('      [BF FindAll] Done (%.1fs) | Pairs matched: %d | Above threshold: %d%s\n', ...
        toc(tStart), filled, numFound, ternary(timedOut, ' [TIMEOUT]', ''));
end

function out = ternary(cond, valTrue, valFalse)
    if cond, out = valTrue; else, out = valFalse; end
end