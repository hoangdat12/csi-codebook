clear; clc; close all;

setupPath();

ALL_Case = [
    % Case 1: Default
    struct('desc', 'Case 1: Default', ...
           'NLAYERS', 2, 'MCS', 12, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 0, ...
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', 'PDSCH_Waveform_8P2V_DEFAULT');
           
    % Case 2: Increase Modulation Type - 256QAM
    struct('desc', 'Case 2: Increase Modulation Type - 256QAM', ...
           'NLAYERS', 2, 'MCS', 22, ... % <--- Thay đổi MCS = 22
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 0, ...
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', 'PDSCH_Waveform_8P2V_256QAM');

    % Case 3: Change PDSCH Allocation - 0:136
    struct('desc', 'Case 3: Change PDSCH Allocation - 0:136', ...
           'NLAYERS', 2, 'MCS', 12, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 0, ...
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:136, 'PDSCH_START_SYMBOL', 0, ... % <--- Thay đổi PRBSET
           'FILE_NAME', 'PDSCH_Waveform_8P2V_HALF_Bandwidth'); 

    % Case 4: Change Slot Index - 5
    struct('desc', 'Case 4: Change Slot Index - 5', ...
           'NLAYERS', 2, 'MCS', 12, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 5, 'NFRAME', 0, 'NCELL_ID', 20, ... % <--- Thay đổi NSLOT = 5
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 0, ...
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', 'PDSCH_Waveform_8P2V_Slot_Index_5'); 

    % Case 5: Change PDSCH Start Symbol - 2
    struct('desc', 'Case 5: Change PDSCH Start Symbol - 2', ...
           'NLAYERS', 2, 'MCS', 12, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 0, ...
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 2, ... % <--- Thay đổi Start Symbol = 2
           'FILE_NAME', 'PDSCH_Waveform_8P2V_PDSCH_Start_Sym2'); 
    % Case 6: DMRS Length 2 
    struct('desc', 'Case 6: DMRS Length 2', ...
           'NLAYERS', 2, 'MCS', 12, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 2, 'DMRS_ADDITIONAL_POSITION', 0, ... % <--- Thay đổi DMRS Length = 2
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', 'PDSCH_Waveform_8P2V_DMRS_LENGTH_2'); 

    % Case 7: DMRS additional position 1
    struct('desc', 'Case 7: DMRS additional position 1', ...
           'NLAYERS', 2, 'MCS', 12, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 1, ... % <--- Thay đổi DMRS Additional Pos = 1
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', 'PDSCH_Waveform_8P2V_DMRS_ADD_Position_1'); 

    % Case 8: DMRS Type 2
    struct('desc', 'Case 8: DMRS Type 2', ...
           'NLAYERS', 2, 'MCS', 12, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 2, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ... % <--- Thay đổi DMRS Config Type = 2
           'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 0, ...
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', 'PDSCH_Waveform_8P2V_DMRS_TYPE_2'); 
];    

% -----------------------------------------------------------------
% Configuration Parameters
% -----------------------------------------------------------------
SUBBAND_AMPLITUDE = true;
N1 = 4; N2 = 1; O1 = 4; O2 = 1;
NUMBER_OF_BEAMS = 2;
PHASE_ALPHABET_SIZE = 4;

% Currently support 2 or 4 beams
if NUMBER_OF_BEAMS == 2
    i11 = [1 0];
    i12 = 3;
    i13 = [0 0];
    i14 = [7,4,2,1; 7,5,6,0];

    i21 = [0,0,0,1; 0,3,0,2];
    i22 = [1,1,1,1; 1,1,1,1];
else
    i11 = [1 1];
    i12 = 3;
    i13 = [0 0];
    i14 = [7,4,2,1,3,0,2,6; 7,5,6,0,1,3,4,0];

    i21 = [0,0,2,1,0,3,1,0; 0,3,0,2,2,1,3,0];
    i22 = [1,1,1,1,1,1,1,1; 1,1,1,1,1,1,1,1];
end

for caseIdx = 1:length(ALL_Case)
    % -----------------------------------------------------------------
    % Codebook Configuration
    % -----------------------------------------------------------------
    cfg = struct();
    cfg.N1 = N1;
    cfg.N2 = N2;
    cfg.O1 = O1;
    cfg.O2 = O2;
    cfg.NumberOfBeams = NUMBER_OF_BEAMS;      
    cfg.PhaseAlphabetSize = PHASE_ALPHABET_SIZE; 
    cfg.SubbandAmplitude = SUBBAND_AMPLITUDE;
    cfg.numLayers = ALL_Case(caseIdx).NLAYERS;   

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

    pdsch.CodebookConfig = cfg;
    
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

    pdsch.Indices.i1 = {i11, i12, i13, i14};
    pdsch.Indices.i2 = {i21, i22};

    % -----------------------------------------------------------------
    % Generate Bits
    % -----------------------------------------------------------------
    [~, pdschInfo] = nrPDSCHIndices(carrier, pdsch);
    NREPerPRB = pdschInfo.NREPerPRB;

    % TBS = nrTBS(pdsch.Modulation, pdsch.NumLayers, ...
    %             length(pdsch.PRBSet), NREPerPRB, pdsch.TargetCodeRate);
    % Manual
    TBS = manualCalculateTBS(pdsch);

    inputBits = randi([0 1], TBS, 1);

    % -----------------------------------------------------------------
    % PDSCH Modulation
    % -----------------------------------------------------------------
    [layerMappedSym, pdschInd] = PDSCHEncode(pdsch, carrier, inputBits);

    W = generateTypeIIPrecoder(pdsch, pdsch.Indices.i1, pdsch.Indices.i2, true);

    W_transposed = W.';
    [antsym, antind] = nrPDSCHPrecode(carrier, layerMappedSym, pdschInd, W_transposed);
    dmrsSym = nrPDSCHDMRS(carrier, pdsch);
    dmrsInd = nrPDSCHDMRSIndices(carrier, pdsch);
    [dmrsAntSym, dmrsAntInd] = nrPDSCHPrecode(carrier, dmrsSym, dmrsInd, W_transposed);

    % Frame Grid
    frameGrid = ResourceGrid(carrier, 2 * cfg.N1 * cfg.N2);
    % Slot grid
    txGrid = nrResourceGrid(carrier, 2 * cfg.N1 * cfg.N2); 

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

    datall = frameGrid(:, :, 8); % 1 Port

    txDataF1 = [datall(numRe/2+1:end, :); ...
                zeros(NFFT - numRe, numSymb); ...
                datall(1:numRe/2, :)];

    % Plot data before OFDM
    figure('Name', ALL_Case(caseIdx).desc, 'NumberTitle', 'off'); 
    
    imagesc(20*log10(abs(txDataF1) + eps)); 
    set(gca, 'YDir', 'normal'); 
    colormap('turbo'); 
    colorbar;

    title(['Dữ liệu trước IFFT (txDataF1) - ', ALL_Case(caseIdx).desc]);
    xlabel('OFDM Symbols (Toàn bộ Frame)');
    ylabel('IFFT Bins (NFFT = 4096)');

    txdata1 = ofdmModulation(txDataF1, NFFT);

    centerFreq = 0;
    nchannel = 1; 
    nFrame = 5; 
    scs = 30000; % SCS 30kHz
    data_repeat = repmat(txdata1, nFrame, 1); 
    savevsarecordingmulti(ALL_Case(caseIdx).FILE_NAME, data_repeat, NFFT*scs, centerFreq, nchannel);
end