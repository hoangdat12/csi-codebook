clear; clc; close all; 
setupPath();

nLayers = 4;
numberOfUeToGroup = 2;
numberOfUE = 20000;

config.CodeBookConfig.N1 = 4;
config.CodeBookConfig.N2 = 4;
config.CodeBookConfig.cbMode = 1;
config.FileName = "Layer4_Port32_N1_4_N2-4_c1.txt";

[W_all, UE_Reported_Indices, totalPMI] = prepareData(config, nLayers, numberOfUE);

baseConfig = struct('desc', 'Case 1: Default', ...
           'NLAYERS', nLayers, 'MCS', 27, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 2, 'DMRS_ADDITIONAL_POSITION', 1, ...
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', '2UE_Combine_PDSCH_Waveform_4P2V');

% =========================================================================
% 3. Pre-Processing: Build representative UE pool via K-Means clustering
% =========================================================================
poolConfig = struct();
poolConfig.numClusters = min(totalPMI, 500);
poolConfig.targetPoolSize = 2000;
poolConfig.kmeansMaxIter  = 100;

disp('--- Running K-Means to build Representative Pool ---');
[W_pool, pool_indices, pool_pmi] = buildRepresentativePool(W_all, UE_Reported_Indices, poolConfig);

% =========================================================================
% TÌM CÁC CẶP TRỰC GIAO VÀ TEST BER
% =========================================================================
threshold = 0.9999; % Ngưỡng trực giao
fprintf('\n[Pre-search] Finding feasible orthogonal UE pairs (score >= %.2f)...\n', threshold);

% Gọi hàm mới của bro (Trả về danh sách các nhóm)
[f_groups, f_W, f_scores, f_pmi] = findFeasibleOrthogonalGroups(W_pool, pool_pmi, numberOfUeToGroup, 50, threshold);

if ~isempty(f_W)
    fprintf('\n---> Đưa cặp ĐẦU TIÊN đạt chuẩn vào test BER Loopback quét dải SNR...\n');
    
    % Lấy ma trận W của nhóm ĐẦU TIÊN trong danh sách
    W_test = f_W{1}; 

    % ── ĐỊNH NGHĨA DẢI SNR QUÉT ──────────────────────────────────────────
    snrRange = 0:5:30; 
    
    % Khởi tạo mảng lưu kết quả
    ber1_results = zeros(length(snrRange), 1);
    ber2_results = zeros(length(snrRange), 1);
    
    fprintf('\n[KẾT QUẢ TEST BER MU-MIMO THEO SNR]\n');
    fprintf('SNR (dB) | BER UE 1     | BER UE 2\n');
    fprintf('----------------------------------------\n');
    
    W_UE1_Codebook = W_test(:,:,1);
    W_UE2_Codebook = W_test(:,:,2);
    disp(W_UE1_Codebook);
    disp(W_UE2_Codebook);

    % ── VÒNG LẶP TEST SNR ────────────────────────────────────────────────
    for i = 1:length(snrRange)
        currentSNR = snrRange(i);
        
        [ber1, ber2] = muMIMO2UE(baseConfig, W_UE1_Codebook, W_UE2_Codebook, currentSNR);
        
        % Lưu kết quả vào mảng
        ber1_results(i) = ber1;
        ber2_results(i) = ber2;
        
        % In kết quả của từng mức SNR ra Command Window
        fprintf('%8d | %10.6f | %10.6f\n', currentSNR, ber1, ber2);
    end
    
    % ── VẼ BIỂU ĐỒ BER (WATERFALL CURVE) ─────────────────────────────────
    figure('Name', 'MU-MIMO BER Performance', 'Color', 'w');
    semilogy(snrRange, ber1_results, '-ob', 'LineWidth', 2, 'MarkerSize', 6);
    hold on;
    semilogy(snrRange, ber2_results, '-sr', 'LineWidth', 2, 'MarkerSize', 6);
    
    grid on;
    % Bật grid phụ để nhìn log-scale rõ hơn
    set(gca, 'YMinorGrid', 'on'); 
    
    xlabel('SNR (dB)', 'FontWeight', 'bold');
    ylabel('Bit Error Rate (BER)', 'FontWeight', 'bold');
    title('Hiệu năng BER của hệ thống MU-MIMO (2 UEs)', 'FontSize', 12);
    legend('UE 1', 'UE 2', 'Location', 'southwest');
else
    fprintf('\n[THẤT BẠI] SOS không tìm được cặp nào đạt ngưỡng trực giao %.2f.\n', threshold);
    fprintf('Gợi ý: Thử giảm threshold xuống 0.8 hoặc tăng targetPoolSize/maxIter lên.\n');
end

% =========================================================================
% LOCAL FUNCTIONS 
% =========================================================================
function [feasible_groups, feasible_W, feasible_scores, feasible_pmi] = findFeasibleOrthogonalGroups(W_pool, pool_pmi, num_users_to_group, maxIter, threshold)
    if nargin < 5
        threshold = 0.9; % Ngưỡng trực giao mặc định
    end
    if nargin < 4
        maxIter = 50; 
    end

    fprintf('[GroupSearch] Running SOS Algorithm...\n');
    % [bestGroups, ~] = sosMUMIMOScheduling(W_pool, num_users_to_group, maxIter);
    [bestGroups, ~] = psoMUMIMOScheduling(W_pool, num_users_to_group, maxIter);

    feasible_groups = {};
    feasible_scores = [];
    feasible_W      = {};
    feasible_pmi    = {};

    numGroups = length(bestGroups);
    for g = 1:numGroups
        current_group = bestGroups{g};
        min_dist_in_group = inf;
        
        for i = 1:num_users_to_group-1
            for j = i+1:num_users_to_group
                u1 = current_group(i);
                u2 = current_group(j);
                dist = chordalDistance(W_pool(:,:,u1), W_pool(:,:,u2));
                if dist < min_dist_in_group
                    min_dist_in_group = dist;
                end
            end
        end
        
        if min_dist_in_group >= threshold
            feasible_groups{end+1} = current_group;      % Lưu index
            feasible_scores(end+1) = min_dist_in_group;  % Lưu điểm thực tế
            feasible_W{end+1}      = W_pool(:, :, current_group); % Lưu ma trận W
            feasible_pmi{end+1}    = pool_pmi(current_group);     % Lưu tên PMI
        end
    end

    % =====================================================================
    % In thống kê kết quả
    % =====================================================================
    fprintf('\n========================================\n');
    fprintf('  SOS Scheduling Completed!\n');
    fprintf('  - Total groups evaluated: %d\n', numGroups);
    fprintf('  - FEASIBLE GROUPS FOUND (Score >= %.2f): %d\n', threshold, length(feasible_groups));
    fprintf('========================================\n');
    
    for k = 1:length(feasible_groups)
        fprintf('  Group %d: UEs [%s] | Min Distance = %.4f\n', ...
            k, num2str(feasible_groups{k}), feasible_scores(k));
    end
    fprintf('\n');
end
