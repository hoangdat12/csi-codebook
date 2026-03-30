clear; clc; close all;

setupPath();

MCS = 27;
nLayers = 2;

% W1 = [
%     0.4000 - 0.1000i   0.6396 + 0.0000i;
%   -0.4000 - 0.1000i   0.2132 + 0.0000i;
%    0.0000 + 0.2828i   0.0000 + 0.1508i;
%   -0.0000 - 0.2828i  -0.0000 - 0.1508i
% ];


% W2 = [
%     -0.1499 + 0.0530i  -0.2512 + 0.0000i;
%    0.1499 + 0.0530i   0.1954 - 0.0000i;
%    0.4240 + 0.2120i   0.3157 + 0.3157i;
%    0.4240 - 0.2120i   0.3157 - 0.3157i
% ];

W1 = [
    0.0139 + 0.1082i   0.4637 + 0.0480i;
   0.1076 + 0.0290i   0.4065 - 0.3399i;
   0.4763 - 0.3621i   0.0420 - 0.0068i;
  -0.3066 + 0.1539i  -0.0066 + 0.0027i
];

W2 = [
    -0.2233 - 0.1306i   0.0027 - 0.0195i;
  -0.0478 - 0.3521i  -0.0042 - 0.0004i;
  -0.0715 - 0.3288i  -0.3514 + 0.0723i;
   0.4122 + 0.1540i   0.2217 + 0.5673i
];


pdsch = customPDSCHConfig;
pdsch.DMRS.DMRSConfigurationType = 1;
pdsch.DMRS.DMRSLength = 2; % <--- THÊM DÒNG NÀY (Double Symbol DMRS)
pdsch.DMRS.DMRSAdditionalPosition = 1;
pdsch.NumLayers = nLayers;
pdsch.PRBSet = 0:272;
pdsch.DMRS.NumCDMGroupsWithoutData = 2;

carrier = nrCarrierConfig;
carrier.SubcarrierSpacing = 30;
% With 273 RB, we need scs 30 
carrier.NSizeGrid = 273;

[BER1, BER2] = muMimo(...
    carrier, pdsch, ...
    W1, W2, MCS, 30 ...
);

disp(BER1);
disp(BER2);

function [BER1, BER2] = muMimo(...
    carrier, basePDSCHConfig, ...
    UE1_W, UE2_W, MCS, SNR_dB ...
)
    
    % -----------------------------------------------------------------
    % UE1 Configuration
    % -----------------------------------------------------------------
    pdsch = basePDSCHConfig; 

    pdsch.DMRS.DMRSPortSet = [0, 1]; 
    pdsch = pdsch.setMCS(MCS);

    [~, pdschInfo] = nrPDSCHIndices(carrier, pdsch);
    NREPerPRB = pdschInfo.NREPerPRB;

    % Get the optimize input length for transmit
    TBS = nrTBS(pdsch.Modulation, pdsch.NumLayers, ...
                length(pdsch.PRBSet), NREPerPRB, pdsch.TargetCodeRate);
    inputBits = randi([0 1], TBS, 1);

    % -----------------------------------------------------------------
    % UE2 Configuration
    % -----------------------------------------------------------------
    pdsch2 = pdsch; 
    pdsch2.DMRS.DMRSPortSet = [2, 3]; 
    pdsch2 = pdsch2.setMCS(MCS);

    [~, pdschInfo] = nrPDSCHIndices(carrier, pdsch2);
    NREPerPRB = pdschInfo.NREPerPRB;

    TBS2 = nrTBS(pdsch2.Modulation, pdsch2.NumLayers, ...
                length(pdsch2.PRBSet), NREPerPRB, pdsch2.TargetCodeRate);
    inputBits2 = randi([0 1], TBS2, 1);

    H_composite = [UE1_W.'; UE2_W.'];

    numTx = size(UE1_W, 1);
    W_total_T = getMMSEPrecoder(H_composite, SNR_dB, numTx);

    % Extract W precoding from the Final W after MMSE
    nLayers1 = size(UE1_W, 2);
    W_transposed = W_total_T(1:nLayers1, :);      
    W2_transposed = W_total_T(nLayers1+1:end, :);  

    % W_transposed = UE1_W.';      
    % W2_transposed = UE2_W.';  

    % -----------------------------------------------------------------
    % PDSCH Modulation
    % -----------------------------------------------------------------
    [layerMappedSym, pdschInd] = PDSCHEncode(pdsch, carrier, inputBits);
    [layerMappedSym2, pdschInd2] = PDSCHEncode(pdsch2, carrier, inputBits2);

    % -----------------------------------------------------------------
    % Precoding 
    % -----------------------------------------------------------------
    [antsym, antind] = nrPDSCHPrecode(carrier, layerMappedSym, pdschInd, W_transposed);
    [antsym2, antind2] = nrPDSCHPrecode(carrier, layerMappedSym2, pdschInd2, W2_transposed);

    % -----------------------------------------------------------------
    % DMRS
    % -----------------------------------------------------------------
    dmrsSym = nrPDSCHDMRS(carrier, pdsch);
    dmrsInd = nrPDSCHDMRSIndices(carrier, pdsch);
    [dmrsAntSym, dmrsAntInd] = nrPDSCHPrecode(carrier, dmrsSym, dmrsInd, W_transposed);

    dmrsSym2 = nrPDSCHDMRS(carrier, pdsch2);
    dmrsInd2 = nrPDSCHDMRSIndices(carrier, pdsch2);
    [dmrsAntSym2, dmrsAntInd2] = nrPDSCHPrecode(carrier, dmrsSym2, dmrsInd2, W2_transposed);

    % -----------------------------------------------------------------
    % Resource Mapping
    % -----------------------------------------------------------------
    numPorts = size(W_transposed, 2);

    txGrid = nrResourceGrid(carrier, numPorts); 

    txGrid(antind) = antsym;
    txGrid(dmrsAntInd) = dmrsAntSym;

    txGrid(antind2) = txGrid(antind2) + antsym2;
    txGrid(dmrsAntInd2) = txGrid(dmrsAntInd2) + dmrsAntSym2;

    % OFDM Modulation
    txWaveform = nrOFDMModulate(carrier, txGrid);

    % -----------------------------------------------------------------
    % Channel
    % -----------------------------------------------------------------
    rxWaveformUE1_clean = txWaveform * UE1_W; 
    rxWaveformUE2_clean = txWaveform * UE2_W;

    rxWaveformUE1 = awgn(rxWaveformUE1_clean, SNR_dB, 'measured');
    rxWaveformUE2 = awgn(rxWaveformUE2_clean, SNR_dB, 'measured');

    % -----------------------------------------------------------------
    % RX
    % -----------------------------------------------------------------

    % -----------------------------------------------------------------
    % Extract data for UE1
    % -----------------------------------------------------------------
    % OFDM Demodulation
    rxBits = rxPDSCHDecode(carrier, pdsch, rxWaveformUE1, txWaveform, TBS);

    numErrors = biterr(double(inputBits), double(rxBits));
    BER1 = numErrors / TBS;

    % -----------------------------------------------------------------
    % Extract Data for UE2
    % -----------------------------------------------------------------
    rxBits2 = rxPDSCHDecode(carrier, pdsch2, rxWaveformUE2, txWaveform, TBS2);

    numErrors2 = biterr(double(inputBits2), double(rxBits2));
    BER2 = numErrors2 / TBS2;
end

function rxBits = rxPDSCHDecode(carrier, pdsch, rxWaveform, txWaveform, TBS)
    pdschInd = nrPDSCHIndices(carrier, pdsch);

    dmrsSym = nrPDSCHDMRS(carrier, pdsch);
    dmrsInd = nrPDSCHDMRSIndices(carrier, pdsch);

    % LÝ THUYẾT: Kênh truyền ma trận không có độ trễ lan truyền. 
    % Buộc offset = 0 để tránh nhiễu tương quan làm trượt cửa sổ FFT.
    offset = 0; 

    rxWaveformSync = rxWaveform(1+offset:end, :);

    samplesNeeded = length(txWaveform); 

    if size(rxWaveformSync, 1) < samplesNeeded
        padding = samplesNeeded - size(rxWaveformSync, 1);
        rxWaveformSync = [rxWaveformSync; zeros(padding, size(rxWaveformSync, 2))];
    end

    rxGrid = nrOFDMDemodulate(carrier, rxWaveformSync);
    rxGrid = rxGrid(1:carrier.NSizeGrid*12, 1:carrier.SymbolsPerSlot, :);

    [Hest, nVar] = nrChannelEstimate(carrier, rxGrid, dmrsInd, dmrsSym, ...
    'CDMLengths', pdsch.DMRS.CDMLengths, ...
    'AveragingWindow', [11 1]);

    [pdschRx, pdschHest] = nrExtractResources(pdschInd, rxGrid, Hest);
    eqSymbols = nrEqualizeMMSE(pdschRx, pdschHest, nVar);

    % LÝ THUYẾT: Truyền phương sai nhiễu nVar thực tế từ kênh vào khối giải mã
    rxBits = PDSCHDecode(pdsch, carrier, eqSymbols, TBS, nVar);
end

% -----------------------------------------------------------------
% This function performs the full PDSCH decoding chain
% -----------------------------------------------------------------
function [out, hasError] = PDSCHDecode(pdsch, carrier, eqSymbols, TBS, nVar)

    % -----------------------------------------------------------------
    % DEMODULATION & DESCRAMBLING
    % -----------------------------------------------------------------
    demappedSym_Cell = nrLayerDemap(eqSymbols);
    sym_to_demod = demappedSym_Cell{1}; 

    % LÝ THUYẾT: Sử dụng trực tiếp nVar để tính LLR chuẩn xác
    rawLLR = nrSymbolDemodulate(sym_to_demod, pdsch.Modulation, nVar);

    if isempty(pdsch.NID)
        nid = carrier.NCellID; 
    else
        nid = pdsch.NID(1); 
    end
    
    c_seq_rx = nrPDSCHPRBS(nid, pdsch.RNTI, 0, length(rawLLR));
    descrambledBits = rawLLR .* (1 - 2*double(c_seq_rx));

    % -----------------------------------------------------------------
    % RATE RECOVERY
    % -----------------------------------------------------------------
    rv = 0; 
    raterecovered = nrRateRecoverLDPC(descrambledBits, TBS, pdsch.TargetCodeRate, ...
                                      rv, pdsch.Modulation, pdsch.NumLayers);

    % -----------------------------------------------------------------
    % DECODING CHAIN (LDPC & CRC)
    % -----------------------------------------------------------------
    crcEnc_dummy = zeros(TBS + 24, 1); 
    bgn_rx = baseGraphSelection(crcEnc_dummy, pdsch.TargetCodeRate);

    MAX_ITER = 25;
    [decBits, ~] = nrLDPCDecode(raterecovered, bgn_rx, MAX_ITER, ...
                        'Algorithm', 'Normalized min-sum', ...
                        'ScalingFactor', 0.75);

    [rxPart, ~] = nrCodeBlockDesegmentLDPC(decBits, bgn_rx, TBS + 24);
    [out, hasError] = nrCRCDecode(rxPart, '24A');
end
