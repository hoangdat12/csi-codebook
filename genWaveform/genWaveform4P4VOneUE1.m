clear; clc; close all;

setupPath();

ALL_Case = [
    % Case 1: Default
    struct('desc', 'Case 1: Default', ...
           'NLAYERS', 4, 'MCS', 27, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 1, ...
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', 'CASE2_UE1_PDSCH_Waveform_4P4V');
];    

N1 = 2; N2 = 1; O1 = 4; O2 = 1;

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
    % PDSCH Configuration
    % -----------------------------------------------------------------
    pdsch = customPDSCHConfig(); 

    pdsch.DMRS.DMRSConfigurationType     = ALL_Case(caseIdx).DMRS_CONFIGURATION_TYPE; 
    pdsch.DMRS.DMRSTypeAPosition         = ALL_Case(caseIdx).DMRS_TYPEA_POSITION; 
    pdsch.DMRS.NumCDMGroupsWithoutData   = ALL_Case(caseIdx).DMRS_NUMCDMGROUP_WITHOUT_DATA;
    pdsch.DMRS.DMRSLength                = ALL_Case(caseIdx).DMRS_LENGTH;
    pdsch.DMRS.DMRSAdditionalPosition    = ALL_Case(caseIdx).DMRS_ADDITIONAL_POSITION; 

    pdsch.NumLayers   = ALL_Case(caseIdx).NLAYERS;
    pdsch.MappingType = ALL_Case(caseIdx).PDSCH_MAPPING_TYPE;
    pdsch.RNTI        = ALL_Case(caseIdx).PDSCH_RNTI;
    pdsch.PRBSet      = ALL_Case(caseIdx).PDSCH_PRBSET;
    pdsch.SymbolAllocation = [ALL_Case(caseIdx).PDSCH_START_SYMBOL, 14 - ALL_Case(caseIdx).PDSCH_START_SYMBOL];

    % Table 5.1.3.1-2: MCS index table 2 for PDSCH - 138 214
    pdsch = pdsch.setMCS(ALL_Case(caseIdx).MCS);

    % -----------------------------------------------------------------
    % Generate Bits
    % -----------------------------------------------------------------
    TBS = manualCalculateTBS(pdsch);
    inputBits = ones(TBS, 1);

    % -----------------------------------------------------------------
    % PDSCH Modulation
    % -----------------------------------------------------------------
    [layerMappedSym, pdschInd] = myPDSCHEncode(pdsch, carrier, inputBits);

    dmrsSym = genDMRS(carrier, pdsch);
    dmrsInd = DMRSIndices(pdsch, carrier);

    % Ma trận Precoding (4 Ports x 4 Layers)
    W = [
        0.0202 + 0.0093i  -0.0009 - 0.0178i   0.0202 + 0.0248i   0.0090 - 0.0318i;
       -0.0079 + 0.0053i  -0.0161 + 0.0100i   0.0170 - 0.0532i   0.0051 + 0.0202i;
        0.4037 - 0.1570i   0.3281 - 0.2936i   0.3908 + 0.0731i   0.2605 - 0.3098i;
        0.2296 - 0.0951i   0.2235 - 0.0743i   0.2924 + 0.0485i   0.2175 - 0.1932i
    ];

    % =========================================================================
    % 1. MAPPING LÊN LAYER GRID & 2. PRECODING SANG PORT GRID
    % =========================================================================
    nPorts = size(W, 1);
    nLayers = pdsch.NumLayers;
    K = carrier.NSizeGrid * 12;
    symbolsPerSlot = 14; % Mặc định 14 symbol/slot

    % Khởi tạo Frame Grid 3 chiều để lưu toàn bộ (K x 280 x 4)
    frameGrid = zeros(K, 280, nPorts); 

    currentSlotIdx = carrier.NSlot; 
    startSym = currentSlotIdx * symbolsPerSlot + 1;
    endSym = (currentSlotIdx + 1) * symbolsPerSlot;

    % Khởi tạo Layer Grid trống cho Slot hiện tại
    layerGrid = zeros(K, symbolsPerSlot, nLayers);

    % Đưa Data và DMRS vào đúng vị trí trên Layer Grid
    % (Lặp qua từng layer để tránh lỗi đè REs của các CDM group khác nhau)
    for layer = 1:nLayers
        layerGrid(pdschInd(:, layer)) = layerMappedSym(:, layer);
        layerGrid(dmrsInd(:, layer))  = dmrsSym(:, layer);
    end

    % Chuyển Layer Grid thành mảng 2D [(K*14) x nLayers] để nhân Precoding matrix
    layerGrid_flat = reshape(layerGrid, K * symbolsPerSlot, nLayers);

    % Precoding: Port_Data = Layer_Data * W' 
    % (Output size: [(K*14) x nPorts])
    portGrid_flat = layerGrid_flat * (W.'); 

    % Chuyển về lại kích thước Grid 3 chiều [K x 14 x nPorts]
    portGrid = reshape(portGrid_flat, K, symbolsPerSlot, nPorts);

    % Nhét Slot Port Grid vừa precode xong vào Frame tổng
    frameGrid(:, startSym:endSym, :) = portGrid;

    % =========================================================================
    % 3. OFDM MODULATION
    % =========================================================================
    NFFT = 4096; 
    numRe = size(frameGrid, 1); 
    numSymb = size(frameGrid, 2); 
    numTxPorts = nPorts;

    % Ánh xạ IFFT-shift cho cả 4 port
    txDataF_Port1 = [frameGrid(numRe/2+1:end, :, 1); zeros(NFFT - numRe, numSymb); frameGrid(1:numRe/2, :, 1)];
    txDataF_Port2 = [frameGrid(numRe/2+1:end, :, 2); zeros(NFFT - numRe, numSymb); frameGrid(1:numRe/2, :, 2)];
    txDataF_Port3 = [frameGrid(numRe/2+1:end, :, 3); zeros(NFFT - numRe, numSymb); frameGrid(1:numRe/2, :, 3)];
    txDataF_Port4 = [frameGrid(numRe/2+1:end, :, 4); zeros(NFFT - numRe, numSymb); frameGrid(1:numRe/2, :, 4)];       

    temp_txdata1 = ofdmModulation(txDataF_Port1, NFFT);
    temp_txdata2 = ofdmModulation(txDataF_Port2, NFFT);
    temp_txdata3 = ofdmModulation(txDataF_Port3, NFFT);
    temp_txdata4 = ofdmModulation(txDataF_Port4, NFFT);

    txdata1 = [temp_txdata1, temp_txdata2, temp_txdata3, temp_txdata4];

    centerFreq = 0;
    nchannel = numTxPorts; 
    nFrame = 5; 
    scs = 30000; 
    data_repeat = repmat(txdata1, nFrame, 1); 
    
    savevsarecordingmulti(ALL_Case(caseIdx).FILE_NAME, data_repeat, NFFT*scs, centerFreq, nchannel);
end