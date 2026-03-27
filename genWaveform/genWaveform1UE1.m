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
           'FILE_NAME', 'UE1_PDSCH_Waveform_4P2V');
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
    pdsch = customPDSCHConfig(); 

    pdsch.DMRS.DMRSConfigurationType     = ALL_Case(caseIdx).DMRS_CONFIGURATION_TYPE; 
    pdsch.DMRS.DMRSTypeAPosition         = ALL_Case(caseIdx).DMRS_TYPEA_POSITION; 
    pdsch.DMRS.NumCDMGroupsWithoutData   = ALL_Case(caseIdx).DMRS_NUMCDMGROUP_WITHOUT_DATA;
    pdsch.DMRS.DMRSLength                = ALL_Case(caseIdx).DMRS_LENGTH;
    pdsch.DMRS.DMRSAdditionalPosition    = ALL_Case(caseIdx).DMRS_ADDITIONAL_POSITION; % <--- Ánh xạ trường mới thêm

    pdsch.NumLayers   = ALL_Case(caseIdx).NLAYERS;
    pdsch.MappingType = ALL_Case(caseIdx).PDSCH_MAPPING_TYPE;
    pdsch.RNTI        = ALL_Case(caseIdx).PDSCH_RNTI;
    pdsch.PRBSet      = ALL_Case(caseIdx).PDSCH_PRBSET;
    pdsch.SymbolAllocation = [ALL_Case(caseIdx).PDSCH_START_SYMBOL, 14 - ALL_Case(caseIdx).PDSCH_START_SYMBOL];

    % Table 5.1.3.1-2: MCS index table 2 for PDSCH - 138 214
    % https://www.etsi.org/deliver/etsi_ts/138200_138299/138214/18.06.00_60/ts_138214v180600p.pdf
    % In this code using TABLE 2
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

    cfg = struct();
    cfg.CodebookConfig.N1 = N1;
    cfg.CodebookConfig.N2 = N2;
    cfg.CodebookConfig.O1 = O1;
    cfg.CodebookConfig.O2 = O2;
    cfg.CodebookConfig.nPorts = 2*N1*N2;
    cfg.CodebookConfig.codebookMode = 1;

    W = [
        0.4619 - 0.1633i   0.4444 + 0.0000i;
        -0.4619 - 0.1633i  -0.4444 + 0.0000i;
        -0.0000 - 0.1394i   0.2222 - 0.0556i;
        0.0000 - 0.0239i  -0.2222 - 0.0556i
    ];

    vsa_normalize_matrix(W);

    % =========================================================================
    % 1. PRECODING TRỰC TIẾP TRÊN SYMBOL (Không dùng Grid 3 chiều)
    % =========================================================================
    % layerMappedSym có kích thước [Số REs x nLayers]
    % Phép nhân ma trận này sẽ trả ra kích thước [Số REs x nPorts]
    precodedPdschSym = layerMappedSym * (W.');
    precodedDmrsSym  = dmrsSym * (W.');

    % Lấy index 2D (cột 1) để dùng chung cho mọi Antenna Ports. 
    % (Vị trí RE trên grid 2D là giống nhau đối với mọi port)
    pdschInd_2D = pdschInd(:, 1);
    dmrsInd_2D  = dmrsInd(:, 1);

    % =========================================================================
    % 2. MAPPING TRỰC TIẾP LÊN FRAME GRID THEO TỪNG PORT
    % =========================================================================
    nPorts = size(W, 1);
    K = carrier.NSizeGrid * 12;
    % Khởi tạo Frame Grid 3 chiều chỉ để lưu trữ cuối cùng (K x 280 x 4)
    frameGrid = zeros(K, 280, nPorts); 

    symbolsPerSlot = carrier.SymbolsPerSlot;
    currentSlotIdx = carrier.NSlot; 

    startSym = currentSlotIdx * symbolsPerSlot + 1;
    endSym = (currentSlotIdx + 1) * symbolsPerSlot;

    % Vòng lặp map lên grid 2D của từng Port
    for p = 1:nPorts
        % Tạo slot grid 2D trống cho port hiện tại
        slotGrid2D = zeros(K, symbolsPerSlot);

        % Mapping data và DMRS đã precoded lên grid 2D
        slotGrid2D(pdschInd_2D) = precodedPdschSym(:, p);
        slotGrid2D(dmrsInd_2D)  = precodedDmrsSym(:, p);
        
        % Đưa slot grid 2D này vào đúng vị trí trên Frame tổng
        frameGrid(:, startSym:endSym, p) = slotGrid2D;
    end

    NFFT = 4096; % Kích thước IFFT
    numRe = size(frameGrid, 1); 
    numSymb = size(frameGrid, 2); 

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
end