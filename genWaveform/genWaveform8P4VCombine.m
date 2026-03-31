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

N1 = 4; N2 = 1; O1 = 4; O2 = 1;

W1 = [
   0.0058 - 0.0010i   0.0104 - 0.0129i   0.0037 + 0.0232i   0.0248 - 0.0026i;
  -0.0027 + 0.0031i  -0.0184 - 0.0059i   0.0175 - 0.0337i  -0.0023 - 0.0075i;
   0.0089 - 0.0029i   0.0005 + 0.0108i  -0.0345 + 0.0092i   0.0072 - 0.0123i;
  -0.0083 - 0.0059i  -0.0034 + 0.0023i   0.0191 + 0.0039i  -0.0268 - 0.0064i;
   0.1825 - 0.2778i   0.2527 - 0.1663i   0.2837 - 0.1104i   0.2049 - 0.2693i;
  -0.1582 - 0.0877i  -0.2262 - 0.0013i  -0.2362 - 0.0681i  -0.2117 + 0.0056i;
  -0.0964 - 0.0713i   0.1819 - 0.0000i   0.1614 + 0.0668i   0.0763 - 0.0618i;
  -0.2149 + 0.2144i  -0.2593 - 0.0786i  -0.2152 - 0.1282i  -0.2678 + 0.0874i
];

W2 = [
   0.0850 + 0.2622i   0.1557 + 0.1206i   0.1346 + 0.2693i   0.1804 + 0.2972i;
   0.0351 - 0.0444i  -0.1182 - 0.1444i   0.2057 + 0.0297i   0.1834 - 0.0936i;
   0.0223 + 0.2126i  -0.0485 + 0.2878i   0.1766 - 0.0216i   0.0480 + 0.0379i;
   0.3357 - 0.0759i   0.2888 - 0.0758i   0.1751 - 0.2200i   0.2370 - 0.1616i;
   0.0077 - 0.0026i   0.0297 + 0.0106i   0.0378 + 0.0235i  -0.0068 + 0.0045i;
  -0.0404 - 0.0180i   0.0075 - 0.0210i   0.0221 - 0.0454i  -0.0080 + 0.0014i;
  -0.0178 + 0.0545i  -0.0000 + 0.0000i  -0.0264 - 0.0077i  -0.0048 + 0.0159i;
   0.0367 + 0.0072i   0.0075 - 0.0210i   0.0111 - 0.0080i   0.0144 + 0.0082i
];

score = PMIPair(W1, W2);
disp(score);

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
    pdsch2.DMRS.DMRSPortSet = 0:3;
    pdsch2.DMRS.NSCID = 1;

    % pdsch2.DMRS.DMRSPortSet = 4:7;
    % pdsch2.DMRS.NSCID = 0;

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

    % Mu-mimo
    centerFreq = 0;
    nchannel = numTxPorts; 
    nFrame = 5; 
    scs = 30000; % SCS 30kHz
    data_repeat = repmat(txdata1, nFrame, 1); 
    savevsarecordingmulti(ALL_Case(caseIdx).FILE_NAME, data_repeat, NFFT*scs, centerFreq, nchannel);

    txdata1 = []; 

    % Vòng lặp xử lý IFFT-shift và OFDM Modulation cho từng Port
    for p = 1:numTxPorts
        % 1. Dịch tần số (IFFT shift) và chèn Zero-padding cho Port p
        txDataF_Port = [frameGridUE1(numRe/2+1:end, :, p); ...
                        zeros(NFFT - numRe, numSymb); ...
                        frameGridUE1(1:numRe/2, :, p)];
        
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
    savevsarecordingmulti("2UE_Combine_PDSCH_Waveform_4P4V_UE1", data_repeat, NFFT*scs, centerFreq, nchannel);

    txdata1 = []; 

    % Vòng lặp xử lý IFFT-shift và OFDM Modulation cho từng Port
    for p = 1:numTxPorts
        % 1. Dịch tần số (IFFT shift) và chèn Zero-padding cho Port p
        txDataF_Port = [frameGridUE2(numRe/2+1:end, :, p); ...
                        zeros(NFFT - numRe, numSymb); ...
                        frameGridUE2(1:numRe/2, :, p)];
        
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
    savevsarecordingmulti("2UE_Combine_PDSCH_Waveform_4P4V_UE2", data_repeat, NFFT*scs, centerFreq, nchannel);
end
