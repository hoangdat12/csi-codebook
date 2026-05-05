clear; clc; close all;
setupPath();

% =========================================================================
% ĐẦU VÀO — THAY ĐỔI Ở ĐÂY
% =========================================================================
PMI1   = 929;
LAYER1 = 3;
MCS1   = 10;

PMI2   = 27;
LAYER2 = 2;
MCS2   = 10;

% =========================================================================
% NẠP CODEBOOK (layer 1, 2, 3, 4)
% =========================================================================
fprintf('Nap codebook...\n');
pool{1} = loadPMIFile('Layer1_Port32_N1_4_N2-4_c1.txt', 32, 1);
pool{2} = loadPMIFile('Layer2_Port32_N1_4_N2-4_c1.txt', 32, 2);
pool{3} = loadPMIFile('Layer3_Port32_N1_4_N2-4_c1.txt', 32, 3);
pool{4} = loadPMIFile('Layer4_Port32_N1_4_N2-4_c1.txt', 32, 4);
fprintf('Done.\n\n');

% Validate PMI index
assert(PMI1 >= 1 && PMI1 <= size(pool{LAYER1}, 3), ...
    'PMI1=%d vuot qua pool layer%d (max=%d)', PMI1, LAYER1, size(pool{LAYER1},3));
assert(PMI2 >= 1 && PMI2 <= size(pool{LAYER2}, 3), ...
    'PMI2=%d vuot qua pool layer%d (max=%d)', PMI2, LAYER2, size(pool{LAYER2},3));
assert(LAYER1 + LAYER2 <= 7, ...
    'Tong layer %d+%d=%d > 7, khong hop le cho MU-MIMO', LAYER1, LAYER2, LAYER1+LAYER2);

% =========================================================================
% LẤY W
% =========================================================================
W1 = pool{LAYER1}(:, :, PMI1);
W2 = pool{LAYER2}(:, :, PMI2);

% =========================================================================
% TÍNH CHORDAL DISTANCE
% Dùng QR + SVD — đồng bộ với Python model (chordal_distance trong train script)
% dist = sqrt(max(L - sum(sv^2), 0)) / sqrt(L)
% =========================================================================
cd_score = chordalDistance(W1, W2);

% =========================================================================
% MCS → CQI → SINR nominal (Shannon inverse từ CQI Table 2)
% Đồng bộ với dataset: SINR_nominal = 2^efficiency - 1
% =========================================================================
cqi1      = mcsToCqi(MCS1);
cqi2      = mcsToCqi(MCS2);
sinr_nom1 = cqiToSinrNominal(cqi1);   % Shannon inverse
sinr_nom2 = cqiToSinrNominal(cqi2);

% =========================================================================
% TÍNH SINR VÀ SUMRATE
% Đồng bộ với compute_sumrate() trong Python
% IUI = (1 - cd) * ri_other * sinr_nom_other
% =========================================================================
interference = 1.0 - cd_score;
iui_on_ue1   = interference * LAYER2 * sinr_nom2;
iui_on_ue2   = interference * LAYER1 * sinr_nom1;

sinr1      = (LAYER1 * sinr_nom1) / (iui_on_ue1 + 1.0);
sinr2      = (LAYER2 * sinr_nom2) / (iui_on_ue2 + 1.0);
sumrate_mu = LAYER1 * log2(1 + sinr1) + LAYER2 * log2(1 + sinr2);
sumrate_su = LAYER1 * log2(1 + LAYER1 * sinr_nom1) + LAYER2 * log2(1 + LAYER2 * sinr_nom2);
gain       = sumrate_mu / sumrate_su;

% =========================================================================
% NHẬN XÉT
% =========================================================================
if cd_score >= 0.8
    ortho_str = 'Truc giao tot';
elseif cd_score >= 0.5
    ortho_str = 'Trung binh';
else
    ortho_str = 'Nhieu cao';
end

if gain >= 0.95
    mu_str = 'Nen dung MU-MIMO';
elseif gain >= 0.7
    mu_str = 'MU-MIMO chap nhan duoc';
else
    mu_str = 'Nen dung SU-MIMO';
end

% =========================================================================
% IN KẾT QUẢ
% =========================================================================
fprintf('============================================================\n');
fprintf('  KET QUA PHAN TICH CAP UE\n');
fprintf('============================================================\n');
fprintf('  UE1 : PMI=%4d | Layer=%d | MCS=%2d -> CQI=%2d\n', PMI1, LAYER1, MCS1, cqi1);
fprintf('  UE2 : PMI=%4d | Layer=%d | MCS=%2d -> CQI=%2d\n', PMI2, LAYER2, MCS2, cqi2);
fprintf('------------------------------------------------------------\n');
fprintf('  Chordal Distance  : %.4f  (%s)\n', cd_score, ortho_str);
fprintf('------------------------------------------------------------\n');
fprintf('  SINR nominal UE1  : %.4f  (%.2f dB)\n', sinr_nom1, 10*log10(sinr_nom1));
fprintf('  SINR nominal UE2  : %.4f  (%.2f dB)\n', sinr_nom2, 10*log10(sinr_nom2));
fprintf('  SINR MU UE1       : %.4f  (%.2f dB)\n', sinr1, 10*log10(sinr1));
fprintf('  SINR MU UE2       : %.4f  (%.2f dB)\n', sinr2, 10*log10(sinr2));
fprintf('  SumRate MU-MIMO   : %.4f bps/Hz\n', sumrate_mu);
fprintf('  SumRate SU-MIMO   : %.4f bps/Hz\n', sumrate_su);
fprintf('  Gain MU/SU        : %.4f  (%s)\n', gain, mu_str);
fprintf('============================================================\n');

% =========================================================================
% CHẠY BER
% =========================================================================
SNR_DB  = 20;       % dB — đặt [] để chạy noiseless
RUN_BER = true;

if RUN_BER
    baseConfig1 = buildConfig(LAYER1, MCS1, 20000);
    baseConfig2 = buildConfig(LAYER2, MCS2, 20001);

    if isempty(SNR_DB)
        fprintf('\n[BER] Chay noiseless...\n');
        [BER1, BER2] = muMIMO2UE(baseConfig1, baseConfig2, W1, W2);
    else
        fprintf('\n[BER] Chay voi SNR = %d dB...\n', SNR_DB);
        [BER1, BER2] = muMIMO2UE(baseConfig1, baseConfig2, W1, W2, SNR_DB);
    end

    fprintf('  BER UE1 : %.6f\n', BER1);
    fprintf('  BER UE2 : %.6f\n', BER2);
end


% =========================================================================
% HÀM: buildConfig
% =========================================================================
function cfg = buildConfig(ri, mcs, rnti)
    cfg = struct( ...
        'NLAYERS',                       double(ri), ...
        'MCS',                           double(mcs), ...
        'SUBCARRIER_SPACING',            30, ...
        'NSIZE_GRID',                    273, ...
        'CYCLIC_PREFIX',                 "normal", ...
        'NSLOT',                         0, ...
        'NFRAME',                        0, ...
        'NCELL_ID',                      20, ...
        'DMRS_CONFIGURATION_TYPE',       1, ...
        'DMRS_TYPEA_POSITION',           2, ...
        'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
        'DMRS_LENGTH',                   2, ...
        'DMRS_ADDITIONAL_POSITION',      1, ...
        'PDSCH_MAPPING_TYPE',            'A', ...
        'PDSCH_RNTI',                    rnti, ...
        'PDSCH_PRBSET',                  0:272, ...
        'PDSCH_START_SYMBOL',            0);
end

% =========================================================================
% HÀM: mcsToCqi
% MCS 0–28 → CQI 1–15 theo 3GPP TS 38.214 Table 5.1.3.1-2
% =========================================================================
function cqi = mcsToCqi(mcs)
    % MCS index:  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28
    table = [      1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,15, ...
                   6, 7, 8, 9,10,11,12,13,14,15,15,15,15];
    assert(mcs >= 0 && mcs <= 28, 'MCS phai trong khoang [0, 28]');
    cqi = table(mcs + 1);
end

% =========================================================================
% HÀM: cqiToSinrNominal
% CQI → SINR nominal dùng Shannon inverse từ CQI Table 2
% SINR = 2^efficiency - 1
% Đồng bộ với CQI_TO_SINR trong Python dataset/model
% =========================================================================
function sinr = cqiToSinrNominal(cqi)
    % CQI Table 2 — 3GPP TS 38.214 Table 5.2.2.1-3
    % spectral efficiency (bits/s/Hz)
    eff_table = [0.1523, 0.3770, 0.8770, 1.4766, 1.9141, 2.4063, 2.7305, ...
                 3.3223, 3.9023, 4.5234, 5.1152, 5.5547, 6.2266, 6.9141, 7.4063];
    assert(cqi >= 1 && cqi <= 15, 'CQI phai trong khoang [1, 15]');
    sinr = 2^eff_table(cqi) - 1;
end

% =========================================================================
% HÀM: chordalDistance
% QR + SVD — đồng bộ hoàn toàn với Python chordal_distance()
% dist = sqrt(max(L - sum(sv.^2), 0)) / sqrt(L)
% =========================================================================
function score = chordalDistance(PMI_m, PMI_n)
    assert(size(PMI_m, 1) == size(PMI_n, 1), ...
        'So hang cua 2 ma tran phai bang nhau');
    [Q_m, ~] = qr(PMI_m, 0);
    [Q_n, ~] = qr(PMI_n, 0);
    L        = min(size(PMI_m, 2), size(PMI_n, 2));
    R        = Q_m' * Q_n;
    sv       = svd(R);
    sv       = min(real(sv), 1.0);
    dist     = sqrt(max(L - sum(sv.^2), 0));
    score    = dist / sqrt(L);
end

% =========================================================================
% HÀM: loadPMIFile
% =========================================================================
function W_pool = loadPMIFile(filename, nPort, nLayers)
    fprintf('  Loading: %s...\n', filename);
    fid = fopen(filename, 'r');
    if fid == -1, error('Khong the mo file: %s', filename); end
    W_pool      = zeros(nPort, nLayers, 0);
    pmi_in_file = 0;
    while ~feof(fid)
        info_line = fgetl(fid);
        if ~ischar(info_line), break; end
        if isempty(strtrim(info_line)), continue; end
        pmi_in_file = pmi_in_file + 1;
        W_temp      = zeros(nPort, nLayers);
        for row = 1:nPort
            line_str      = fgetl(fid);
            W_temp(row,:) = str2num(line_str); %#ok<ST2NM>
        end
        W_pool(:, :, pmi_in_file) = W_temp;
    end
    fclose(fid);
    fprintf('    -> Loaded %d matrices.\n', pmi_in_file);
end

% =========================================================================
% Các hàm giữ nguyên từ script gốc
% =========================================================================
function [BER1, BER2] = muMIMO2UE(baseConfig1, baseConfig2, W1, W2, SNR_dB)
    if nargin < 5, SNR_dB = []; end
    nLayers1 = baseConfig1.NLAYERS;
    nLayers2 = baseConfig2.NLAYERS;
    carrier  = nrCarrierConfig;
    carrier.SubcarrierSpacing = baseConfig1.SUBCARRIER_SPACING;
    carrier.NSizeGrid         = baseConfig1.NSIZE_GRID;
    carrier.CyclicPrefix      = baseConfig1.CYCLIC_PREFIX;
    carrier.NSlot             = baseConfig1.NSLOT;
    carrier.NFrame            = baseConfig1.NFRAME;
    carrier.NCellID           = baseConfig1.NCELL_ID;
    pdsch1 = buildPDSCH(baseConfig1, nLayers1, baseConfig1.PDSCH_RNTI, (0:nLayers1-1), 0);
    pdsch2 = buildPDSCH(baseConfig2, nLayers2, baseConfig2.PDSCH_RNTI, (nLayers1:nLayers1+nLayers2-1), 0);
    TBS1       = manualCalculateTBS(pdsch1);
    TBS2       = manualCalculateTBS(pdsch2);
    inputBits1 = ones(TBS1,  1);
    inputBits2 = zeros(TBS2, 1);
    [layerMappedSym1, pdschInd1] = myPDSCHEncode(pdsch1, carrier, inputBits1);
    [layerMappedSym2, pdschInd2] = myPDSCHEncode(pdsch2, carrier, inputBits2);
    dmrsSym1 = genDMRS(carrier, pdsch1); dmrsInd1 = DMRSIndices(pdsch1, carrier);
    dmrsSym2 = genDMRS(carrier, pdsch2); dmrsInd2 = DMRSIndices(pdsch2, carrier);
    nPorts         = size(W1, 1);
    symbolsPerSlot = carrier.SymbolsPerSlot;
    NFFT           = computeNFFT(carrier.SubcarrierSpacing);
    K              = carrier.NSizeGrid * 12;
    layerGrid_UE1  = zeros(K, symbolsPerSlot, nLayers1);
    layerGrid_UE2  = zeros(K, symbolsPerSlot, nLayers2);
    for layer = 1:nLayers1
        layerGrid_UE1(pdschInd1(:,layer)) = layerMappedSym1(:,layer);
        layerGrid_UE1(dmrsInd1(:,layer))  = dmrsSym1(:,layer);
    end
    for layer = 1:nLayers2
        layerGrid_UE2(pdschInd2(:,layer)) = layerMappedSym2(:,layer);
        layerGrid_UE2(dmrsInd2(:,layer))  = dmrsSym2(:,layer);
    end
    layerFlat_UE1 = reshape(layerGrid_UE1, K*symbolsPerSlot, nLayers1);
    layerFlat_UE2 = reshape(layerGrid_UE2, K*symbolsPerSlot, nLayers2);
    portFlat      = layerFlat_UE1 * W1.' + layerFlat_UE2 * W2.';
    portGrid      = reshape(portFlat, K, symbolsPerSlot, nPorts);
    txdataF_ref   = subcarrierMap(portGrid(:,:,1), NFFT);
    txRef         = ofdmModulation(txdataF_ref, NFFT);
    txWaveform    = zeros(length(txRef), nPorts);
    for p = 1:nPorts
        txWaveform(:,p) = ofdmModulation(subcarrierMap(portGrid(:,:,p), NFFT), NFFT);
    end
    if isempty(SNR_dB)
        rxWaveform  = txWaveform;
        noiseVarEst = eps;
    else
        rxWaveform   = awgn(txWaveform, SNR_dB, 'measured');
        signalPower  = mean(abs(txWaveform(:)).^2);
        noiseVarEst  = signalPower / (10^(SNR_dB/10));
    end
    [rxBits1, ~] = rxPDSCHDecode(carrier, pdsch1, rxWaveform, TBS1, NFFT, noiseVarEst);
    [rxBits2, ~] = rxPDSCHDecode(carrier, pdsch2, rxWaveform, TBS2, NFFT, noiseVarEst);
    BER1 = biterr(double(inputBits1), double(rxBits1)) / TBS1;
    BER2 = biterr(double(inputBits2), double(rxBits2)) / TBS2;
end

function pdsch = buildPDSCH(cfg, nLayers, rnti, dmrsPorts, nscid)
    pdsch = customPDSCHConfig();
    pdsch.DMRS.DMRSConfigurationType    = cfg.DMRS_CONFIGURATION_TYPE;
    pdsch.DMRS.DMRSTypeAPosition        = cfg.DMRS_TYPEA_POSITION;
    pdsch.DMRS.NumCDMGroupsWithoutData  = cfg.DMRS_NUMCDMGROUP_WITHOUT_DATA;
    pdsch.DMRS.DMRSLength               = cfg.DMRS_LENGTH;
    pdsch.DMRS.DMRSAdditionalPosition   = cfg.DMRS_ADDITIONAL_POSITION;
    pdsch.NumLayers                     = nLayers;
    pdsch.MappingType                   = cfg.PDSCH_MAPPING_TYPE;
    pdsch.RNTI                          = rnti;
    pdsch.PRBSet                        = cfg.PDSCH_PRBSET;
    pdsch.SymbolAllocation              = [cfg.PDSCH_START_SYMBOL, 14-cfg.PDSCH_START_SYMBOL];
    pdsch                               = pdsch.setMCS(cfg.MCS);
    pdsch.DMRS.DMRSPortSet              = dmrsPorts;
    pdsch.DMRS.NSCID                    = nscid;
end

function [rxBits, eqSymbols, Hest] = rxPDSCHDecode(carrier, pdsch, rxWaveform, TBS, NFFT, noiseVar)
    K              = carrier.NSizeGrid * 12;
    symbolsPerSlot = carrier.SymbolsPerSlot;
    nPorts         = size(rxWaveform, 2);
    nLayers        = pdsch.NumLayers;
    rxGrid         = zeros(K, symbolsPerSlot, nPorts);
    for p = 1:nPorts
        rxdataF_p     = ofdmDemodulation(rxWaveform(:,p), NFFT, K, carrier.SubcarrierSpacing);
        rxGrid(:,:,p) = rxdataF_p(:, 1:symbolsPerSlot);
    end
    pdschInd   = nrPDSCHIndices(carrier, pdsch);
    planeSize  = K * symbolsPerSlot;
    pdschInd2D = pdschInd(:,1);
    if any(pdschInd2D > planeSize)
        pdschInd2D = mod(pdschInd2D - 1, planeSize) + 1;
    end
    nRE     = size(pdschInd, 1);
    pdschRx = zeros(nRE, nPorts);
    for p = 1:nPorts
        grid_p       = rxGrid(:,:,p);
        pdschRx(:,p) = grid_p(pdschInd2D);
    end
    HportLayer = estimateChannelFromDMRS(rxGrid, carrier, pdsch);
    Hest       = repmat(reshape(HportLayer, [1, nPorts, nLayers]), [nRE, 1, 1]);
    eqSymbols  = nrEqualizeMMSE(pdschRx, Hest, noiseVar);
    rxBits     = PDSCHDecode(pdsch, carrier, eqSymbols, TBS, noiseVar);
end

function HportLayer = estimateChannelFromDMRS(rxGrid, carrier, pdsch)
    K              = carrier.NSizeGrid * 12;
    symbolsPerSlot = carrier.SymbolsPerSlot;
    planeSize      = K * symbolsPerSlot;
    nPorts         = size(rxGrid, 3);
    nLayers        = pdsch.NumLayers;
    dmrsInd        = DMRSIndices(pdsch, carrier);
    dmrsTx         = genDMRS(carrier, pdsch);
    HportLayer     = zeros(nPorts, nLayers);
    for l = 1:nLayers
        ind2D = dmrsInd(:,l);
        if any(ind2D > planeSize)
            ind2D = mod(ind2D - 1, planeSize) + 1;
        end
        for p = 1:nPorts
            rxTmp           = rxGrid(:,:,p);
            h_ls            = rxTmp(ind2D) ./ dmrsTx(:,l);
            HportLayer(p,l) = mean(h_ls);
        end
    end
end

function rxdataF = ofdmDemodulation(rxdata, NFFT, K, SCS)
    mu          = log2(SCS / 15);
    cp_samples0 = round(176 * NFFT / 2048);
    cp_samples  = round(144 * NFFT / 2048);
    rxdataF     = zeros(K, 14);
    idx         = 0;
    for i = 1:14
        cp_len    = cp_samples0 * (mod(i-1, 7*2^mu) == 0) + ...
                    cp_samples  * (mod(i-1, 7*2^mu) ~= 0);
        sym_start = idx + cp_len + 1;
        freq_sym  = fft(rxdata(sym_start : sym_start+NFFT-1), NFFT);
        half      = K / 2;
        rxdataF(:,i) = [freq_sym(2:half+1); freq_sym(NFFT-half+1:NFFT)];
        idx = idx + cp_len + NFFT;
    end
end

function txdataF = subcarrierMap(grid_K_T, NFFT)
    [K, nSym] = size(grid_K_T);
    half      = K / 2;
    txdataF   = zeros(NFFT, nSym);
    txdataF(2:half+1,          :) = grid_K_T(1:half,     :);
    txdataF(NFFT-half+1:NFFT, :) = grid_K_T(half+1:end, :);
end

function NFFT = computeNFFT(SCS)
    NFFT = 2048 * SCS / 15;
end