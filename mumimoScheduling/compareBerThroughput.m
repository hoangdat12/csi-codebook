% =========================================================================
% compareBerThroughput.m
%
% Evaluates BER and effective throughput of a fixed pre-selected MU-MIMO
% UE pair (W1, W2) across multiple MCS indices and SNR levels.
%
% Pipeline:
%   1. Sweep MCS indices [0, 5, 11, 27] and SNR range 0:5:30 dB
%   2. Compute BER for each UE via full PHY simulation (muMIMO2UE)
%   3. Estimate BLER from BER: BLER = 1 - (1 - BER)^TBS
%   4. Compute effective throughput per UE and cell sum rate
%
% Requirements:
%   - muMIMO2UE.m, calculateThroughput.m, manualCalculateTBS.m
%   - customPDSCHConfig.m
%   - W1, W2: [32 x 4] precoding matrices (defined in script)
%
% Output:
%   - Figure 1: BER and per-UE throughput (2x2 subplot)
%   - Figure 2: Cell sum rate vs SNR
%   - Console log of BER, BLER, throughput, and sum rate per MCS/SNR point
% =========================================================================
clear; clc; close all;
setupPath();

% ----------------------------------------------------------------------------
% Precoding matrices W1 and W2 for the two scheduled UEs.
% These are hardcoded from a pre-selected orthogonal pair and can be replaced
% with output from simulateRandomMUMIMOScheduling.
%
% Requirements:
%   - W1 and W2 must satisfy the orthogonality threshold (chordal distance
%     >= 0.9999) since the Tx/Rx chain does not apply ZF or MMSE interference
%     cancellation between UEs. Insufficient orthogonality will cause
%     inter-user interference and degrade BER directly.
% ----------------------------------------------------------------------------
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

% ----------------------------------------------------------------------------
% The configuration parameters for the test
% ----------------------------------------------------------------------------
SNR_dBs  = 0:5:30;
MCS_list = [0, 5, 11, 27];

% Initialize result matrices
ber1_results    = zeros(length(MCS_list), length(SNR_dBs));
ber2_results    = zeros(length(MCS_list), length(SNR_dBs));
tp1_results     = zeros(length(MCS_list), length(SNR_dBs));
tp2_results     = zeros(length(MCS_list), length(SNR_dBs));
sumRate_results = zeros(length(MCS_list), length(SNR_dBs));

% Base PDSCH configuration
baseConfig = struct('desc', 'Case 1: Default', ...
           'NLAYERS', 4, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 2, 'DMRS_ADDITIONAL_POSITION', 1, ...
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', '2UE_Combine_PDSCH_Waveform_4P2V');

% Initialize PDSCH config object
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

% Derive numerology mu from subcarrier spacing (30 kHz -> mu = 1)
mu = log2(baseConfig.SUBCARRIER_SPACING / 15);

% ----------------------------------------------------------------------------
% Sweep through MCS and SNR
% ----------------------------------------------------------------------------
fprintf('--- BER AND THROUGHPUT SIMULATION ACROSS MCS AND SNR ---\n');

for m = 1:length(MCS_list)
    current_mcs    = MCS_list(m);
    baseConfig.MCS = current_mcs;
    pdsch          = pdsch.setMCS(current_mcs);

    % Peak throughput for a single UE (K=1)
    [max_tp_UE, ~] = calculateThroughput(pdsch, mu, 1);

    % TBS used to estimate BLER from BER
    TBS = manualCalculateTBS(pdsch);

    fprintf('MCS=%d | Modulation=%s | CodeRate=%.4f | Max TP/UE=%.2f Mbps\n', ...
            current_mcs, pdsch.Modulation, pdsch.TargetCodeRate, max_tp_UE);

    for i = 1:length(SNR_dBs)
        SNR_dB = SNR_dBs(i);

        [ber1, ber2] = muMIMO2UE(baseConfig, W1, W2, SNR_dB);

        ber1_results(m, i) = ber1;
        ber2_results(m, i) = ber2;

        % Estimate BLER from BER: BLER = 1 - (1 - BER)^TBS
        bler1 = 1 - (1 - ber1)^TBS;
        bler2 = 1 - (1 - ber2)^TBS;

        % Effective throughput per UE = peak TP * (1 - BLER)
        tp1 = max_tp_UE * max(0, 1 - bler1);
        tp2 = max_tp_UE * max(0, 1 - bler2);

        % Cell sum rate = sum of effective throughput across all UEs
        sumRate = tp1 + tp2;

        tp1_results(m, i)     = tp1;
        tp2_results(m, i)     = tp2;
        sumRate_results(m, i) = sumRate;

        fprintf('   SNR=%2d dB | BER1=%.2e BLER1=%.4f TP1=%.2f Mbps | BER2=%.2e BLER2=%.4f TP2=%.2f Mbps | SumRate=%.2f Mbps\n', ...
                SNR_dB, ber1, bler1, tp1, ber2, bler2, tp2, sumRate);
    end
end

fprintf('--- SIMULATION COMPLETE ---\n');


% ----------------------------------------------------------------------------
% Plotting Results
% ----------------------------------------------------------------------------
markers      = {'-o', '-s', '-d', '-^'};
legends_cell = cell(length(MCS_list), 1);
for m = 1:length(MCS_list)
    legends_cell{m} = sprintf('MCS %d', MCS_list(m));
end

% Figure 1: BER and per-UE throughput
figure('Name', 'BER & Throughput per UE', 'Position', [100, 100, 1000, 800]);

% Panel 1: BER - UE 1
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

% Panel 2: BER - UE 2
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

% Panel 3: Effective throughput - UE 1
subplot(2, 2, 3);
hold on;
for m = 1:length(MCS_list)
    plot(SNR_dBs, tp1_results(m, :), markers{m}, 'LineWidth', 1.5, 'MarkerSize', 6);
end
hold off; grid on;
title('UE 1: Effective Throughput vs SNR');
xlabel('SNR (dB)'); ylabel('Throughput (Mbps)');
legend(legends_cell, 'Location', 'northwest');

% Panel 4: Effective throughput - UE 2
subplot(2, 2, 4);
hold on;
for m = 1:length(MCS_list)
    plot(SNR_dBs, tp2_results(m, :), markers{m}, 'LineWidth', 1.5, 'MarkerSize', 6);
end
hold off; grid on;
title('UE 2: Effective Throughput vs SNR');
xlabel('SNR (dB)'); ylabel('Throughput (Mbps)');
legend(legends_cell, 'Location', 'northwest');

sgtitle('BER and Throughput Trade-off across MCS and SNR (MU-MIMO 2 UEs)');

% Figure 2: Cell sum rate
figure('Name', 'Cell Sum Rate', 'Position', [150, 150, 600, 450]);
hold on;
for m = 1:length(MCS_list)
    plot(SNR_dBs, sumRate_results(m, :), markers{m}, 'LineWidth', 1.5, 'MarkerSize', 6);
end
hold off; grid on;
title('Cell Sum Rate vs SNR');
xlabel('SNR (dB)'); ylabel('Sum Rate (Mbps)');
legend(legends_cell, 'Location', 'northwest');
sgtitle('Cell Sum Rate across MCS and SNR (MU-MIMO 2 UEs)');