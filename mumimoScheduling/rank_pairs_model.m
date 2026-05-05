clear; clc; close all;
setupPath();

fprintf('Import Python inference module...\n');
inf_mod = py.importlib.import_module('mu_mimo_inference');
fprintf('Done.\n\n');

% =========================================================================
% CẤU HÌNH
% =========================================================================
N_PAIRS        = 5000;
TOP_N          = 50;
BER_TOP_N      = 10;        % số cặp top/bottom đem chạy BER
SNR_DB         = 20;        % dB — đặt [] để noiseless
MAX_TOTAL_RANK = 7;
CQI_MAX_DELTA  = 4;
rng('shuffle');

CQI_SNR_TABLE = [-6.7, -4.7, -2.3, 0.2, 2.4, 4.3, 5.9, 8.1, ...
                  10.3, 11.7, 14.1, 16.3, 18.7, 21.0, 22.7];

% =========================================================================
% NẠP CODEBOOK
% =========================================================================
fprintf('Nap codebook...\n');
codebook{1} = loadPMIFile('Layer1_Port32_N1_4_N2-4_c1.txt', 32, 1);
codebook{2} = loadPMIFile('Layer2_Port32_N1_4_N2-4_c1.txt', 32, 2);
codebook{3} = loadPMIFile('Layer3_Port32_N1_4_N2-4_c1.txt', 32, 3);
codebook{4} = loadPMIFile('Layer4_Port32_N1_4_N2-4_c1.txt', 32, 4);
for l = 1:4
    fprintf('  Layer %d: %d matrices\n', l, size(codebook{l}, 3));
end
fprintf('\n');

% =========================================================================
% CẶP RI HỢP LỆ
% =========================================================================
valid_ri = [];
for r1 = 1:4
    for r2 = 1:4
        if r1 + r2 <= MAX_TOTAL_RANK
            valid_ri(end+1, :) = [r1, r2]; %#ok<AGROW>
        end
    end
end
n_valid_ri = size(valid_ri, 1);

% =========================================================================
% SINH CẶP + TÍNH GROUND TRUTH
% =========================================================================
fprintf('Sinh %d cap va tinh ground truth...\n', N_PAIRS);

pmi1_arr    = zeros(1, N_PAIRS, 'int32');
ri1_arr     = zeros(1, N_PAIRS, 'int32');
cqi1_arr    = zeros(1, N_PAIRS, 'int32');
pmi2_arr    = zeros(1, N_PAIRS, 'int32');
ri2_arr     = zeros(1, N_PAIRS, 'int32');
cqi2_arr    = zeros(1, N_PAIRS, 'int32');
cd_gt_arr   = zeros(1, N_PAIRS);
gain_gt_arr = zeros(1, N_PAIRS);

for i = 1:N_PAIRS
    ri_idx = randi(n_valid_ri);
    ri1    = valid_ri(ri_idx, 1);
    ri2    = valid_ri(ri_idx, 2);
    pmi1   = randi(size(codebook{ri1}, 3));
    pmi2   = randi(size(codebook{ri2}, 3));
    cqi1   = randi(15);
    delta  = randi(2*CQI_MAX_DELTA+1) - CQI_MAX_DELTA - 1;
    cqi2   = max(1, min(15, cqi1 + delta));

    pmi1_arr(i) = int32(pmi1);
    ri1_arr(i)  = int32(ri1);
    cqi1_arr(i) = int32(cqi1);
    pmi2_arr(i) = int32(pmi2);
    ri2_arr(i)  = int32(ri2);
    cqi2_arr(i) = int32(cqi2);

    W1 = codebook{ri1}(:, :, pmi1);
    W2 = codebook{ri2}(:, :, pmi2);

    cd              = chordalDistance(W1, W2);
    cd_gt_arr(i)    = cd;
    snr1            = 10^(CQI_SNR_TABLE(cqi1) / 10);
    snr2            = 10^(CQI_SNR_TABLE(cqi2) / 10);
    iui_on_ue1      = (1-cd) * ri2 * snr2;
    iui_on_ue2      = (1-cd) * ri1 * snr1;
    sinr1           = (ri1*snr1) / (iui_on_ue1 + 1);
    sinr2           = (ri2*snr2) / (iui_on_ue2 + 1);
    sr_mu           = ri1*log2(1+sinr1) + ri2*log2(1+sinr2);
    sr_su           = ri1*log2(1+ri1*snr1) + ri2*log2(1+ri2*snr2);
    gain_gt_arr(i)  = sr_mu / sr_su;
end
fprintf('Hoan thanh ground truth.\n\n');

% =========================================================================
% MODEL INFERENCE
% =========================================================================
fprintf('Chay model inference (%d cap)...\n', N_PAIRS);
py_results = inf_mod.predict_batch( ...
    py.list(num2cell(pmi1_arr)), py.list(num2cell(ri1_arr)),  py.list(num2cell(cqi1_arr)), ...
    py.list(num2cell(pmi2_arr)), py.list(num2cell(ri2_arr)),  py.list(num2cell(cqi2_arr)));
gain_model_arr = double(py.array.array('d', py_results{4}));
fprintf('Inference hoan thanh.\n\n');

% =========================================================================
% METRICS TỔNG QUÁT
% =========================================================================
err     = gain_model_arr - gain_gt_arr;
abs_err = abs(err);
mae     = mean(abs_err);
rmse    = sqrt(mean(err.^2));
pr      = corr(gain_gt_arr', gain_model_arr');
r2      = 1 - sum(err.^2) / sum((gain_gt_arr - mean(gain_gt_arr)).^2);

fprintf('%s\n', repmat('=', 1, 65));
fprintf('  VALIDATION: G_Model vs G_LyThuyet  (%d cap)\n', N_PAIRS);
fprintf('%s\n', repmat('=', 1, 65));
fprintf('  MAE             : %.6f\n', mae);
fprintf('  RMSE            : %.6f\n', rmse);
fprintf('  Pearson r       : %.6f\n', pr);
fprintf('  R-squared       : %.6f\n', r2);
fprintf('  Bias (mean err) : %+.6f\n', mean(err));
fprintf('%s\n\n', repmat('=', 1, 65));

% Phân tích theo dải CD_True
cd_edges  = [0, 0.25, 0.5, 0.75, 0.9, 1.01];
cd_labels = {'[0.00-0.25]','[0.25-0.50]','[0.50-0.75]','[0.75-0.90]','[0.90-1.00]'};
fprintf('  Phan tich theo dai CD_True:\n');
fprintf('  %12s | %6s | %8s | %8s | %8s | %8s\n', ...
    'Dai CD','Count','MAE','Bias','G_LT_avg','G_Mdl_avg');
fprintf('  %s\n', repmat('-', 1, 65));
for b = 1:numel(cd_labels)
    mask = cd_gt_arr >= cd_edges(b) & cd_gt_arr < cd_edges(b+1);
    if ~any(mask), continue; end
    eb = err(mask);
    fprintf('  %12s | %6d | %8.5f | %+8.5f | %8.5f | %8.5f\n', ...
        cd_labels{b}, sum(mask), mean(abs(eb)), mean(eb), ...
        mean(gain_gt_arr(mask)), mean(gain_model_arr(mask)));
end

% Phân tích theo cặp RI
fprintf('\n  Phan tich theo cap (RI_1, RI_2):\n');
fprintf('  %10s | %6s | %8s | %9s\n', '(RI1,RI2)','Count','MAE','Pearson_r');
fprintf('  %s\n', repmat('-', 1, 42));
for row = 1:n_valid_ri
    r1   = valid_ri(row,1);  r2 = valid_ri(row,2);
    mask = (ri1_arr == r1) & (ri2_arr == r2);
    if ~any(mask), continue; end
    gt_s = gain_gt_arr(mask); md_s = gain_model_arr(mask);
    fprintf('  (%2d, %2d)   | %6d | %8.5f | %9.4f\n', ...
        r1, r2, sum(mask), mean(abs(gt_s-md_s)), corr(gt_s', md_s'));
end
fprintf('\n');

% =========================================================================
% HEADER BẢNG
% =========================================================================
hdr = sprintf('%4s | %5s %2s %2s | %5s %2s %2s | %7s | %10s | %10s | %8s', ...
    '#', 'PMI1','R1','Q1','PMI2','R2','Q2', ...
    'CD_True', 'G_LyThuyet', 'G_Model', 'Epsilon');
sep = repmat('-', 1, length(hdr));

% =========================================================================
% BẢNG 1: TOP 50 CD_True CAO NHẤT
% =========================================================================
[~, idx_desc] = sort(cd_gt_arr, 'descend');
fprintf('%s\n', repmat('=', 1, length(hdr)));
fprintf('  BANG 1: TOP %d CD_True CAO NHAT — truc giao tot, it nhieu\n', TOP_N);
fprintf('%s\n', repmat('=', 1, length(hdr)));
fprintf('%s\n', hdr); fprintf('%s\n', sep);
for k = 1:TOP_N
    idx = idx_desc(k);
    printRow(k, pmi1_arr(idx), ri1_arr(idx), cqi1_arr(idx), ...
                pmi2_arr(idx), ri2_arr(idx), cqi2_arr(idx), ...
                cd_gt_arr(idx), gain_gt_arr(idx), gain_model_arr(idx), err(idx));
end
sub = idx_desc(1:TOP_N);
fprintf('%s\n', sep);
fprintf('  Tong ket: avg G_LyThuyet=%.4f | avg G_Model=%.4f | avg |Eps|=%.4f\n', ...
    mean(gain_gt_arr(sub)), mean(gain_model_arr(sub)), mean(abs(err(sub))));

% =========================================================================
% BẢNG 2: TOP 50 CD_True THẤP NHẤT
% =========================================================================
[~, idx_asc] = sort(cd_gt_arr, 'ascend');
fprintf('\n%s\n', repmat('=', 1, length(hdr)));
fprintf('  BANG 2: TOP %d CD_True THAP NHAT — nhieu cao, nen SU-MIMO\n', TOP_N);
fprintf('%s\n', repmat('=', 1, length(hdr)));
fprintf('%s\n', hdr); fprintf('%s\n', sep);
for k = 1:TOP_N
    idx = idx_asc(k);
    printRow(k, pmi1_arr(idx), ri1_arr(idx), cqi1_arr(idx), ...
                pmi2_arr(idx), ri2_arr(idx), cqi2_arr(idx), ...
                cd_gt_arr(idx), gain_gt_arr(idx), gain_model_arr(idx), err(idx));
end
sub = idx_asc(1:TOP_N);
fprintf('%s\n', sep);
fprintf('  Tong ket: avg G_LyThuyet=%.4f | avg G_Model=%.4f | avg |Eps|=%.4f\n', ...
    mean(gain_gt_arr(sub)), mean(gain_model_arr(sub)), mean(abs(err(sub))));

% =========================================================================
% BER: TOP 10 TỐT NHẤT (CD cao nhất)
% =========================================================================
fprintf('\n%s\n', repmat('=', 1, 70));
fprintf('  BER SIMULATION — TOP %d CAP CD CAO NHAT (SNR = %s dB)\n', ...
    BER_TOP_N, num2str(SNR_DB));
fprintf('%s\n', repmat('=', 1, 70));

ber_hdr = sprintf('%4s | %5s %2s %2s | %5s %2s %2s | %7s | %6s | %8s | %8s', ...
    '#', 'PMI1','R1','Q1','PMI2','R2','Q2','CD_True','G_LT','BER_UE1','BER_UE2');
fprintf('%s\n', ber_hdr);
fprintf('%s\n', repmat('-', 1, length(ber_hdr)));

ber1_top = zeros(1, BER_TOP_N);
ber2_top = zeros(1, BER_TOP_N);

for k = 1:BER_TOP_N
    idx  = idx_desc(k);
    ri1  = ri1_arr(idx);   ri2  = ri2_arr(idx);
    pmi1 = pmi1_arr(idx);  pmi2 = pmi2_arr(idx);
    cqi1 = cqi1_arr(idx);  cqi2 = cqi2_arr(idx);

    W1   = codebook{ri1}(:, :, pmi1);
    W2   = codebook{ri2}(:, :, pmi2);

    mcs1 = cqiToMcs(cqi1);
    mcs2 = cqiToMcs(cqi2);

    cfg1 = buildConfig(ri1, mcs1, 20000);
    cfg2 = buildConfig(ri2, mcs2, 20001);

    [b1, b2] = muMIMO2UE(cfg1, cfg2, W1, W2, SNR_DB);
    ber1_top(k) = b1;
    ber2_top(k) = b2;

    fprintf('%4d | %5d %2d %2d | %5d %2d %2d | %7.4f | %6.4f | %8.6f | %8.6f\n', ...
        k, pmi1, ri1, cqi1, pmi2, ri2, cqi2, ...
        cd_gt_arr(idx), gain_gt_arr(idx), b1, b2);
end
fprintf('%s\n', repmat('-', 1, length(ber_hdr)));
fprintf('  Avg BER UE1 (top CD) : %.6f\n', mean(ber1_top));
fprintf('  Avg BER UE2 (top CD) : %.6f\n', mean(ber2_top));
fprintf('  Avg BER tong hop     : %.6f\n', mean([ber1_top, ber2_top]));

% =========================================================================
% BER: TOP 10 TỆ NHẤT (CD thấp nhất)
% =========================================================================
fprintf('\n%s\n', repmat('=', 1, 70));
fprintf('  BER SIMULATION — TOP %d CAP CD THAP NHAT (SNR = %s dB)\n', ...
    BER_TOP_N, num2str(SNR_DB));
fprintf('%s\n', repmat('=', 1, 70));
fprintf('%s\n', ber_hdr);
fprintf('%s\n', repmat('-', 1, length(ber_hdr)));

ber1_bot = zeros(1, BER_TOP_N);
ber2_bot = zeros(1, BER_TOP_N);

for k = 1:BER_TOP_N
    idx  = idx_asc(k);
    ri1  = ri1_arr(idx);   ri2  = ri2_arr(idx);
    pmi1 = pmi1_arr(idx);  pmi2 = pmi2_arr(idx);
    cqi1 = cqi1_arr(idx);  cqi2 = cqi2_arr(idx);

    W1   = codebook{ri1}(:, :, pmi1);
    W2   = codebook{ri2}(:, :, pmi2);

    mcs1 = cqiToMcs(cqi1);
    mcs2 = cqiToMcs(cqi2);

    cfg1 = buildConfig(ri1, mcs1, 20000);
    cfg2 = buildConfig(ri2, mcs2, 20001);

    [b1, b2] = muMIMO2UE(cfg1, cfg2, W1, W2, SNR_DB);
    ber1_bot(k) = b1;
    ber2_bot(k) = b2;

    fprintf('%4d | %5d %2d %2d | %5d %2d %2d | %7.4f | %6.4f | %8.6f | %8.6f\n', ...
        k, pmi1, ri1, cqi1, pmi2, ri2, cqi2, ...
        cd_gt_arr(idx), gain_gt_arr(idx), b1, b2);
end
fprintf('%s\n', repmat('-', 1, length(ber_hdr)));
fprintf('  Avg BER UE1 (bot CD) : %.6f\n', mean(ber1_bot));
fprintf('  Avg BER UE2 (bot CD) : %.6f\n', mean(ber2_bot));
fprintf('  Avg BER tong hop     : %.6f\n', mean([ber1_bot, ber2_bot]));

% =========================================================================
% TỔNG HỢP SO SÁNH
% =========================================================================
fprintf('\n%s\n', repmat('=', 1, 70));
fprintf('  TONG HOP SO SANH BER: CD cao vs CD thap\n');
fprintf('%s\n', repmat('=', 1, 70));
fprintf('  %25s | %10s | %10s\n', '', 'CD Cao (Top)', 'CD Thap (Bot)');
fprintf('  %s\n', repmat('-', 1, 52));
fprintf('  %25s | %10.6f | %10.6f\n', 'Avg BER UE1',  mean(ber1_top), mean(ber1_bot));
fprintf('  %25s | %10.6f | %10.6f\n', 'Avg BER UE2',  mean(ber2_top), mean(ber2_bot));
fprintf('  %25s | %10.6f | %10.6f\n', 'Avg BER (ca 2 UE)', ...
    mean([ber1_top,ber2_top]), mean([ber1_bot,ber2_bot]));
fprintf('  %25s | %10.4f | %10.4f\n', 'Avg CD_True', ...
    mean(cd_gt_arr(idx_desc(1:BER_TOP_N))), mean(cd_gt_arr(idx_asc(1:BER_TOP_N))));
fprintf('  %25s | %10.4f | %10.4f\n', 'Avg G_LyThuyet', ...
    mean(gain_gt_arr(idx_desc(1:BER_TOP_N))), mean(gain_gt_arr(idx_asc(1:BER_TOP_N))));
fprintf('%s\n', repmat('=', 1, 70));
fprintf('  => CD cao → BER thap hơn: xac nhan ly thuyet truc giao\n');
fprintf('  => CD thap → BER cao hon: nhieu cheo giua 2 UE lon\n');
fprintf('%s\n\n', repmat('=', 1, 70));


% =========================================================================
% HÀM NỘI BỘ
% =========================================================================
function printRow(rank, pmi1, ri1, cqi1, pmi2, ri2, cqi2, cd, g_phys, g_model, epsilon)
    fprintf('%4d | %5d %2d %2d | %5d %2d %2d | %7.4f | %10.4f | %10.4f | %+8.4f\n', ...
        rank, pmi1, ri1, cqi1, pmi2, ri2, cqi2, cd, g_phys, g_model, epsilon);
end

function mcs = cqiToMcs(cqi)
    % CQI 1-15 → MCS xấp xỉ (dùng MCS thấp để an toàn)
    table = [1, 2, 4, 6, 8, 11, 13, 16, 18, 21, 23, 25, 27, 27, 27];
    mcs   = table(cqi);
end

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

function W_pool = loadPMIFile(filename, nPort, nLayers)
    fprintf('  Loading: %s...\n', filename);
    fid = fopen(filename, 'r');
    if fid == -1, error('Khong the mo file: %s', filename); end
    W_pool = []; n = 0;
    while ~feof(fid)
        line = fgetl(fid);
        if ~ischar(line) || isempty(strtrim(line)), continue; end
        n = n + 1;
        W = zeros(nPort, nLayers);
        for r = 1:nPort
            W(r,:) = str2num(fgetl(fid)); %#ok<ST2NM>
        end
        W_pool(:,:,n) = W; %#ok<AGROW>
    end
    fclose(fid);
    fprintf('    -> Loaded %d matrices.\n', n);
end

function score = chordalDistance(PMI_m, PMI_n)
    [Q_m, ~] = qr(PMI_m, 0);
    [Q_n, ~] = qr(PMI_n, 0);
    L        = min(size(PMI_m,2), size(PMI_n,2));
    sv       = svd(Q_m' * Q_n);
    sv       = min(real(sv), 1.0);
    score    = sqrt(max(L - sum(sv.^2), 0)) / sqrt(L);
end

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
    TBS1 = manualCalculateTBS(pdsch1); TBS2 = manualCalculateTBS(pdsch2);
    inputBits1 = ones(TBS1,1);         inputBits2 = zeros(TBS2,1);
    [layerMappedSym1, pdschInd1] = myPDSCHEncode(pdsch1, carrier, inputBits1);
    [layerMappedSym2, pdschInd2] = myPDSCHEncode(pdsch2, carrier, inputBits2);
    dmrsSym1 = genDMRS(carrier,pdsch1); dmrsInd1 = DMRSIndices(pdsch1,carrier);
    dmrsSym2 = genDMRS(carrier,pdsch2); dmrsInd2 = DMRSIndices(pdsch2,carrier);
    nPorts = size(W1,1); symbolsPerSlot = carrier.SymbolsPerSlot;
    NFFT = computeNFFT(carrier.SubcarrierSpacing); K = carrier.NSizeGrid*12;
    layerGrid_UE1 = zeros(K,symbolsPerSlot,nLayers1);
    layerGrid_UE2 = zeros(K,symbolsPerSlot,nLayers2);
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
    portFlat = layerFlat_UE1*W1.' + layerFlat_UE2*W2.';
    portGrid = reshape(portFlat, K, symbolsPerSlot, nPorts);
    txRef    = ofdmModulation(subcarrierMap(portGrid(:,:,1),NFFT), NFFT);
    txWaveform = zeros(length(txRef), nPorts);
    for p = 1:nPorts
        txWaveform(:,p) = ofdmModulation(subcarrierMap(portGrid(:,:,p),NFFT), NFFT);
    end
    if isempty(SNR_dB)
        rxWaveform = txWaveform; noiseVarEst = eps;
    else
        rxWaveform  = awgn(txWaveform, SNR_dB, 'measured');
        noiseVarEst = mean(abs(txWaveform(:)).^2) / (10^(SNR_dB/10));
    end
    [rxBits1,~] = rxPDSCHDecode(carrier,pdsch1,rxWaveform,TBS1,NFFT,noiseVarEst);
    [rxBits2,~] = rxPDSCHDecode(carrier,pdsch2,rxWaveform,TBS2,NFFT,noiseVarEst);
    BER1 = biterr(double(inputBits1),double(rxBits1))/TBS1;
    BER2 = biterr(double(inputBits2),double(rxBits2))/TBS2;
end

function pdsch = buildPDSCH(cfg, nLayers, rnti, dmrsPorts, nscid)
    pdsch = customPDSCHConfig();
    pdsch.DMRS.DMRSConfigurationType    = cfg.DMRS_CONFIGURATION_TYPE;
    pdsch.DMRS.DMRSTypeAPosition        = cfg.DMRS_TYPEA_POSITION;
    pdsch.DMRS.NumCDMGroupsWithoutData  = cfg.DMRS_NUMCDMGROUP_WITHOUT_DATA;
    pdsch.DMRS.DMRSLength               = cfg.DMRS_LENGTH;
    pdsch.DMRS.DMRSAdditionalPosition   = cfg.DMRS_ADDITIONAL_POSITION;
    pdsch.NumLayers    = nLayers;
    pdsch.MappingType  = cfg.PDSCH_MAPPING_TYPE;
    pdsch.RNTI         = rnti;
    pdsch.PRBSet       = cfg.PDSCH_PRBSET;
    pdsch.SymbolAllocation = [cfg.PDSCH_START_SYMBOL, 14-cfg.PDSCH_START_SYMBOL];
    pdsch              = pdsch.setMCS(cfg.MCS);
    pdsch.DMRS.DMRSPortSet = dmrsPorts;
    pdsch.DMRS.NSCID   = nscid;
end

function [rxBits, eqSymbols, Hest] = rxPDSCHDecode(carrier, pdsch, rxWaveform, TBS, NFFT, noiseVar)
    K = carrier.NSizeGrid*12; symbolsPerSlot = carrier.SymbolsPerSlot;
    nPorts = size(rxWaveform,2); nLayers = pdsch.NumLayers;
    rxGrid = zeros(K, symbolsPerSlot, nPorts);
    for p = 1:nPorts
        rxdataF_p     = ofdmDemodulation(rxWaveform(:,p), NFFT, K, carrier.SubcarrierSpacing);
        rxGrid(:,:,p) = rxdataF_p(:,1:symbolsPerSlot);
    end
    pdschInd   = nrPDSCHIndices(carrier, pdsch);
    planeSize  = K*symbolsPerSlot;
    pdschInd2D = pdschInd(:,1);
    if any(pdschInd2D > planeSize)
        pdschInd2D = mod(pdschInd2D-1, planeSize)+1;
    end
    nRE = size(pdschInd,1); pdschRx = zeros(nRE, nPorts);
    for p = 1:nPorts
        grid_p = rxGrid(:,:,p); pdschRx(:,p) = grid_p(pdschInd2D);
    end
    HportLayer = estimateChannelFromDMRS(rxGrid, carrier, pdsch);
    Hest       = repmat(reshape(HportLayer,[1,nPorts,nLayers]),[nRE,1,1]);
    eqSymbols  = nrEqualizeMMSE(pdschRx, Hest, noiseVar);
    rxBits     = PDSCHDecode(pdsch, carrier, eqSymbols, TBS, noiseVar);
end

function HportLayer = estimateChannelFromDMRS(rxGrid, carrier, pdsch)
    K = carrier.NSizeGrid*12; symbolsPerSlot = carrier.SymbolsPerSlot;
    planeSize = K*symbolsPerSlot; nPorts = size(rxGrid,3); nLayers = pdsch.NumLayers;
    dmrsInd = DMRSIndices(pdsch,carrier); dmrsTx = genDMRS(carrier,pdsch);
    HportLayer = zeros(nPorts, nLayers);
    for l = 1:nLayers
        ind2D = dmrsInd(:,l);
        if any(ind2D > planeSize), ind2D = mod(ind2D-1,planeSize)+1; end
        for p = 1:nPorts
            rxTmp = rxGrid(:,:,p);
            HportLayer(p,l) = mean(rxTmp(ind2D) ./ dmrsTx(:,l));
        end
    end
end

function rxdataF = ofdmDemodulation(rxdata, NFFT, K, SCS)
    mu = log2(SCS/15); cp0 = round(176*NFFT/2048); cp = round(144*NFFT/2048);
    rxdataF = zeros(K,14); idx = 0;
    for i = 1:14
        cp_len = cp0*(mod(i-1,7*2^mu)==0) + cp*(mod(i-1,7*2^mu)~=0);
        sym_start = idx+cp_len+1;
        freq_sym  = fft(rxdata(sym_start:sym_start+NFFT-1), NFFT);
        half = K/2;
        rxdataF(:,i) = [freq_sym(2:half+1); freq_sym(NFFT-half+1:NFFT)];
        idx = idx+cp_len+NFFT;
    end
end

function txdataF = subcarrierMap(grid_K_T, NFFT)
    [K,nSym] = size(grid_K_T); half = K/2;
    txdataF = zeros(NFFT,nSym);
    txdataF(2:half+1,:)          = grid_K_T(1:half,:);
    txdataF(NFFT-half+1:NFFT,:) = grid_K_T(half+1:end,:);
end

function NFFT = computeNFFT(SCS)
    NFFT = 2048*SCS/15;
end