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
           'FILE_NAME', '2UE_Combine_PDSCH_Waveform_8P4V');
];    

N1 = 4; N2 = 1; O1 = 4; O2 = 1;

W1 = [
   0.0081 + 0.0134i  -0.0228 + 0.0187i  -0.0283 + 0.0292i   0.3313 + 0.0434i;
   0.0102 - 0.0089i  -0.1025 + 0.2243i   0.0302 - 0.0076i  -0.0580 - 0.2032i;
  -0.0020 - 0.0048i   0.3456 + 0.0419i  -0.0257 + 0.0053i   0.0308 - 0.0179i;
  -0.0042 - 0.0084i  -0.0462 - 0.2432i   0.0368 + 0.0039i  -0.2247 - 0.1333i;
   0.0888 - 0.1581i   0.0540 + 0.0003i   0.2999 + 0.0303i   0.0224 + 0.0696i;
   0.0820 - 0.0608i  -0.0144 - 0.0353i  -0.1850 - 0.1795i   0.0577 - 0.0886i;
  -0.1729 - 0.2489i   0.0000 - 0.0000i   0.0991 + 0.1483i  -0.0819 + 0.0059i;
  -0.2166 + 0.2596i  -0.0352 - 0.0148i  -0.1176 - 0.2058i   0.0302 + 0.0004i
];

W2 = [
    0.0161 + 0.0011i   0.0080 + 0.0026i   0.2460 + 0.0777i  -0.0036 - 0.0824i;
  -0.0060 - 0.0084i  -0.0028 - 0.0027i  -0.1851 - 0.2016i   0.0237 + 0.0155i;
   0.0043 + 0.0018i   0.0054 + 0.0012i   0.0657 + 0.2319i  -0.0533 - 0.0951i;
  -0.0102 - 0.0084i  -0.0052 - 0.0077i  -0.0060 - 0.2230i  -0.0676 + 0.1153i;
   0.3046 + 0.1405i   0.2244 - 0.2018i   0.0159 - 0.0072i   0.2621 + 0.0342i;
  -0.0083 - 0.1608i  -0.1427 - 0.2122i  -0.0127 - 0.0054i  -0.1785 - 0.1437i;
   0.1090 - 0.0182i  -0.1839 - 0.0000i   0.0059 + 0.0031i   0.1184 + 0.1498i;
  -0.2023 - 0.2405i  -0.1515 + 0.1912i  -0.0120 - 0.0043i  -0.0961 - 0.2111i
];

score = PMIPair(W1, W2);
disp(score);
disp(abs(score));

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
    pdsch1.DMRS.DMRSPortSet = 0:3;
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
    pdsch2.RNTI        = ALL_Case(caseIdx).PDSCH_RNTI + 1; 
    pdsch2.PRBSet      = ALL_Case(caseIdx).PDSCH_PRBSET;
    pdsch2.SymbolAllocation = [ALL_Case(caseIdx).PDSCH_START_SYMBOL, 14 - ALL_Case(caseIdx).PDSCH_START_SYMBOL];
    pdsch2 = pdsch2.setMCS(ALL_Case(caseIdx).MCS);

    pdsch2.DMRS.DMRSPortSet = 4:7;
    pdsch2.DMRS.NSCID = 0;

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

    txdata1 = []; 

    % Vòng lặp xử lý IFFT-shift và OFDM Modulation cho từng Port
    for p = 1:numTxPorts
        % 1. Dịch tần số (IFFT shift) và chèn Zero-padding cho Port p
        txDataF_Port = [frameGrid(numRe/2+1:end, :, p); ...
                        zeros(NFFT - numRe, numSymb); ...
                        frameGrid(1:numRe/2, :, p)];
        
        % 2. Điều chế OFDM
        temp_txdata = ofdmModulation(txDataF_Port, NFFT);
        
        % 3. Nối tiếp tín hiệu của Port p vào mảng tổng (ghép theo cột)
        txdata1 = [txdata1, temp_txdata];
    end

    centerFreq = 0;
    nchannel = numTxPorts; 
    nFrame = 5; 
    scs = 30000; % SCS 30kHz
    data_repeat = repmat(txdata1, nFrame, 1); 
    savevsarecordingmulti(ALL_Case(caseIdx).FILE_NAME, data_repeat, NFFT*scs, centerFreq, nchannel);
end
