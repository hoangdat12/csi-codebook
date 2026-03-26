clear; clc; close all;

setupPath();

ALL_Case = [
    % Case 1: Default
    struct('desc', 'Case 1: Default', ...
           'NLAYERS', 2, 'MCS', 27, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 1, ...
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', '2UE_Combine_PDSCH_Waveform_4P2V');
];


W1 = [
     0.4619 - 0.1633i   0.4444 + 0.0000i;
  -0.4619 - 0.1633i  -0.4444 + 0.0000i;
  -0.0000 - 0.1394i   0.2222 - 0.0556i;
   0.0000 - 0.0239i  -0.2222 - 0.0556i
];

W2 = [
   0.2132 - 0.1066i  -0.0845 - 0.0845i;
   0.2132 + 0.1066i  -0.0845 + 0.0845i;
   0.4264 + 0.1066i   0.4781 + 0.0845i;
   0.4264 - 0.1066i   0.4781 - 0.0845i
];


% -----------------------------------------------------------------
% Configuration Parameters
% -----------------------------------------------------------------
for caseIdx = 1:length(ALL_Case)

    % -----------------------------------------------------------------
    % Carrier Configuration
    % -----------------------------------------------------------------
    carrier = nrCarrierConfig;
    carrier.SubcarrierSpacing = ALL_Case(caseIdx).SUBCARRIER_SPACING;
    carrier.NSizeGrid         = ALL_Case(caseIdx).NSIZE_GRID;
    carrier.CyclicPrefix      = ALL_Case(caseIdx).CYCLIC_PREFIX;
    carrier.NSlot             = ALL_Case(caseIdx).NSLOT;
    carrier.NFrame            = ALL_Case(caseIdx).NFRAME;
    carrier.NCellID           = ALL_Case(caseIdx).NCELL_ID;

    % -----------------------------------------------------------------
    % PDSCH Configuration UE1
    % -----------------------------------------------------------------
    pdsch1 = customPDSCHConfig();
    pdsch1.DMRS.DMRSConfigurationType   = ALL_Case(caseIdx).DMRS_CONFIGURATION_TYPE;
    pdsch1.DMRS.DMRSTypeAPosition       = ALL_Case(caseIdx).DMRS_TYPEA_POSITION;
    pdsch1.DMRS.NumCDMGroupsWithoutData = ALL_Case(caseIdx).DMRS_NUMCDMGROUP_WITHOUT_DATA;
    pdsch1.DMRS.DMRSLength              = ALL_Case(caseIdx).DMRS_LENGTH;
    pdsch1.DMRS.DMRSAdditionalPosition  = ALL_Case(caseIdx).DMRS_ADDITIONAL_POSITION;
    pdsch1.NumLayers                    = ALL_Case(caseIdx).NLAYERS;
    pdsch1.MappingType                  = ALL_Case(caseIdx).PDSCH_MAPPING_TYPE;
    pdsch1.RNTI                         = ALL_Case(caseIdx).PDSCH_RNTI;
    pdsch1.PRBSet                       = ALL_Case(caseIdx).PDSCH_PRBSET;
    pdsch1.SymbolAllocation             = [ALL_Case(caseIdx).PDSCH_START_SYMBOL, ...
                                           14 - ALL_Case(caseIdx).PDSCH_START_SYMBOL];
    pdsch1 = pdsch1.setMCS(ALL_Case(caseIdx).MCS);

    % UE1: Port 0,1 - CDM group 0 - NSCID 0
    pdsch1.DMRS.DMRSPortSet = 0:(pdsch1.NumLayers - 1);  % [0, 1]
    pdsch1.DMRS.NSCID       = 0;

    % -----------------------------------------------------------------
    % PDSCH Configuration UE2
    % -----------------------------------------------------------------
    pdsch2 = customPDSCHConfig();
    pdsch2.DMRS.DMRSConfigurationType   = ALL_Case(caseIdx).DMRS_CONFIGURATION_TYPE;
    pdsch2.DMRS.DMRSTypeAPosition       = ALL_Case(caseIdx).DMRS_TYPEA_POSITION;
    pdsch2.DMRS.NumCDMGroupsWithoutData = ALL_Case(caseIdx).DMRS_NUMCDMGROUP_WITHOUT_DATA;
    pdsch2.DMRS.DMRSLength              = ALL_Case(caseIdx).DMRS_LENGTH;
    pdsch2.DMRS.DMRSAdditionalPosition  = ALL_Case(caseIdx).DMRS_ADDITIONAL_POSITION;
    pdsch2.NumLayers                    = ALL_Case(caseIdx).NLAYERS;
    pdsch2.MappingType                  = ALL_Case(caseIdx).PDSCH_MAPPING_TYPE;
    pdsch2.RNTI                         = ALL_Case(caseIdx).PDSCH_RNTI + 1;  % 20001
    pdsch2.PRBSet                       = ALL_Case(caseIdx).PDSCH_PRBSET;
    pdsch2.SymbolAllocation             = [ALL_Case(caseIdx).PDSCH_START_SYMBOL, ...
                                           14 - ALL_Case(caseIdx).PDSCH_START_SYMBOL];
    pdsch2 = pdsch2.setMCS(ALL_Case(caseIdx).MCS);

    % UE2: Port 2,3 - CDM group 1 - NSCID 1
    pdsch2.DMRS.DMRSPortSet = pdsch1.NumLayers:(2*pdsch1.NumLayers - 1);  % [2, 3]
    pdsch2.DMRS.NSCID       = 1;

    % -----------------------------------------------------------------
    % Debug: Kiểm tra DMRS trực giao
    % -----------------------------------------------------------------
    dmrsInd1_check = DMRSIndices(pdsch1, carrier);
    dmrsInd2_check = DMRSIndices(pdsch2, carrier);
    dmrsInd_2D1_check = dmrsInd1_check(:, 1);
    dmrsInd_2D2_check = dmrsInd2_check(:, 1);

    overlap_dmrs = intersect(dmrsInd_2D1_check, dmrsInd_2D2_check);
    fprintf('=== Case %d: %s ===\n', caseIdx, ALL_Case(caseIdx).desc);
    fprintf('DMRS overlap: %d REs\n', length(overlap_dmrs));
    if ~isempty(overlap_dmrs)
        warning('DMRS bi trung! MU-MIMO se bi nhieu. Kiem tra lai DMRSPortSet!');
    else
        fprintf('DMRS truc giao OK!\n');
    end

    % -----------------------------------------------------------------
    % Generate Bits
    % -----------------------------------------------------------------
    TBS1 = manualCalculateTBS(pdsch1);
    TBS2 = manualCalculateTBS(pdsch2);

    inputBits1 = ones(TBS1, 1);
    inputBits2 = zeros(TBS2, 1);

    fprintf('TBS1 = %d bits, TBS2 = %d bits\n', TBS1, TBS2);

    % -----------------------------------------------------------------
    % Modulation: PDSCH + DMRS
    % -----------------------------------------------------------------
    [layerMappedSym1, pdschInd1] = myPDSCHEncode(pdsch1, carrier, inputBits1);
    [layerMappedSym2, pdschInd2] = myPDSCHEncode(pdsch2, carrier, inputBits2);

    dmrsSym1 = genDMRS(carrier, pdsch1);
    dmrsInd1 = DMRSIndices(pdsch1, carrier);

    dmrsSym2 = genDMRS(carrier, pdsch2);
    dmrsInd2 = DMRSIndices(pdsch2, carrier);

    % -----------------------------------------------------------------
    % Precoding
    % W1, W2: [nPorts x nLayers] -> transpose: [nLayers x nPorts]
    % layerMappedSym: [N x nLayers] * [nLayers x nPorts] = [N x nPorts]
    % -----------------------------------------------------------------
    nPorts = size(W1, 1);  % = 4

    precodedPdschSym1 = layerMappedSym1 * (W1.');  % [N x 4]
    precodedDmrsSym1  = dmrsSym1        * (W1.');  % [M x 4]

    precodedPdschSym2 = layerMappedSym2 * (W2.');  % [N x 4]
    precodedDmrsSym2  = dmrsSym2        * (W2.');  % [M x 4]

    % -----------------------------------------------------------------
    % Lấy 2D index (vị trí RE trên grid giống nhau cho tất cả ports)
    % -----------------------------------------------------------------
    pdschInd_2D1 = pdschInd1(:, 1);
    dmrsInd_2D1  = dmrsInd1(:, 1);

    pdschInd_2D2 = pdschInd2(:, 1);
    dmrsInd_2D2  = dmrsInd2(:, 1);

    % -----------------------------------------------------------------
    % Khởi tạo Frame Grid [K x numSymb x nPorts]
    % -----------------------------------------------------------------
    K              = carrier.NSizeGrid * 12;   % 273*12 = 3276
    symbolsPerSlot = carrier.SymbolsPerSlot;   % 14
    numSymbFrame   = 280;                       % 20 slots * 14 symbols
    currentSlotIdx = carrier.NSlot;            % = 0

    frameGrid = zeros(K, numSymbFrame, nPorts);

    startSym = currentSlotIdx * symbolsPerSlot + 1;
    endSym   = (currentSlotIdx + 1) * symbolsPerSlot;

    % -----------------------------------------------------------------
    % MU-MIMO Superposition: map lên grid từng port
    % -----------------------------------------------------------------
    for p = 1:nPorts
        slotGrid2D = zeros(K, symbolsPerSlot);

        % --- UE1: map PDSCH + DMRS cho port p ---
        slotGrid2D(pdschInd_2D1) = slotGrid2D(pdschInd_2D1) + precodedPdschSym1(:, p);
        slotGrid2D(dmrsInd_2D1)  = slotGrid2D(dmrsInd_2D1)  + precodedDmrsSym1(:, p);

        % --- UE2: cộng dồn PDSCH + DMRS cho port p ---
        slotGrid2D(pdschInd_2D2) = slotGrid2D(pdschInd_2D2) + precodedPdschSym2(:, p);
        slotGrid2D(dmrsInd_2D2)  = slotGrid2D(dmrsInd_2D2)  + precodedDmrsSym2(:, p);

        frameGrid(:, startSym:endSym, p) = slotGrid2D;
    end

    % -----------------------------------------------------------------
    % OFDM Modulation: fftshift + IFFT cho từng port
    % -----------------------------------------------------------------
    NFFT    = 4096;
    numRe   = size(frameGrid, 1);   % 3276
    numSymb = size(frameGrid, 2);   % 280

    % fftshift: đưa DC về giữa NFFT
    txDataF_Port1 = [frameGrid(numRe/2+1:end, :, 1); zeros(NFFT-numRe, numSymb); frameGrid(1:numRe/2, :, 1)];
    txDataF_Port2 = [frameGrid(numRe/2+1:end, :, 2); zeros(NFFT-numRe, numSymb); frameGrid(1:numRe/2, :, 2)];
    txDataF_Port3 = [frameGrid(numRe/2+1:end, :, 3); zeros(NFFT-numRe, numSymb); frameGrid(1:numRe/2, :, 3)];
    txDataF_Port4 = [frameGrid(numRe/2+1:end, :, 4); zeros(NFFT-numRe, numSymb); frameGrid(1:numRe/2, :, 4)];

    temp_txdata1 = ofdmModulation(txDataF_Port1, NFFT);
    temp_txdata2 = ofdmModulation(txDataF_Port2, NFFT);
    temp_txdata3 = ofdmModulation(txDataF_Port3, NFFT);
    temp_txdata4 = ofdmModulation(txDataF_Port4, NFFT);

    % Ghép 4 port thành ma trận [numSamples x 4]
    txdata1 = [temp_txdata1, temp_txdata2, temp_txdata3, temp_txdata4];

    % -----------------------------------------------------------------
    % Lưu file VSA
    % -----------------------------------------------------------------
    centerFreq  = 0;
    numTxPorts  = 4;
    nFrame      = 5;
    scs         = 30000;  % 30 kHz

    data_repeat = repmat(txdata1, nFrame, 1);
    savevsarecordingmulti(ALL_Case(caseIdx).FILE_NAME, data_repeat, NFFT*scs, centerFreq, numTxPorts);

    fprintf('Saved: %s\n', ALL_Case(caseIdx).FILE_NAME);
    fprintf('data_repeat size: %d x %d\n', size(data_repeat, 1), size(data_repeat, 2));

    txWaveform = txdata1;
end