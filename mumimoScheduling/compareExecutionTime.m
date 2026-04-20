% =========================================================================
% SCRIPT: K-MEANS + SOS VS PSO MU-MIMO SCHEDULING FOR 20,000 UEs
% Antenna: 32T32R | Compare execution time between SOS and PSO
% =========================================================================

clear; clc; close all;
setupPath();

nLayers            = 4;
numberOfUeToGroup  = 2;
numberOfUE         = 20000;

config.CodeBookConfig.N1     = 4;
config.CodeBookConfig.N2     = 4;
config.CodeBookConfig.cbMode = 1;
config.FileName              = "Layer4_Port32_N1_4_N2-4_c1.txt";

[W_all, UE_Reported_Indices, totalPMI] = ...
    prepareData(config, nLayers, numberOfUE);

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

disp('--- Running K-Means to build Representative Pool ---');

[W_pool, pool_indices, pool_pmi] = ...
    buildRepresentativePool(W_all, UE_Reported_Indices, poolConfig);

maxIter   = 50;
threshold = 0.90;

fprintf('\n--- BENCHMARK: SOS vs PSO (MaxIter = %d, Threshold = %.2f) ---\n', ...
    maxIter, threshold);

fprintf('\nRunning SOS...\n');

tic;
[bestGroupsSOS, scoreSOS] = ...
    sosMUMIMOScheduling(W_pool, numberOfUeToGroup, maxIter);
timeSOS = toc;

validPairsSOS = countValidPairs(bestGroupsSOS, W_pool, threshold);

fprintf('Running PSO...\n');

tic;
[bestGroupsPSO, scorePSO] = ...
    psoMUMIMOScheduling(W_pool, numberOfUeToGroup, maxIter);
timePSO = toc;

validPairsPSO = countValidPairs(bestGroupsPSO, W_pool, threshold);

fprintf('\n================ BENCHMARK SUMMARY =================\n');
fprintf('%-25s | %-15s | %-15s\n', 'Metric', 'SOS', 'PSO');
fprintf('---------------------------------------------------\n');

fprintf('%-25s | %-15.4f | %-15.4f\n', ...
    'Execution Time (s)', timeSOS, timePSO);

fprintf('%-25s | %-15.4f | %-15.4f\n', ...
    'Average Score', scoreSOS, scorePSO);

fprintf('%-25s | %-15d | %-15d\n', ...
    sprintf('Pairs >= %.2f', threshold), ...
    validPairsSOS, validPairsPSO);

fprintf('===================================================\n');

% =========================================================================
% 5. VẼ BIỂU ĐỒ SO SÁNH (VISUALIZATION)
% =========================================================================
figure('Name', 'So sánh Hiệu năng SOS vs PSO', 'Color', 'w', 'Position', [100, 100, 1000, 450]);

% --- Đồ thị 1: Thời gian thực thi (Càng thấp càng tốt) ---
subplot(1, 2, 1);
bar_data_time = [timeSOS, timePSO];
b1 = bar(bar_data_time, 0.6, 'FaceColor', 'flat');
b1.CData(1,:) = [0.2 0.6 0.8]; % Màu xanh dương cho SOS
b1.CData(2,:) = [0.8 0.2 0.2]; % Màu đỏ cho PSO

set(gca, 'XTickLabel', {'SOS', 'PSO'}, 'FontSize', 11);
ylabel('Thời gian thực thi (giây)');
title('So sánh Thời gian chạy');
grid on;
text(1:2, bar_data_time, num2str(bar_data_time', '%.3f s'), ...
    'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');

% --- Đồ thị 2: Số cặp đạt ngưỡng & Score (Càng cao càng tốt) ---
subplot(1, 2, 2);
% Chuẩn hóa dữ liệu để hiển thị cùng lúc (tùy chọn) hoặc vẽ group bar
bar_data_perf = [validPairsSOS, validPairsPSO];
b2 = bar(bar_data_perf, 0.6, 'FaceColor', 'flat');
b2.CData(1,:) = [0.2 0.7 0.3]; % Màu xanh lá cho SOS
b2.CData(2,:) = [0.9 0.6 0];   % Màu cam cho PSO

set(gca, 'XTickLabel', {'SOS', 'PSO'}, 'FontSize', 11);
ylabel(['Số cặp đạt Chordal Dist >= ', num2str(threshold)]);
title(['Hiệu quả ghép cặp (Threshold = ', num2str(threshold), ')']);
grid on;
text(1:2, bar_data_perf, num2str(bar_data_perf'), ...
    'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');

% Thêm chú thích tổng quan
sgtitle(['Phân tích Hiệu năng MU-MIMO Scheduling: SOS vs PSO (Pool Size: ', num2str(poolConfig.targetPoolSize), ')']);

fprintf('\n[Thông báo] Đã vẽ xong biểu đồ so sánh.\n');



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