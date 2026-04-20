clear; clc; close all; 
setupPath();

W1 = [
   0.0884 + 0.0000i   0.0884 + 0.0000i   0.0884 + 0.0000i   0.0884 + 0.0000i;
   0.0000 - 0.0884i   0.0000 - 0.0884i   0.0000 - 0.0884i   0.0000 - 0.0884i;
  -0.0884 + 0.0000i  -0.0884 + 0.0000i  -0.0884 + 0.0000i  -0.0884 + 0.0000i;
   0.0000 + 0.0884i   0.0000 + 0.0884i   0.0000 + 0.0884i   0.0000 + 0.0884i;
  -0.0625 + 0.0625i  -0.0625 + 0.0625i  -0.0625 + 0.0625i  -0.0625 + 0.0625i;
   0.0625 + 0.0625i   0.0625 + 0.0625i   0.0625 + 0.0625i   0.0625 + 0.0625i;
   0.0625 - 0.0625i   0.0625 - 0.0625i   0.0625 - 0.0625i   0.0625 - 0.0625i;
  -0.0625 - 0.0625i  -0.0625 - 0.0625i  -0.0625 - 0.0625i  -0.0625 - 0.0625i;
   0.0625 + 0.0625i  -0.0625 - 0.0625i   0.0625 + 0.0625i  -0.0625 - 0.0625i;
   0.0625 - 0.0625i  -0.0625 + 0.0625i   0.0625 - 0.0625i  -0.0625 + 0.0625i;
  -0.0625 - 0.0625i   0.0625 + 0.0625i  -0.0625 - 0.0625i   0.0625 + 0.0625i;
  -0.0625 + 0.0625i   0.0625 - 0.0625i  -0.0625 + 0.0625i   0.0625 - 0.0625i;
  -0.0884 + 0.0000i   0.0884 + 0.0000i  -0.0884 + 0.0000i   0.0884 + 0.0000i;
   0.0000 + 0.0884i   0.0000 - 0.0884i   0.0000 + 0.0884i   0.0000 - 0.0884i;
   0.0884 + 0.0000i  -0.0884 + 0.0000i   0.0884 + 0.0000i  -0.0884 + 0.0000i;
   0.0000 - 0.0884i   0.0000 + 0.0884i   0.0000 - 0.0884i   0.0000 + 0.0884i;
   0.0000 + 0.0884i   0.0000 + 0.0884i   0.0000 - 0.0884i   0.0000 - 0.0884i;
   0.0884 + 0.0000i   0.0884 + 0.0000i  -0.0884 + 0.0000i  -0.0884 + 0.0000i;
   0.0000 - 0.0884i   0.0000 - 0.0884i   0.0000 + 0.0884i   0.0000 + 0.0884i;
  -0.0884 + 0.0000i  -0.0884 + 0.0000i   0.0884 + 0.0000i   0.0884 + 0.0000i;
  -0.0625 - 0.0625i  -0.0625 - 0.0625i   0.0625 + 0.0625i   0.0625 + 0.0625i;
  -0.0625 + 0.0625i  -0.0625 + 0.0625i   0.0625 - 0.0625i   0.0625 - 0.0625i;
   0.0625 + 0.0625i   0.0625 + 0.0625i  -0.0625 - 0.0625i  -0.0625 - 0.0625i;
   0.0625 - 0.0625i   0.0625 - 0.0625i  -0.0625 + 0.0625i  -0.0625 + 0.0625i;
  -0.0625 + 0.0625i   0.0625 - 0.0625i   0.0625 - 0.0625i  -0.0625 + 0.0625i;
   0.0625 + 0.0625i  -0.0625 - 0.0625i  -0.0625 - 0.0625i   0.0625 + 0.0625i;
   0.0625 - 0.0625i  -0.0625 + 0.0625i  -0.0625 + 0.0625i   0.0625 - 0.0625i;
  -0.0625 - 0.0625i   0.0625 + 0.0625i   0.0625 + 0.0625i  -0.0625 - 0.0625i;
   0.0000 - 0.0884i   0.0000 + 0.0884i   0.0000 + 0.0884i   0.0000 - 0.0884i;
  -0.0884 + 0.0000i   0.0884 + 0.0000i   0.0884 + 0.0000i  -0.0884 + 0.0000i;
   0.0000 + 0.0884i   0.0000 - 0.0884i   0.0000 - 0.0884i   0.0000 + 0.0884i;
   0.0884 + 0.0000i  -0.0884 + 0.0000i  -0.0884 + 0.0000i   0.0884 + 0.0000i
];

W2 = [
   0.0884 + 0.0000i   0.0884 + 0.0000i   0.0884 + 0.0000i   0.0884 + 0.0000i;
   0.0625 + 0.0625i   0.0625 + 0.0625i   0.0625 + 0.0625i   0.0625 + 0.0625i;
   0.0000 + 0.0884i   0.0000 + 0.0884i   0.0000 + 0.0884i   0.0000 + 0.0884i;
  -0.0625 + 0.0625i  -0.0625 + 0.0625i  -0.0625 + 0.0625i  -0.0625 + 0.0625i;
   0.0625 - 0.0625i   0.0625 - 0.0625i   0.0625 - 0.0625i   0.0625 - 0.0625i;
   0.0884 + 0.0000i   0.0884 + 0.0000i   0.0884 + 0.0000i   0.0884 + 0.0000i;
   0.0625 + 0.0625i   0.0625 + 0.0625i   0.0625 + 0.0625i   0.0625 + 0.0625i;
   0.0000 + 0.0884i   0.0000 + 0.0884i   0.0000 + 0.0884i   0.0000 + 0.0884i;
   0.0625 + 0.0625i  -0.0625 - 0.0625i   0.0625 + 0.0625i  -0.0625 - 0.0625i;
   0.0000 + 0.0884i   0.0000 - 0.0884i   0.0000 + 0.0884i   0.0000 - 0.0884i;
  -0.0625 + 0.0625i   0.0625 - 0.0625i  -0.0625 + 0.0625i   0.0625 - 0.0625i;
  -0.0884 + 0.0000i   0.0884 + 0.0000i  -0.0884 + 0.0000i   0.0884 + 0.0000i;
   0.0884 + 0.0000i  -0.0884 + 0.0000i   0.0884 + 0.0000i  -0.0884 + 0.0000i;
   0.0625 + 0.0625i  -0.0625 - 0.0625i   0.0625 + 0.0625i  -0.0625 - 0.0625i;
   0.0000 + 0.0884i   0.0000 - 0.0884i   0.0000 + 0.0884i   0.0000 - 0.0884i;
  -0.0625 + 0.0625i   0.0625 - 0.0625i  -0.0625 + 0.0625i   0.0625 - 0.0625i;
   0.0884 + 0.0000i   0.0884 + 0.0000i  -0.0884 + 0.0000i  -0.0884 + 0.0000i;
   0.0625 + 0.0625i   0.0625 + 0.0625i  -0.0625 - 0.0625i  -0.0625 - 0.0625i;
   0.0000 + 0.0884i   0.0000 + 0.0884i   0.0000 - 0.0884i   0.0000 - 0.0884i;
  -0.0625 + 0.0625i  -0.0625 + 0.0625i   0.0625 - 0.0625i   0.0625 - 0.0625i;
   0.0625 - 0.0625i   0.0625 - 0.0625i  -0.0625 + 0.0625i  -0.0625 + 0.0625i;
   0.0884 + 0.0000i   0.0884 + 0.0000i  -0.0884 + 0.0000i  -0.0884 + 0.0000i;
   0.0625 + 0.0625i   0.0625 + 0.0625i  -0.0625 - 0.0625i  -0.0625 - 0.0625i;
   0.0000 + 0.0884i   0.0000 + 0.0884i   0.0000 - 0.0884i   0.0000 - 0.0884i;
   0.0625 + 0.0625i  -0.0625 - 0.0625i  -0.0625 - 0.0625i   0.0625 + 0.0625i;
   0.0000 + 0.0884i   0.0000 - 0.0884i   0.0000 - 0.0884i   0.0000 + 0.0884i;
  -0.0625 + 0.0625i   0.0625 - 0.0625i   0.0625 - 0.0625i  -0.0625 + 0.0625i;
  -0.0884 + 0.0000i   0.0884 + 0.0000i   0.0884 + 0.0000i  -0.0884 + 0.0000i;
   0.0884 + 0.0000i  -0.0884 + 0.0000i  -0.0884 + 0.0000i   0.0884 + 0.0000i;
   0.0625 + 0.0625i  -0.0625 - 0.0625i  -0.0625 - 0.0625i   0.0625 + 0.0625i;
   0.0000 + 0.0884i   0.0000 - 0.0884i   0.0000 - 0.0884i   0.0000 + 0.0884i;
  -0.0625 + 0.0625i   0.0625 - 0.0625i   0.0625 - 0.0625i  -0.0625 + 0.0625i
];

SNR_dBs = 0:5:30;
MCS_list = [0, 5, 11, 27]; 

% Khởi tạo ma trận lưu kết quả
ber1_results = zeros(length(MCS_list), length(SNR_dBs));
ber2_results = zeros(length(MCS_list), length(SNR_dBs));
tp1_results  = zeros(length(MCS_list), length(SNR_dBs));
tp2_results  = zeros(length(MCS_list), length(SNR_dBs));

% Cấu hình cơ bản 
baseConfig = struct('desc', 'Case 1: Default', ...
           'NLAYERS', 4, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 2, 'DMRS_ADDITIONAL_POSITION', 1, ...
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', '2UE_Combine_PDSCH_Waveform_4P2V');

% Khởi tạo pdsch config
pdsch = customPDSCHConfig(); 
pdsch.DMRS.DMRSConfigurationType   = baseConfig.DMRS_CONFIGURATION_TYPE; 
pdsch.DMRS.DMRSTypeAPosition       = baseConfig.DMRS_TYPEA_POSITION; 
pdsch.DMRS.NumCDMGroupsWithoutData = baseConfig.DMRS_NUMCDMGROUP_WITHOUT_DATA;
pdsch.DMRS.DMRSLength              = baseConfig.DMRS_LENGTH;
pdsch.DMRS.DMRSAdditionalPosition  = baseConfig.DMRS_ADDITIONAL_POSITION;
pdsch.NumLayers        = baseConfig.NLAYERS;
pdsch.MappingType      = baseConfig.PDSCH_MAPPING_TYPE;
pdsch.RNTI             = baseConfig.PDSCH_RNTI;
pdsch.PRBSet           = baseConfig.PDSCH_PRBSET;
pdsch.SymbolAllocation = [baseConfig.PDSCH_START_SYMBOL, 14 - baseConfig.PDSCH_START_SYMBOL];
pdsch.DMRS.DMRSPortSet = 0:3;
pdsch.DMRS.NSCID       = 0;

% Xác định Numerology (mu) dựa trên Subcarrier Spacing (30kHz -> mu=1)
mu = log2(baseConfig.SUBCARRIER_SPACING / 15);

fprintf('--- BẮT ĐẦU MÔ PHỎNG SO SÁNH BER VÀ THROUGHPUT GIỮA MCS VÀ SNR ---\n');

for m = 1:length(MCS_list)
    current_mcs = MCS_list(m);
    baseConfig.MCS = current_mcs; 
    pdsch = pdsch.setMCS(current_mcs);
    
    % Tính Max Throughput lý tưởng cho 1 UE (K=2 cho MU-MIMO 2 UE)
    [max_tp_UE, ~] = calculateThroughput(pdsch, mu, 2);
    
    % Lấy TBS để tính BLER
    TBS = manualCalculateTBS(pdsch);

    fprintf('MCS=%d | Modulation=%s | CodeRate=%.4f\n', current_mcs, pdsch.Modulation, pdsch.TargetCodeRate);
    
    for i = 1:length(SNR_dBs)
        SNR_dB = SNR_dBs(i);
        
        [ber1, ber2] = muMIMO2UE(baseConfig, W1, W2, SNR_dB);
        
        % Lưu BER
        ber1_results(m, i) = ber1;
        ber2_results(m, i) = ber2;
        
        % Ước lượng BLER từ BER: BLER = 1 - (1 - BER)^TBS
        bler1 = 1 - (1 - ber1)^TBS;
        bler2 = 1 - (1 - ber2)^TBS;
        
        % Effective Throughput = Max_TP * (1 - BLER)
        tp1_results(m, i) = max_tp_UE * max(0, 1 - bler1);
        tp2_results(m, i) = max_tp_UE * max(0, 1 - bler2);
        
        fprintf('   SNR = %2d dB | BER1=%.2e BLER1=%.4f TP1=%.2f Mbps | BER2=%.2e BLER2=%.4f TP2=%.2f Mbps\n', ...
                SNR_dB, ber1, bler1, tp1_results(m, i), ber2, bler2, tp2_results(m, i));
    end
end

fprintf('--- HOÀN THÀNH MÔ PHỎNG ---\n');

%% --- VẼ ĐỒ THỊ ---
figure('Name', 'Trade-off: MCS vs SNR', 'Position', [100, 100, 1000, 800]);
markers = {'-o', '-s', '-d', '-^'};
legends_cell = cell(length(MCS_list), 1);
for m = 1:length(MCS_list)
    legends_cell{m} = sprintf('MCS %d', MCS_list(m));
end

% 1. BER - UE 1
subplot(2, 2, 1);
hold on;
for m = 1:length(MCS_list)
    semilogy(SNR_dBs, ber1_results(m, :), markers{m}, 'LineWidth', 1.5, 'MarkerSize', 6);
end
hold off; grid on;
title('UE 1: BER vs SNR');
xlabel('SNR (dB)'); ylabel('BER');
legend(legends_cell, 'Location', 'southwest');
ylim([1e-5 1]);

% 2. BER - UE 2
subplot(2, 2, 2);
hold on;
for m = 1:length(MCS_list)
    semilogy(SNR_dBs, ber2_results(m, :), markers{m}, 'LineWidth', 1.5, 'MarkerSize', 6);
end
hold off; grid on;
title('UE 2: BER vs SNR');
xlabel('SNR (dB)'); ylabel('BER');
legend(legends_cell, 'Location', 'southwest');
ylim([1e-5 1]);

% 3. Throughput - UE 1
subplot(2, 2, 3);
hold on;
for m = 1:length(MCS_list)
    plot(SNR_dBs, tp1_results(m, :), markers{m}, 'LineWidth', 1.5, 'MarkerSize', 6);
end
hold off; grid on;
title('UE 1: Effective Throughput vs SNR');
xlabel('SNR (dB)'); ylabel('Throughput (Mbps)');
legend(legends_cell, 'Location', 'northwest');

% 4. Throughput - UE 2
subplot(2, 2, 4);
hold on;
for m = 1:length(MCS_list)
    plot(SNR_dBs, tp2_results(m, :), markers{m}, 'LineWidth', 1.5, 'MarkerSize', 6);
end
hold off; grid on;
title('UE 2: Effective Throughput vs SNR');
xlabel('SNR (dB)'); ylabel('Throughput (Mbps)');
legend(legends_cell, 'Location', 'northwest');

sgtitle('Đánh đổi BER và Throughput giữa các MCS và SNR trong hệ thống MU-MIMO');

