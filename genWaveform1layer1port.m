clear; clc; close all;

setupPath();

ALL_Case = [
    % Case 1: Default
    struct('desc', 'Case 1: Default', ...
           'NLAYERS', 1, 'MCS', 12, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 0, ...
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', 'PDSCH_Waveform_1P1V_DEFAULT');
           
    % Case 2: Increase Modulation Type - 256QAM
    struct('desc', 'Case 2: Increase Modulation Type - 256QAM', ...
           'NLAYERS', 1, 'MCS', 22, ... % <--- Thay đổi MCS = 22
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 0, ...
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', 'PDSCH_Waveform_1P1V_256QAM');

    % Case 3: Change PDSCH Allocation - 0:136
    struct('desc', 'Case 3: Change PDSCH Allocation - 0:136', ...
           'NLAYERS', 1, 'MCS', 12, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 0, ...
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:136, 'PDSCH_START_SYMBOL', 0, ... % <--- Thay đổi PRBSET
           'FILE_NAME', 'PDSCH_Waveform_1P1V_HALF_Bandwidth'); 

    % Case 4: Change Slot Index - 5
    struct('desc', 'Case 4: Change Slot Index - 5', ...
           'NLAYERS', 1, 'MCS', 12, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 5, 'NFRAME', 0, 'NCELL_ID', 20, ... % <--- Thay đổi NSLOT = 5
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 0, ...
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', 'PDSCH_Waveform_1P1V_Slot_Index_5'); 

    % Case 5: Change PDSCH Start Symbol - 2
    struct('desc', 'Case 5: Change PDSCH Start Symbol - 2', ...
           'NLAYERS', 1, 'MCS', 12, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 0, ...
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 2, ... % <--- Thay đổi Start Symbol = 2
           'FILE_NAME', 'PDSCH_Waveform_1P1V_PDSCH_Start_Sym2'); 
    % Case 6: DMRS Length 2 
    struct('desc', 'Case 6: DMRS Length 2', ...
           'NLAYERS', 1, 'MCS', 12, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 2, 'DMRS_ADDITIONAL_POSITION', 0, ... % <--- Thay đổi DMRS Length = 2
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', 'PDSCH_Waveform_1P1V_DMRS_LENGTH_2'); 

    % Case 7: DMRS additional position 1
    struct('desc', 'Case 7: DMRS additional position 1', ...
           'NLAYERS', 1, 'MCS', 12, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 1, ... % <--- Thay đổi DMRS Additional Pos = 1
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', 'PDSCH_Waveform_1P1V_DMRS_ADD_Position_1'); 

    % Case 8: DMRS Type 2
    struct('desc', 'Case 8: DMRS Type 2', ...
           'NLAYERS', 1, 'MCS', 12, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 2, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ... % <--- Thay đổi DMRS Config Type = 2
           'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 0, ...
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', 'PDSCH_Waveform_1P1V_DMRS_TYPE_2'); 
];            

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
    inputBits = randi([0 1], TBS, 1);

    % -----------------------------------------------------------------
    % PDSCH Modulation
    % -----------------------------------------------------------------
    [layerMappedSym, pdschInd] = PDSCHEncode(pdsch, carrier, inputBits);

    dmrsSym = nrPDSCHDMRS(carrier, pdsch);
    dmrsInd = nrPDSCHDMRSIndices(carrier, pdsch);

    % Frame Grid
    frameGrid = ResourceGrid(carrier, 1);
    % Slot grid
    txGrid = nrResourceGrid(carrier, 1); 

    % Mapping on slot 0
    txGrid(pdschInd) = layerMappedSym;
    txGrid(dmrsInd) = dmrsSym;  

    symbolsPerSlot = carrier.SymbolsPerSlot;
    currentSlotIdx = carrier.NSlot; 

    startSym = currentSlotIdx * symbolsPerSlot + 1;
    endSym = (currentSlotIdx + 1) * symbolsPerSlot;

    % Extended to all Frame
    frameGrid(:, startSym:endSym, :) = txGrid;

    NFFT = 4096; 
    numRe = size(frameGrid, 1);
    numSymb = size(frameGrid, 2); 

    datall = frameGrid(:, :, 1);

    txDataF1 = [datall(numRe/2+1:end, :); ...
                zeros(NFFT - numRe, numSymb); ...
                datall(1:numRe/2, :)];

%   % Plot data before OFDM
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

% -----------------------------------------------------------------------
% HELPER FUNCTION
% -----------------------------------------------------------------------
function TBS = manualCalculateTBS(pdsch)
    if pdsch.DMRS.DMRSConfigurationType == 1
        dmrsPatern = [0, 2, 4, 6, 8, 10];
    else
        dmrsPatern = [1, 2, 6, 7];
    end

    % The number of dmrs re in the prb
    dmrsRePerPRB = length(dmrsPatern) * pdsch.DMRS.NumCDMGroupsWithoutData;

    % The number of pdsch re in the prb
    pdschReTotalPerPRB = 12 * pdsch.SymbolAllocation(2);

    % The number of pdsch re available for data in the prb
    pdschRePerPRB = pdschReTotalPerPRB - dmrsRePerPRB;

    % The total Re of PDSCH available for data
    numRE = min(156, pdschRePerPRB) * length(pdsch.PRBSet);

    switch pdsch.Modulation
        case 'QPSK',    Qm = 2;
        case '16QAM',   Qm = 4;
        case '64QAM',   Qm = 6;
        case '256QAM',  Qm = 8;
        case '1024QAM', Qm = 10;
        otherwise,      Qm = 2;
    end

    NInfo = numRE * pdsch.TargetCodeRate * Qm * pdsch.NumLayers;

    if NInfo <= 3824
        n = max(3, floor(log2(NInfo)) - 6);
        NInfoPrime = max(24, (2^n) * floor(NInfo / (2^n)));
        tableTBS = [24, 32, 40, 48, 56, 64, 72, 80, 88, 96, 104, 112, 120, ...
                128, 136, 144, 152, 160, 168, 176, 184, 192, 208, 224, 240, ...
                256, 272, 288, 304, 320, 336, 352, 368, 384, 408, 432, 456, ...
                480, 504, 528, 552, 576, 608, 640, 672, 704, 736, 768, 808, ...
                848, 888, 928, 984, 1032, 1064, 1128, 1160, 1192, 1224, 1256, ...
                1288, 1320, 1352, 1416, 1480, 1544, 1608, 1672, 1736, 1800, ...
                1864, 1928, 2024, 2088, 2152, 2216, 2280, 2408, 2472, 2536, ...
                2600, 2664, 2728, 2792, 2856, 2976, 3104, 3240, 3368, 3496, ...
                3624, 3752, 3824];
        validTBS = tableTBS(tableTBS >= NInfoPrime);

        TBS = validTBS(1);
    else
        n = floor(log2(NInfo - 24)) - 5;

        round_val = floor((NInfo - 24) / (2^n) + 0.5);
        NInfoPrime = max(3840, (2^n) * round_val);

        if pdsch.TargetCodeRate <= 1/4
            C = ceil((NInfoPrime + 24) / 3816);
            TBS = 8 * C * ceil((NInfoPrime + 24) / (8 * C)) - 24;
        else
            if NInfoPrime > 8424
                C = ceil((NInfoPrime + 24) / 8424);
                TBS = 8 * C * ceil((NInfoPrime + 24) / (8 * C)) - 24;
            else
                TBS = 8 * ceil((NInfoPrime + 24) / 8) - 24;
            end
        end
    end
end
