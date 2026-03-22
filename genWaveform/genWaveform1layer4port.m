clear; clc; close all;

setupPath();

ALL_Case = [
    % Case 1: Default
    struct('desc', 'Case 1: Default', ...
           'NLAYERS', 2, 'MCS', 12, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 1, ...
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', 'PDSCH_Waveform_4P1V_Matran025');
];


SUBBAND_AMPLITUDE = true;
N1 = 4; N2 = 1; O1 = 4; O2 = 1;
NUMBER_OF_BEAMS = 2;
PHASE_ALPHABET_SIZE = 4;

i11 = [1 0];
i12 = 2;

i13 = [3; 2];

i14 = [2 7 0 3;
       6 1 3 3];

i21 = [1 3 0 0;
       2 2 0 0];

i22 = [1 1 1 1;
       1 1 1 1];

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

    inputBits = ones(TBS, 1);

    % -----------------------------------------------------------------
    % PDSCH Modulation
    % -----------------------------------------------------------------
    [layerMappedSym, pdschInd] = myPDSCHEncode(pdsch, carrier, inputBits);
    dmrsSym = genDMRS(carrier, pdsch);
    dmrsInd = DMRSIndices(pdsch, carrier);
    
    W = generateTypeIIPrecoder(pdsch, pdsch.Indices.i1, pdsch.Indices.i2, true)

    frameGrid = ResourceGrid(carrier, 2 * N1 * N2);

    txGrid = SlotGrid(carrier, 2 * N1 * N2); 

    txGrid(pdschInd) = layerMappedSym;
    txGrid(dmrsInd) = dmrsSym; 
    
    txGridAntennas = precoding(txGrid, W);

    symbolsPerSlot = carrier.SymbolsPerSlot;
    currentSlotIdx = carrier.NSlot; 

    startSym = currentSlotIdx * symbolsPerSlot + 1;
    endSym = (currentSlotIdx + 1) * symbolsPerSlot;

    frameGrid(:, startSym:endSym, :) = txGridAntennas;

    NFFT = 4096; % Kích thước IFFT
    numRe = size(frameGrid, 1); % Tổng số subcarriers mang dữ liệu (Ví dụ: 273*12 = 3276)
    numSymb = size(frameGrid, 2); % Tổng số symbol trong frameGrid

    numTxPorts = 2 * N1 * N2;

    txdata1 = zeros(size(ofdmModulation([frameGrid(numRe/2+1:end, :, 1); zeros(NFFT - numRe, numSymb); frameGrid(1:numRe/2, :, 1)], NFFT), 1), numTxPorts);

    for p = 1:numTxPorts
        txDataF_Port = [frameGrid(numRe/2+1:end, :, p); ...
                        zeros(NFFT - numRe, numSymb); ...
                        frameGrid(1:numRe/2, :, p)];
        txdata1(:, p) = ofdmModulation(txDataF_Port, NFFT);
    end

    centerFreq = 0;
    nchannel = numTxPorts; 
    nFrame = 5; 
    scs = 30000; % SCS 30kHz
    data_repeat = repmat(txdata1, nFrame, 1); 
    savevsarecordingmulti(ALL_Case(caseIdx).FILE_NAME, data_repeat, NFFT*scs, centerFreq, nchannel);
end