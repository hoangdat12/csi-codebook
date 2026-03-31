clear; clc; close all;

setupPath();

ALL_Case = [
    % Case 1: Default
    struct('desc', 'Case 1: Default', ...
           'NLAYERS', 4, 'MCS', 27, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 2, 'DMRS_ADDITIONAL_POSITION', 1, ...
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', '2UE_Combine_PDSCH_Waveform_4P4V');
];    

N1 = 2; N2 = 1; O1 = 4; O2 = 1;

W1 = [
   0.3710 - 0.0340i   0.0450 + 0.0272i   0.0985 + 0.0230i   0.1655 + 0.0793i;
  -0.1082 + 0.2126i   0.0129 + 0.0187i   0.0290 + 0.0075i  -0.3418 + 0.2284i;
   0.0552 + 0.1186i   0.3005 + 0.2939i   0.2809 + 0.2203i  -0.1438 - 0.1576i;
   0.1912 - 0.0241i   0.0280 - 0.2632i  -0.3320 - 0.0352i  -0.0310 - 0.0299i
];

W2 = [
    0.0793 + 0.0142i   0.4330 - 0.0183i  -0.2095 + 0.2583i   0.0121 + 0.0015i;
   0.0213 - 0.0477i   0.1746 + 0.1746i  -0.3238 - 0.1793i  -0.0042 - 0.0017i;
   0.3860 - 0.0244i   0.0310 - 0.0053i   0.0452 + 0.0072i   0.3734 - 0.1611i;
  -0.2402 - 0.1830i   0.0129 + 0.0076i   0.0052 - 0.0166i  -0.2845 - 0.0589i
];

score = PMIPair(W1, W2);

% -----------------------------------------------------------------
% Configuration Parameters
% -----------------------------------------------------------------
for caseIdx = 1:length(ALL_Case)
    % -----------------------------------------------------------------
    % Carrier Configuration
    % -----------------------------------------------------------------
    carrier = nrCarrierConfig;
    
    % Lấy dữ liệu từ struct hiện tại bằng ALL_Case(caseIdx).
    carrier.SubcarrierSpacing = ALL_Case(caseIdx).SUBCARRIER_SPACING;  
    carrier.NSizeGrid         = ALL_Case(caseIdx).NSIZE_GRID;
    carrier.CyclicPrefix      = ALL_Case(caseIdx).CYCLIC_PREFIX;
    carrier.NSlot             = ALL_Case(caseIdx).NSLOT;
    carrier.NFrame            = ALL_Case(caseIdx).NFRAME;
    carrier.NCellID           = ALL_Case(caseIdx).NCELL_ID;

    % -----------------------------------------------------------------
    % PDSCH Configuration
    % -----------------------------------------------------------------
    % =================================================================
    % KHỞI TẠO PDSCH CHO UE 1
    % =================================================================
    pdsch1 = customPDSCHConfig(); 

    pdsch1.DMRS.DMRSConfigurationType   = ALL_Case(caseIdx).DMRS_CONFIGURATION_TYPE; 
    pdsch1.DMRS.DMRSTypeAPosition       = ALL_Case(caseIdx).DMRS_TYPEA_POSITION; 
    pdsch1.DMRS.NumCDMGroupsWithoutData = ALL_Case(caseIdx).DMRS_NUMCDMGROUP_WITHOUT_DATA;
    pdsch1.DMRS.DMRSLength              = ALL_Case(caseIdx).DMRS_LENGTH;
    pdsch1.DMRS.DMRSAdditionalPosition  = ALL_Case(caseIdx).DMRS_ADDITIONAL_POSITION;

    pdsch1.NumLayers   = ALL_Case(caseIdx).NLAYERS;
    pdsch1.MappingType = ALL_Case(caseIdx).PDSCH_MAPPING_TYPE;
    pdsch1.RNTI        = ALL_Case(caseIdx).PDSCH_RNTI;
    pdsch1.PRBSet      = ALL_Case(caseIdx).PDSCH_PRBSET;
    pdsch1.SymbolAllocation = [ALL_Case(caseIdx).PDSCH_START_SYMBOL, 14 - ALL_Case(caseIdx).PDSCH_START_SYMBOL];
    pdsch1 = pdsch1.setMCS(ALL_Case(caseIdx).MCS);

    % Phân bổ DMRS Port và Scrambling ID cho UE 1
    pdsch1.DMRS.DMRSPortSet = 0 : 3;
    pdsch1.DMRS.NSCID = 0;

    % =================================================================
    % KHỞI TẠO PDSCH CHO UE 2
    % =================================================================
    pdsch2 = customPDSCHConfig(); 

    pdsch2.DMRS.DMRSConfigurationType   = ALL_Case(caseIdx).DMRS_CONFIGURATION_TYPE; 
    pdsch2.DMRS.DMRSTypeAPosition       = ALL_Case(caseIdx).DMRS_TYPEA_POSITION; 
    pdsch2.DMRS.NumCDMGroupsWithoutData = ALL_Case(caseIdx).DMRS_NUMCDMGROUP_WITHOUT_DATA;
    pdsch2.DMRS.DMRSLength              = ALL_Case(caseIdx).DMRS_LENGTH;
    pdsch2.DMRS.DMRSAdditionalPosition  = ALL_Case(caseIdx).DMRS_ADDITIONAL_POSITION;

    pdsch2.NumLayers   = ALL_Case(caseIdx).NLAYERS;
    pdsch2.MappingType = ALL_Case(caseIdx).PDSCH_MAPPING_TYPE;
    % Phân tách RNTI để đảm bảo xáo trộn dữ liệu (Scrambling) độc lập
    pdsch2.RNTI        = ALL_Case(caseIdx).PDSCH_RNTI + 1; 
    pdsch2.PRBSet      = ALL_Case(caseIdx).PDSCH_PRBSET;
    pdsch2.SymbolAllocation = [ALL_Case(caseIdx).PDSCH_START_SYMBOL, 14 - ALL_Case(caseIdx).PDSCH_START_SYMBOL];
    pdsch2 = pdsch2.setMCS(ALL_Case(caseIdx).MCS);

    % Phân bổ DMRS Port trực giao và Scrambling ID cho UE 2
    pdsch2.DMRS.DMRSPortSet = 4:7;
    pdsch2.DMRS.NSCID = 1;

    % =================================================================
    % TẠO BITS (GENERATE BITS)
    % =================================================================
    TBS1 = manualCalculateTBS(pdsch1);
    TBS2 = manualCalculateTBS(pdsch2);

    inputBits1 = ones(TBS1, 1);
    inputBits2 = zeros(TBS2, 1);

    % =================================================================
    % ĐIỀU CHẾ PDSCH VÀ DMRS (MODULATION)
    % =================================================================
    [layerMappedSym1, pdschInd1] = myPDSCHEncode(pdsch1, carrier, inputBits1);
    [layerMappedSym2, pdschInd2] = myPDSCHEncode(pdsch2, carrier, inputBits2);

    dmrsSym1 = genDMRS(carrier, pdsch1);
    dmrsInd1 = DMRSIndices(pdsch1, carrier);

    dmrsSym2 = genDMRS(carrier, pdsch2);
    dmrsInd2 = DMRSIndices(pdsch2, carrier);

    % =========================================================================
    % 1. MAPPING LÊN LAYER GRID CHO TỪNG UE (Giữ nguyên cấu trúc CDM Groups)
    % =========================================================================
    nPorts = size(W1, 1); 
    nLayers1 = pdsch1.NumLayers;
    nLayers2 = pdsch2.NumLayers;
    K = carrier.NSizeGrid * 12;
    symbolsPerSlot = carrier.SymbolsPerSlot;
    currentSlotIdx = carrier.NSlot; 

    % Khởi tạo Layer Grid 3D trống cho Slot hiện tại
    layerGrid_UE1 = zeros(K, symbolsPerSlot, nLayers1);
    layerGrid_UE2 = zeros(K, symbolsPerSlot, nLayers2);

    % Map PDSCH và DMRS cho UE 1 (Lặp qua từng layer để không đè REs)
    for layer = 1:nLayers1
        layerGrid_UE1(pdschInd1(:, layer)) = layerMappedSym1(:, layer);
        layerGrid_UE1(dmrsInd1(:, layer))  = dmrsSym1(:, layer);
    end

    % Map PDSCH và DMRS cho UE 2
    for layer = 1:nLayers2
        layerGrid_UE2(pdschInd2(:, layer)) = layerMappedSym2(:, layer);
        layerGrid_UE2(dmrsInd2(:, layer))  = dmrsSym2(:, layer);
    end

    % =========================================================================
    % 2. PRECODING TỪ LAYER GRID SANG PORT GRID
    % =========================================================================
    % Chuyển Layer Grid thành mảng 2D [(K*14) x nLayers] để nhân Precoding matrix
    layerGrid_flat_UE1 = reshape(layerGrid_UE1, K * symbolsPerSlot, nLayers1);
    layerGrid_flat_UE2 = reshape(layerGrid_UE2, K * symbolsPerSlot, nLayers2);

    % Thực hiện Precoding: Port_Data = Layer_Data * W' 
    % Output size: [(K*14) x nPorts]
    portGrid_flat_UE1 = layerGrid_flat_UE1 * (W1.'); 
    portGrid_flat_UE2 = layerGrid_flat_UE2 * (W2.'); 

    % Chuyển về lại kích thước Grid 3 chiều [K x 14 x nPorts]
    portGrid_UE1 = reshape(portGrid_flat_UE1, K, symbolsPerSlot, nPorts);
    portGrid_UE2 = reshape(portGrid_flat_UE2, K, symbolsPerSlot, nPorts);

    % Cộng dồn tín hiệu MU-MIMO (Superposition)
    portGrid_Combined = portGrid_UE1 + portGrid_UE2;

    % =========================================================================
    % 3. ĐƯA VÀO FRAME GRID TỔNG
    % =========================================================================
    % Khởi tạo Frame Grid 3 chiều (Tần số x Thời gian x Antennas)
    frameGrid    = zeros(K, 280, nPorts); 
    frameGridUE1 = zeros(K, 280, nPorts); 
    frameGridUE2 = zeros(K, 280, nPorts); 

    startSym = currentSlotIdx * symbolsPerSlot + 1;
    endSym   = (currentSlotIdx + 1) * symbolsPerSlot;

    % Nhét Slot Port Grid tương ứng vào Frame tổng (Không cần vòng lặp for từng Port nữa)
    frameGrid(:, startSym:endSym, :)    = portGrid_Combined;
    frameGridUE1(:, startSym:endSym, :) = portGrid_UE1;
    frameGridUE2(:, startSym:endSym, :) = portGrid_UE2;

    % =========================================================================
    % 4. THÔNG SỐ OFDM
    % =========================================================================
    NFFT = 4096; % Kích thước IFFT
    numRe = size(frameGrid, 1); % Tổng số subcarriers mang dữ liệu
    numSymb = size(frameGrid, 2); % Tổng số symbol trong frameGrid
    
    numTxPorts = nPorts; % Gán linh hoạt theo nPorts thay vì fix cứng bằng 4

    txDataF_Port1 = [frameGrid(numRe/2+1:end, :, 1); ...
                    zeros(NFFT - numRe, numSymb); ...
                    frameGrid(1:numRe/2, :, 1)];

    txDataF_Port2 = [frameGrid(numRe/2+1:end, :, 2); ...
                    zeros(NFFT - numRe, numSymb); ...
                    frameGrid(1:numRe/2, :, 2)];
                    
    txDataF_Port3 = [frameGrid(numRe/2+1:end, :, 3); ...
                    zeros(NFFT - numRe, numSymb); ...
                    frameGrid(1:numRe/2, :, 3)];
                    
    txDataF_Port4 = [frameGrid(numRe/2+1:end, :, 4); ...
                    zeros(NFFT - numRe, numSymb); ...
                    frameGrid(1:numRe/2, :, 4)];       

    temp_txdata1 = ofdmModulation(txDataF_Port1, NFFT);
    temp_txdata2 = ofdmModulation(txDataF_Port2, NFFT);
    temp_txdata3 = ofdmModulation(txDataF_Port3, NFFT);
    temp_txdata4 = ofdmModulation(txDataF_Port4, NFFT);

    txdata1 = [temp_txdata1, temp_txdata2, temp_txdata3, temp_txdata4];

    % Mu-mimo
    centerFreq = 0;
    nchannel = numTxPorts; 
    nFrame = 5; 
    scs = 30000; % SCS 30kHz
    data_repeat = repmat(txdata1, nFrame, 1); 
    savevsarecordingmulti(ALL_Case(caseIdx).FILE_NAME, data_repeat, NFFT*scs, centerFreq, nchannel);

    % UE1
    txDataF_Port1 = [frameGridUE1(numRe/2+1:end, :, 1); ...
                    zeros(NFFT - numRe, numSymb); ...
                    frameGridUE1(1:numRe/2, :, 1)];

    txDataF_Port2 = [frameGridUE1(numRe/2+1:end, :, 2); ...
                    zeros(NFFT - numRe, numSymb); ...
                    frameGridUE1(1:numRe/2, :, 2)];
                    
    txDataF_Port3 = [frameGridUE1(numRe/2+1:end, :, 3); ...
                    zeros(NFFT - numRe, numSymb); ...
                    frameGridUE1(1:numRe/2, :, 3)];
                    
    txDataF_Port4 = [frameGridUE1(numRe/2+1:end, :, 4); ...
                    zeros(NFFT - numRe, numSymb); ...
                    frameGridUE1(1:numRe/2, :, 4)];       

    temp_txdata1 = ofdmModulation(txDataF_Port1, NFFT);
    temp_txdata2 = ofdmModulation(txDataF_Port2, NFFT);
    temp_txdata3 = ofdmModulation(txDataF_Port3, NFFT);
    temp_txdata4 = ofdmModulation(txDataF_Port4, NFFT);

    txdata1 = [temp_txdata1, temp_txdata2, temp_txdata3, temp_txdata4];

    centerFreq = 0;
    nchannel = numTxPorts; 
    nFrame = 5; 
    scs = 30000; % SCS 30kHz
    data_repeat = repmat(txdata1, nFrame, 1); 
    savevsarecordingmulti("2UE_Combine_PDSCH_Waveform_4P4V_UE1", data_repeat, NFFT*scs, centerFreq, nchannel);

    % UE1
    txDataF_Port1 = [frameGridUE2(numRe/2+1:end, :, 1); ...
                    zeros(NFFT - numRe, numSymb); ...
                    frameGridUE2(1:numRe/2, :, 1)];

    txDataF_Port2 = [frameGridUE2(numRe/2+1:end, :, 2); ...
                    zeros(NFFT - numRe, numSymb); ...
                    frameGridUE2(1:numRe/2, :, 2)];
                    
    txDataF_Port3 = [frameGridUE2(numRe/2+1:end, :, 3); ...
                    zeros(NFFT - numRe, numSymb); ...
                    frameGridUE2(1:numRe/2, :, 3)];
                    
    txDataF_Port4 = [frameGridUE2(numRe/2+1:end, :, 4); ...
                    zeros(NFFT - numRe, numSymb); ...
                    frameGridUE2(1:numRe/2, :, 4)];       

    temp_txdata1 = ofdmModulation(txDataF_Port1, NFFT);
    temp_txdata2 = ofdmModulation(txDataF_Port2, NFFT);
    temp_txdata3 = ofdmModulation(txDataF_Port3, NFFT);
    temp_txdata4 = ofdmModulation(txDataF_Port4, NFFT);

    txdata1 = [temp_txdata1, temp_txdata2, temp_txdata3, temp_txdata4];

    centerFreq = 0;
    nchannel = numTxPorts; 
    nFrame = 5; 
    scs = 30000; % SCS 30kHz
    data_repeat = repmat(txdata1, nFrame, 1); 
    savevsarecordingmulti("2UE_Combine_PDSCH_Waveform_4P4V_UE2", data_repeat, NFFT*scs, centerFreq, nchannel);
end
