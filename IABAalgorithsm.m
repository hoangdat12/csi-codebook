% =========================================================================
% MAIN SCRIPT: IABA MU-MIMO SCHEDULING SIMULATION (4 PORTS, 2 LAYERS)
% =========================================================================
clear; clc; close all;
setupPath(); 

nLayers = 2; 

% -----------------------------------------------------------------
% Carrier Configuration
% -----------------------------------------------------------------
carrier = nrCarrierConfig;
carrier.SubcarrierSpacing = 30;
carrier.NSizeGrid = 273;

% -----------------------------------------------------------------
% PDSCH Configuration
% -----------------------------------------------------------------
pdsch = nrPDSCHConfig;
pdsch.DMRS.DMRSConfigurationType = 1;
pdsch.DMRS.DMRSAdditionalPosition = 1;
pdsch.NumLayers = nLayers;
pdsch.PRBSet = 0:272;

% Csi Config
csiConfig = nrCSIRSConfig;
csiConfig.CSIRSType = {'nzp'};
% https://www.etsi.org/deliver/etsi_ts/138200_138299/138211/18.06.00_60/ts_138211v180600p.pdf
% Bảng 7.4.1.5.3-1.
% 6 -> 8 Ports
% 11 -> 16 Ports
% 16 -> 32 Ports

rowNumber = 4;
csiReportAntenna = [1 2 1];
csiReportSymbolLocations = {0};


csiConfig.RowNumber = rowNumber;           
csiConfig.Density = {'one'};
csiConfig.SubcarrierLocations = {0};
csiConfig.SymbolLocations = csiReportSymbolLocations;
csiConfig.CSIRSPeriod = [4 0];
csiConfig.NumRB = 273;
csiConfig.RBOffset = 0;

% CSI Report Config (Type II)
subbandAmplitude = true;
csiReport = nrCSIReportConfig;
% Table 2 support 256QAM
csiReport.CQITable = "table2"; 
csiReport.CodebookType = "type2";
% [Ng N1 N2]
csiReport.PanelDimensions = csiReportAntenna; 
% Report PMI for each subband
csiReport.PMIFormatIndicator = "subband";
% Report CQI for every subband
csiReport.CQIFormatIndicator = "subband";
csiReport.SubbandSize = 32;
csiReport.SubbandAmplitude = subbandAmplitude;
csiReport.NumberOfBeams = 2;
csiReport.PhaseAlphabetSize = 4;
csiReport.RIRestriction = [1 1 0 0]; 

% -------------------------------------------------------------------------
% 1. Cấu hình thông số mạng và Pool
% -------------------------------------------------------------------------
Num_UEs = 100;            % Số lượng UE trong Pool
nTxAnts = csiConfig.NumCSIRSPorts;
nRxAnts = 2;             % Số anten thu UE (2R) - Bắt buộc >= nLayers để giải mã
noiseVar = 1e-9;         % Công suất nhiễu (N)

H_pool = cell(1, Num_UEs);
W_pool = zeros(nTxAnts, nLayers, Num_UEs); % Kích thước: 4 x 2 x Num_UEs

% Khởi tạo cfg cho generateTypeIIPrecoder
cfg = struct();
cfg.CodebookConfig.N1 = csiReport.PanelDimensions(2);  % = 2 (N1)
cfg.CodebookConfig.N2 = csiReport.PanelDimensions(3);  % = 1 (N2)
cfg.CodebookConfig.O1 = 4;
cfg.CodebookConfig.O2 = 1;
cfg.CodebookConfig.NumberOfBeams = csiReport.NumberOfBeams;
cfg.CodebookConfig.PhaseAlphabetSize = csiReport.PhaseAlphabetSize;
cfg.CodebookConfig.SubbandAmplitude = csiReport.SubbandAmplitude;
cfg.CodebookConfig.numLayers = nLayers;

disp(cfg);

fprintf('--- BƯỚC 1: THU THẬP KÊNH VÀ PMI CHO %d UEs ---\n', Num_UEs);

for u = 1:Num_UEs
    % 1.1 MÔ PHỎNG KÊNH VẬT LÝ (H_real) - Kích thước: 2 Rx x 4 Tx
    H_real = (randn(nRxAnts, nTxAnts) + 1i * randn(nRxAnts, nTxAnts)) / sqrt(2);
    H_pool{u} = H_real; 
    
    % 1.2 TẠO HÀM MÔ PHỎNG CHANNEL
    channelFunc = @(tx) tx * H_real.' + sqrt(noiseVar/2)*(randn(size(tx,1), nRxAnts) + 1i*randn(size(tx,1), nRxAnts));
    
    % [! LƯU Ý MÔ PHỎNG MOCK-UP]
    % Ở đây tôi dùng thuật toán SVD để tạo nhanh Precoder W_u (Size: 4x2) phòng khi 
    % hàm generateTypeIIPrecoder của bạn chưa hoạt động với 2 layers.
    % Nếu csiRsMesurements chạy chuẩn, hãy mở comment 2 dòng dưới.
    
    [MCS_u, PMI_u] = csiRsMesurements(carrier, channelFunc, csiConfig, csiReport, pdsch, nLayers);
    W_u = generateTypeIIPrecoder(cfg, PMI_u.i1, PMI_u.i2); 
    
    % [~, ~, V] = svd(H_real);
    % W_u = V(:, 1:nLayers); % Lấy 2 singular vectors tốt nhất
    
    % Lưu vào Pool
    if ndims(W_u) == 3
        W_pool(:, :, u) = W_u(:, :, 1); % Lấy subband 1
    else
        W_pool(:, :, u) = W_u(:, :); 
    end
end

% -------------------------------------------------------------------------
% 2. Chạy thuật toán tìm cặp MU-MIMO
% -------------------------------------------------------------------------
fprintf('\n--- BƯỚC 2: TÌM CẶP MU-MIMO (ZERO-FORCING & M-MIMO SINR EVALUATION) ---\n');

[ue1_idx, ue2_idx, bestSumRate, final_sinr1, final_sinr2] = findBestMUMIMOPair(W_pool, H_pool, noiseVar);

% -------------------------------------------------------------------------
% 3. Xuất kết quả
% -------------------------------------------------------------------------
fprintf('\n--- BƯỚC 3: KẾT QUẢ CẤP PHÁT BPL ---\n');
if ue1_idx ~= -1
    fprintf('=> THÀNH CÔNG: Đã ghép cặp UE %d và UE %d\n', ue1_idx, ue2_idx);
    fprintf('=> SINR trung bình tại UE 1: %.2f dB\n', final_sinr1);
    fprintf('=> SINR trung bình tại UE 2: %.2f dB\n', final_sinr2);
    fprintf('=> Tổng thông lượng mạng (Sum-Rate): %.2f bps/Hz\n', bestSumRate);
else
    fprintf('=> THẤT BẠI: Không có cặp UE nào thỏa mãn ngưỡng SINR.\n');
end

% =========================================================================
% CÁC HÀM XỬ LÝ (LOCAL FUNCTIONS)
% =========================================================================

function [sinr1_dB, sinr2_dB, sumRate, wp1, wp2] = evaluateMUMIMOPair(H1, H2, W1, W2, noiseVar)
    nRx     = size(H1, 1);   % 2
    nTx     = size(W1, 1);   % 4
    nLayers = size(W1, 2);   % 2

    % Effective channel: gNB nhìn thấy kênh qua beam W
    % H_eff shape: (nRx × nTx) * (nTx × nLayers) = (2×2)
    H_eff1 = H1 * W1;   % (2×2)
    H_eff2 = H2 * W2;   % (2×2)

    % ZF tính trên effective channel — mỗi UE là 1 scalar channel (nLayers=2)
    % Để null interference giữa 2 UE, gNB cần biết H_eff của cả 2
    % Aggregate: (2×2) stacked → dùng block ZF

    % Signal power tại UE1 khi dùng W1: s1 = H1*W1*x1
    % Interference tại UE1 từ UE2:       i1 = H1*W2*x2
    % ZF condition: H1*W2 → 0, tức W2 phải nằm trong null space của H1

    % Null space approach:
    % Tìm W2_ZF sao cho H1 * W2_ZF = 0
    % Tìm W1_ZF sao cho H2 * W1_ZF = 0

    % Null space của H1 (2×4): có 2 chiều null
    [~, ~, V1] = svd(H1);
    null_H1 = V1(:, nRx+1:end);   % (4×2) — null space của H1

    % Null space của H2
    [~, ~, V2] = svd(H2);
    null_H2 = V2(:, nRx+1:end);   % (4×2) — null space của H2

    % Project W1 vào null space của H2 (để H2*wp1 = 0)
    wp1_raw = null_H2 * (null_H2' * W1);   % (4×2)

    % Project W2 vào null space của H1 (để H1*wp2 = 0)  
    wp2_raw = null_H1 * (null_H1' * W2);   % (4×2)

    % Normalize
    wp1 = wp1_raw / norm(wp1_raw, 'fro');
    wp2 = wp2_raw / norm(wp2_raw, 'fro');

    % SINR
    Cov_sig1 = (H1 * wp1) * (H1 * wp1)';
    Cov_int1 = (H1 * wp2) * (H1 * wp2)' + noiseVar * eye(nRx);
    rate1    = real(log2(det(eye(nRx) + Cov_int1 \ Cov_sig1)));

    Cov_sig2 = (H2 * wp2) * (H2 * wp2)';
    Cov_int2 = (H2 * wp1) * (H2 * wp1)' + noiseVar * eye(nRx);
    rate2    = real(log2(det(eye(nRx) + Cov_int2 \ Cov_sig2)));

    sumRate  = rate1 + rate2;

    sinr1_dB = 10 * log10(max(2^(rate1/nLayers) - 1, 1e-10));
    sinr2_dB = 10 * log10(max(2^(rate2/nLayers) - 1, 1e-10));
end

function [ue1_idx, ue2_idx, bestSumRate, final_sinr1, final_sinr2, best_W1, best_W2, best_wp1, best_wp2] = ...
    findBestMUMIMOPair(W_pool, H_pool, noiseVar)

    NUE = size(W_pool, 3);

    bestSumRate = 0;
    ue1_idx     = -1;
    ue2_idx     = -1;
    final_sinr1 = -inf;
    final_sinr2 = -inf;
    best_W1     = [];
    best_W2     = [];
    best_wp1    = [];
    best_wp2    = [];

    SINR_MIN_dB = -5;

    for i = 1:NUE-1
        for j = i+1:NUE
            W_i = W_pool(:, :, i);
            W_j = W_pool(:, :, j);
            H_i = H_pool{i};
            H_j = H_pool{j};

            [sinr_i, sinr_j, sumRate, wp1, wp2] = evaluateMUMIMOPair(H_i, H_j, W_i, W_j, noiseVar);

            if (sinr_i >= SINR_MIN_dB) && (sinr_j >= SINR_MIN_dB)
                if sumRate > bestSumRate
                    bestSumRate = sumRate;
                    ue1_idx     = i;
                    ue2_idx     = j;
                    final_sinr1 = sinr_i;
                    final_sinr2 = sinr_j;
                    best_W1     = W_i;
                    best_W2     = W_j;
                    best_wp1    = wp1;
                    best_wp2    = wp2;
                end
            end
        end
    end

    if ue1_idx == -1
        fprintf('=> THẤT BẠI: Không có cặp UE nào thỏa mãn ngưỡng SINR.\n');
        return;
    end

    % Lấy H của cặp tốt nhất từ pool
    H_best1 = H_pool{ue1_idx};
    H_best2 = H_pool{ue2_idx};

    fprintf('\n======================================================\n');
    fprintf('=> TÌM THẤY CẶP TỐT NHẤT: UE %d và UE %d\n', ue1_idx, ue2_idx);
    fprintf('======================================================\n');

    fprintf('\n--- PRECODER TỪ UE %d (W1 report) ---\n', ue1_idx);
    disp(best_W1);

    fprintf('\n--- PRECODER TỪ UE %d (W2 report) ---\n', ue2_idx);
    disp(best_W2);

    fprintf('\n--- FINAL PRECODER SAU ZF CHO UE %d (wp1, 4x2) ---\n', ue1_idx);
    disp(best_wp1);

    fprintf('\n--- FINAL PRECODER SAU ZF CHO UE %d (wp2, 4x2) ---\n', ue2_idx);
    disp(best_wp2);

    % Kiểm tra độ trực giao (antenna domain — không quan trọng)
    overlap = norm(best_wp1' * best_wp2, 'fro');
    fprintf('||wp1^H * wp2|| = %.6f  (antenna domain, khong can = 0)\n', overlap);

    % Kiểm tra leakage sau kênh (mới quan trọng)
    signal_UE1  = norm(H_best1 * best_wp1, 'fro');
    leakage_UE1 = norm(H_best1 * best_wp2, 'fro');

    signal_UE2  = norm(H_best2 * best_wp2, 'fro');
    leakage_UE2 = norm(H_best2 * best_wp1, 'fro');

    fprintf('\nSignal UE%d:  %.4f | Leakage tu UE%d vao UE%d: %.4f\n', ...
            ue1_idx, signal_UE1, ue2_idx, ue1_idx, leakage_UE1);
    fprintf('Signal UE%d:  %.4f | Leakage tu UE%d vao UE%d: %.4f\n', ...
            ue2_idx, signal_UE2, ue1_idx, ue2_idx, leakage_UE2);

    % SIR (Signal-to-Interference Ratio thuần, không noise)
    SIR1_dB = 20 * log10(signal_UE1 / max(leakage_UE1, 1e-12));
    SIR2_dB = 20 * log10(signal_UE2 / max(leakage_UE2, 1e-12));
    fprintf('\nSIR tai UE%d: %.2f dB\n', ue1_idx, SIR1_dB);
    fprintf('SIR tai UE%d: %.2f dB\n', ue2_idx, SIR2_dB);
end