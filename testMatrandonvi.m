clear; clc; close all;

setupPath();

ALL_Case = [

    struct('desc', 'Case: Reference Comparison', ...
           'NLAYERS', 2, 'MCS', 12, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 1, ... % Code ref total=2 -> AddPos=1
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', 'PDSCH_Waveform_2P2V_MaTranDonVi10'),
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
    pdsch.DMRS.DMRSPortSet               = [0 1];
    pdsch.DMRS.NSCID                     = 0;
    pdsch.DMRS.NIDNSCID                  = ALL_Case(caseIdx).NCELL_ID;


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

    W = [1 0; 0 1];
    W_transposed = W;

    [antsym, antind] = nrPDSCHPrecode(carrier, layerMappedSym, pdschInd, W_transposed);
    
    dataPrecoded = layerMappedSym * W_transposed;

    dmrsSym = genDMRS(carrier, pdsch);
    dmrsInd = DMRSIndices(pdsch, carrier);

    % tdmrsSym = nrPDSCHDMRS(carrier, pdsch);
    % tdmrsInd = nrPDSCHDMRSIndices(carrier, pdsch);

    % errSym = max(abs(dmrsSym - tdmrsSym));
    % disp(errSym);

    % errIndices = max(abs(double(dmrsInd) - double(tdmrsInd)));
    % disp(errIndices);

    [dmrsAntSym, dmrsAntInd] = nrPDSCHPrecode(carrier, dmrsSym, dmrsInd, W_transposed);

    dmrsPrecoded = dmrsSym * W_transposed;

    % Frame Grid
    frameGrid = ResourceGrid(carrier, 2);
    % Slot grid
    txGrid = SlotGrid(carrier, 2); 

    % Mapping on slot 0
    txGrid(antind) = dataPrecoded;
    txGrid(dmrsAntInd) = dmrsPrecoded;  

    symbolsPerSlot = carrier.SymbolsPerSlot;
    currentSlotIdx = carrier.NSlot; 

    startSym = currentSlotIdx * symbolsPerSlot + 1;
    endSym = (currentSlotIdx + 1) * symbolsPerSlot;

    % Extended to all Frame
    frameGrid(:, startSym:endSym, :) = txGrid;

    NFFT = 4096; % Kích thước IFFT
    numRe = size(frameGrid, 1); % Tổng số subcarriers mang dữ liệu (Ví dụ: 273*12 = 3276)
    numSymb = size(frameGrid, 2); % Tổng số symbol trong frameGrid

    numTxPorts = 2;

       txDataF_Port1 = [frameGrid(numRe/2+1:end, :, 1); ...
                    zeros(NFFT - numRe, numSymb); ...
                    frameGrid(1:numRe/2, :, 1)];

       txDataF_Port2 = [frameGrid(numRe/2+1:end, :, 2); ...
                    zeros(NFFT - numRe, numSymb); ...
                    frameGrid(1:numRe/2, :, 2)];
                    
    %    txDataF_Port3 = [frameGrid(numRe/2+1:end, :, 3); ...
    %                 zeros(NFFT - numRe, numSymb); ...
    %                 frameGrid(1:numRe/2, :, 3)];
                    
    %    txDataF_Port4 = [frameGrid(numRe/2+1:end, :, 4); ...
    %                 zeros(NFFT - numRe, numSymb); ...
    %                 frameGrid(1:numRe/2, :, 4)];       

       temp_txdata1 = ofdmModulation(txDataF_Port1, NFFT);
       temp_txdata2 = ofdmModulation(txDataF_Port2, NFFT);
    %    temp_txdata3 = ofdmModulation(txDataF_Port3, NFFT);
    %    temp_txdata4 = ofdmModulation(txDataF_Port4, NFFT);

    %    txdata1 = [temp_txdata1, temp_txdata2, temp_txdata3, temp_txdata4];
    
       txdata1 = [temp_txdata1, temp_txdata2];

    centerFreq = 0;
    nchannel = numTxPorts; 
    nFrame = 5; 
    scs = 30000; % SCS 30kHz
    data_repeat = repmat(txdata1, nFrame, 1); 
    savevsarecordingmulti(ALL_Case(caseIdx).FILE_NAME, data_repeat, NFFT*scs, centerFreq, nchannel);
end