clear; clc; close all;

setupPath();

ALL_Case = [
    % Case 1: Default
    struct('desc', 'Case 1: Default', ...
           'NLAYERS', 4, 'MCS', 4, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 2, 'DMRS_ADDITIONAL_POSITION', 1, ...
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', '2UE_Combine_PDSCH_Waveform_4P4V');
];    

N1 = 2; N2 = 1; O1 = 4; O2 = 1;

W1 = [
   0.2321 - 0.3309i   0.3774 + 0.1391i   0.4134 - 0.0309i   0.1292 - 0.0777i;
   0.0583 + 0.2800i   0.2942 + 0.0220i  -0.1680 + 0.2178i   0.0313 - 0.4716i;
   0.0239 - 0.0324i   0.0125 - 0.0317i   0.0006 - 0.0337i   0.0464 - 0.0228i;
   0.0525 + 0.0216i   0.0068 + 0.0031i   0.0362 + 0.0050i  -0.0274 - 0.0224i
];

W2 = [
    0.0202 + 0.0093i  -0.0009 - 0.0178i   0.0202 + 0.0248i   0.0090 - 0.0318i;
   -0.0079 + 0.0053i  -0.0161 + 0.0100i   0.0170 - 0.0532i   0.0051 + 0.0202i;
    0.4037 - 0.1570i   0.3281 - 0.2936i   0.3908 + 0.0731i   0.2605 - 0.3098i;
    0.2296 - 0.0951i   0.2235 - 0.0743i   0.2924 + 0.0485i   0.2175 - 0.1932i
];


vsa_normalize_matrix(W1, W2);

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
    % 1. PRECODING CHO TỪNG UE (Dùng ma trận W riêng của mỗi UE)
    % =========================================================================
    % UE 1: [Số REs x nLayers] * [nLayers x nPorts] = [Số REs x nPorts]
    precodedPdschSym1 = layerMappedSym1 * (W1.');
    precodedDmrsSym1  = dmrsSym1 * (W1.');

    % UE 2: [Số REs x nLayers] * [nLayers x nPorts] = [Số REs x nPorts]
    precodedPdschSym2 = layerMappedSym2 * (W2.');
    precodedDmrsSym2  = dmrsSym2 * (W2.');

    % Lấy index 2D (Chỉ lấy cột đầu tiên vì vị trí RE trên grid 2D là giống nhau)
    pdschInd_2D1 = pdschInd1(:, 1);
    dmrsInd_2D1  = dmrsInd1(:, 1);

    pdschInd_2D2 = pdschInd2(:, 1);
    dmrsInd_2D2  = dmrsInd2(:, 1);

    % =========================================================================
    % 2. MAPPING CỘNG DỒN (MU-MIMO SUPERPOSITION) LÊN FRAME GRID
    % =========================================================================
    nPorts = size(W1, 1); % Số lượng antenna ports của gNodeB
    K = carrier.NSizeGrid * 12;
    symbolsPerSlot = carrier.SymbolsPerSlot;
    currentSlotIdx = carrier.NSlot; 

    % Khởi tạo Frame Grid 3 chiều (Tần số x Thời gian x Antennas)
    frameGrid = zeros(K, 280, nPorts); 

    startSym = currentSlotIdx * symbolsPerSlot + 1;
    endSym   = (currentSlotIdx + 1) * symbolsPerSlot;

    % Vòng lặp map lên grid của từng Antenna Port
    for p = 1:nPorts
        % Tạo slot grid 2D trống cho port hiện tại
        slotGrid2D = zeros(K, symbolsPerSlot);

        % --- Mapping UE 1 ---
        slotGrid2D(pdschInd_2D1) = slotGrid2D(pdschInd_2D1) + precodedPdschSym1(:, p);
        slotGrid2D(dmrsInd_2D1)  = slotGrid2D(dmrsInd_2D1)  + precodedDmrsSym1(:, p);
        
        % --- Mapping UE 2 (Cộng dồn lên cùng tài nguyên) ---
        slotGrid2D(pdschInd_2D2) = slotGrid2D(pdschInd_2D2) + precodedPdschSym2(:, p);
        slotGrid2D(dmrsInd_2D2)  = slotGrid2D(dmrsInd_2D2)  + precodedDmrsSym2(:, p);
        
        % Đưa slot grid của port p vào Frame tổng
        frameGrid(:, startSym:endSym, p) = slotGrid2D;
    end

    W1_T = W1.';   % [nLayers1 x nPorts]
    W2_T = W2.';   % [nLayers2 x nPorts]

    % UE1: precode PDSCH + DMRS
    [precodedPdschSym1_toolbox, pdschAntInd1_toolbox] = nrPDSCHPrecode(carrier, layerMappedSym1, pdschInd1, W1_T);
    [precodedDmrsSym1_toolbox,  dmrsAntInd1_toolbox]  = nrPDSCHPrecode(carrier, dmrsSym1,        dmrsInd1,  W1_T);

    % UE2: precode PDSCH + DMRS
    [precodedPdschSym2_toolbox, pdschAntInd2_toolbox] = nrPDSCHPrecode(carrier, layerMappedSym2, pdschInd2, W2_T);
    [precodedDmrsSym2_toolbox,  dmrsAntInd2_toolbox]  = nrPDSCHPrecode(carrier, dmrsSym2,        dmrsInd2,  W2_T);

    NFFT = 4096; % Kích thước IFFT
    numRe = size(frameGrid, 1); % Tổng số subcarriers mang dữ liệu (Ví dụ: 273*12 = 3276)
    numSymb = size(frameGrid, 2); % Tổng số symbol trong frameGrid

    numTxPorts = 4;

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

    centerFreq = 0;
    nchannel = numTxPorts; 
    nFrame = 5; 
    scs = 30000; % SCS 30kHz
    data_repeat = repmat(txdata1, nFrame, 1); 
    savevsarecordingmulti(ALL_Case(caseIdx).FILE_NAME, data_repeat, NFFT*scs, centerFreq, nchannel);

    txWaveform = txdata1;
end
