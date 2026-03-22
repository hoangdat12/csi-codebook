clear; clc; close all;

setupPath();

ALL_Case = [

    struct('desc', 'Case: Reference Comparison', ...
           'NLAYERS', 1, 'MCS', 12, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 1, ... % Code ref total=2 -> AddPos=1
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', 'PDSCH_Waveform_4P1V_Reference_Compare_TypeI'),

    % % Case 1: Default
    % struct('desc', 'Case 1: Default', ...
    %        'NLAYERS', 1, 'MCS', 12, ...
    %        'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
    %        'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
    %        'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
    %        'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 0, ...
    %        'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
    %        'FILE_NAME', 'PDSCH_Waveform_4P1V_DEFAULT');
           
%     % Case 2: Increase Modulation Type - 256QAM
%     struct('desc', 'Case 2: Increase Modulation Type - 256QAM', ...
%            'NLAYERS', 1, 'MCS', 22, ... % <--- Thay đổi MCS = 22
%            'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
%            'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
%            'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
%            'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 0, ...
%            'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
%            'FILE_NAME', 'PDSCH_Waveform_4P1V_256QAM');

%     % Case 3: Change PDSCH Allocation - 0:136
%     struct('desc', 'Case 3: Change PDSCH Allocation - 0:136', ...
%            'NLAYERS', 1, 'MCS', 12, ...
%            'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
%            'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
%            'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
%            'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 0, ...
%            'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:136, 'PDSCH_START_SYMBOL', 0, ... % <--- Thay đổi PRBSET
%            'FILE_NAME', 'PDSCH_Waveform_4P1V_HALF_Bandwidth'); 

%     % Case 4: Change Slot Index - 5
%     struct('desc', 'Case 4: Change Slot Index - 5', ...
%            'NLAYERS', 1, 'MCS', 12, ...
%            'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
%            'NSLOT', 5, 'NFRAME', 0, 'NCELL_ID', 20, ... % <--- Thay đổi NSLOT = 5
%            'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
%            'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 0, ...
%            'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
%            'FILE_NAME', 'PDSCH_Waveform_4P1V_Slot_Index_5'); 

%     % Case 5: Change PDSCH Start Symbol - 2
%     struct('desc', 'Case 5: Change PDSCH Start Symbol - 2', ...
%            'NLAYERS', 1, 'MCS', 12, ...
%            'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
%            'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
%            'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
%            'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 0, ...
%            'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 2, ... % <--- Thay đổi Start Symbol = 2
%            'FILE_NAME', 'PDSCH_Waveform_4P1V_PDSCH_Start_Sym2'); 
%     % Case 6: DMRS Length 2 
%     struct('desc', 'Case 6: DMRS Length 2', ...
%            'NLAYERS', 1, 'MCS', 12, ...
%            'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
%            'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
%            'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
%            'DMRS_LENGTH', 2, 'DMRS_ADDITIONAL_POSITION', 0, ... % <--- Thay đổi DMRS Length = 2
%            'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
%            'FILE_NAME', 'PDSCH_Waveform_4P1V_DMRS_LENGTH_2'); 

%     % Case 7: DMRS additional position 1
%     struct('desc', 'Case 7: DMRS additional position 1', ...
%            'NLAYERS', 1, 'MCS', 12, ...
%            'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
%            'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
%            'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
%            'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 1, ... % <--- Thay đổi DMRS Additional Pos = 1
%            'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
%            'FILE_NAME', 'PDSCH_Waveform_4P1V_DMRS_ADD_Position_1'); 

%     % Case 8: DMRS Type 2
%     struct('desc', 'Case 8: DMRS Type 2', ...
%            'NLAYERS', 1, 'MCS', 12, ...
%            'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
%            'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
%            'DMRS_CONFIGURATION_TYPE', 2, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ... % <--- Thay đổi DMRS Config Type = 2
%            'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 0, ...
%            'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
%            'FILE_NAME', 'PDSCH_Waveform_4P1V_DMRS_TYPE_2'); 
];    

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
    [~, pdschInfo] = nrPDSCHIndices(carrier, pdsch);
    NREPerPRB = pdschInfo.NREPerPRB;

    % TBS = nrTBS(pdsch.Modulation, pdsch.NumLayers, ...
    %             length(pdsch.PRBSet), NREPerPRB, pdsch.TargetCodeRate);
    % Manual
    TBS = manualCalculateTBS(pdsch);

    inputBits = ones(TBS, 1);

    % -----------------------------------------------------------------
    % PDSCH Modulation
    % -----------------------------------------------------------------
    [layerMappedSym, pdschInd] = myPDSCHEncode(pdsch, carrier, inputBits);

    testConfig = struct();
    testConfig.CodebookConfig.N1 = 2;
    testConfig.CodebookConfig.N2 = 1;
    testConfig.CodebookConfig.O1 = 4;
    testConfig.CodebookConfig.O2 = 1;
    testConfig.CodebookConfig.NumberOfBeams = 2;     % L
    testConfig.CodebookConfig.PhaseAlphabetSize = 4; % NPSK
    testConfig.CodebookConfig.SubbandAmplitude = true;
    testConfig.CodebookConfig.numLayers = 1; % nLayers
    testConfig.CodebookConfig.codebookMode = 1;

    W = getPrecodingMatrixByPMISinglePannel(testConfig, pdsch.NumLayers, 30);
    % W = generateTypeIIPrecoder(pdsch, pdsch.Indices.i1, pdsch.Indices.i2, true);    

    W_transposed = W.';
    [antsym, antind] = nrPDSCHPrecode(carrier, layerMappedSym, pdschInd, W_transposed);

    dmrsSym = genDMRS(carrier, pdsch);
    dmrsInd = DMRSIndices(pdsch, carrier);

    % tdmrsSym = nrPDSCHDMRS(carrier, pdsch);
    % tdmrsInd = nrPDSCHDMRSIndices(carrier, pdsch);

    % errSym = max(abs(dmrsSym - tdmrsSym));
    % disp(errSym);

    % errIndices = max(abs(double(dmrsInd) - double(tdmrsInd)));
    % disp(errIndices);

    [dmrsAntSym, dmrsAntInd] = nrPDSCHPrecode(carrier, dmrsSym, dmrsInd, W_transposed);

    % Frame Grid
    frameGrid = ResourceGrid(carrier, 4);
    % Slot grid
    txGrid = SlotGrid(carrier, 4); 

    % Mapping on slot 0
    txGrid(antind) = antsym;
    txGrid(dmrsAntInd) = dmrsAntSym;  

    symbolsPerSlot = carrier.SymbolsPerSlot;
    currentSlotIdx = carrier.NSlot; 

    startSym = currentSlotIdx * symbolsPerSlot + 1;
    endSym = (currentSlotIdx + 1) * symbolsPerSlot;

    % Extended to all Frame
    frameGrid(:, startSym:endSym, :) = txGrid;

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
end