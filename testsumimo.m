inputLen = 4000;
inputBits = randi([0 1], inputLen, 1); 

nlayers = 2;
SNR_dB = 20;

carrier = nrCarrierConfig;
% Sharetechnote frame structure 
% Table 5.3.2-1 138-101-1
% https://www.etsi.org/deliver/etsi_ts/138100_138199/13810101/17.08.00_60/ts_13810101v170800p.pdf
carrier.SubcarrierSpacing = 15;  
carrier.NSizeGrid = 273;

cfg = struct();
cfg.N1 = 4;
cfg.N2 = 2;
cfg.O1 = 4;
cfg.O2 = 4;
cfg.NumberOfBeams = 4;
cfg.PhaseAlphabetSize = 8;
cfg.SubbandAmplitude = true;
cfg.numLayers = nlayers;

i11 = [2, 1];
i12 = 2;
i13 = [3, 1];
i14 = [4, 6, 5, 0, 2, 3, 1 ; 3, 2, 4, 1, 5, 6, 0];
i21 = [1, 3, 4, 2, 5, 7 ; 2, 0, 5, 1, 4, 6];
i22 = [0, 1, 0, 1, 0 ; 1, 1, 0, 0, 1];

pdsch = customPDSCHConfig(); 

% Table 5.1.3.1-2: MCS index table 2 for PDSCH - 138 214
% https://www.etsi.org/deliver/etsi_ts/138200_138299/138214/18.06.00_60/ts_138214v180600p.pdf
pdsch = pdsch.setMCS(21); 

pdsch.CodebookConfig = cfg;

pdsch.Indices.i1 = {i11, i12, i13, i14};
pdsch.Indices.i2 = {i21, i22};

pdsch.NumLayers = nlayers;
% 273 PRB
pdsch.PRBSet = 0:272;

[layerMappedSym, pdschInd] = PDSCHEncode(pdsch, carrier, inputBits);

W = generateTypeIIPrecoder(pdsch, pdsch.Indices.i1, pdsch.Indices.i2);

W_transposed = W.';

[antsym, antind] = nrPDSCHPrecode(carrier, layerMappedSym, pdschInd, W_transposed);

pdsch.DMRS.DMRSConfigurationType = 1;
pdsch.DMRS.DMRSAdditionalPosition = 1;

dmrsSym = nrPDSCHDMRS(carrier, pdsch);
dmrsInd = nrPDSCHDMRSIndices(carrier, pdsch);

[dmrsAntSym, dmrsAntInd] = nrPDSCHPrecode(carrier, dmrsSym, dmrsInd, W_transposed);

txGrid = nrResourceGrid(carrier, 2 * cfg.N1 * cfg.N2); 
txGrid(antind) = antsym;
txGrid(dmrsAntInd) = dmrsAntSym;  % Map DMRS vào lưới (Dòng này mới)

[txWaveform, waveformInfo] = nrOFDMModulate(carrier, txGrid);


%% ===================== KÊNH TRUYỀN (CHANNEL) =====================
NRxAnt = 2; 
NumTxAnt = size(txWaveform, 2); % 16

H = (randn(NRxAnt, NumTxAnt) + 1j*randn(NRxAnt, NumTxAnt)) / sqrt(2);

rxWaveform_Fading = txWaveform * H.'; 

rxWaveform = awgn(rxWaveform_Fading, SNR_dB, 'measured');

%% RX

rxGrid = nrOFDMDemodulate(carrier, rxWaveform);

refDmrsSym = nrPDSCHDMRS(carrier, pdsch);
refDmrsInd = nrPDSCHDMRSIndices(carrier, pdsch);

[Hest, nVar] = nrChannelEstimate(carrier, rxGrid, refDmrsInd, refDmrsSym);

[pdschRx, pdschHest] = nrExtractResources(pdschInd, rxGrid, Hest);

[eqSymbols, csi] = nrEqualizeMMSE(pdschRx, pdschHest, nVar);

[rxBits, hasError] = PDSCHDecode(pdsch, carrier, eqSymbols, inputBits, SNR_dB);

numErrors = biterr(double(inputBits(:)), double(rxBits(:)));
BER = numErrors / TBS;

disp(BER);


%% Helper

function [out, pdschInd] = PDSCHEncode(pdsch, carrier, inputBits)
    [pdschInd, indinfo] = nrPDSCHIndices(carrier, pdsch);
    G = indinfo.G;  

    crcEncoded = nrCRCEncode(inputBits,'24A');
    bgn = baseGraphSelection(crcEncoded, pdsch.TargetCodeRate);
    cbs = nrCodeBlockSegmentLDPC(crcEncoded, bgn);
    codedcbs = nrLDPCEncode(cbs, bgn);

    rv = 0;
    ratematched = nrRateMatchLDPC(codedcbs, G, rv, pdsch.Modulation, pdsch.NumLayers);

    if isempty(pdsch.NID)
        nid = carrier.NCellID;
    else
        nid = pdsch.NID(1);
    end
    rnti = pdsch.RNTI;

    c = nrPDSCHPRBS(nid, rnti, 0, length(ratematched));
    scrambled = mod(ratematched + c, 2);

    modulated = nrSymbolModulate(scrambled, pdsch.Modulation);

    out = nrLayerMap(modulated, pdsch.NumLayers);    
end

function [out, hasError] = PDSCHDecode(pdsch, carrier, eqSymbols, inputBits, SNR_dB)
    demappedSym_Cell = nrLayerDemap(eqSymbols);
    sym_to_demod = demappedSym_Cell{1}; % Lấy dữ liệu Codeword 0

    noiseVar = 10^(-SNR_dB/10); % Tính phương sai nhiễu
    rawLLR = nrSymbolDemodulate(sym_to_demod, pdsch.Modulation, noiseVar);

    if isempty(pdsch.NID), nid = carrier.NCellID; else, nid = pdsch.NID(1); end
    c_seq_rx = nrPDSCHPRBS(nid, pdsch.RNTI, 0, length(rawLLR));

    descrambledBits = rawLLR .* (1 - 2*double(c_seq_rx));

    TBS = length(inputBits); % Lấy kích thước gói tin gốc
    rv = 0; 
    raterecovered = nrRateRecoverLDPC(descrambledBits, TBS, pdsch.TargetCodeRate, ...
                                    rv, pdsch.Modulation, pdsch.NumLayers);

    crcEnc_dummy = zeros(TBS + 24, 1); 
    bgn_rx = baseGraphSelection(crcEnc_dummy, pdsch.TargetCodeRate);

    [decBits, ~] = nrLDPCDecode(raterecovered, bgn_rx, 25);

    [rxPart, ~] = nrCodeBlockDesegmentLDPC(decBits, bgn_rx, TBS + 24);

    [out, hasError] = nrCRCDecode(rxPart, '24A');
end