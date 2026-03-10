clear; clc; close all;

setupPath();

% -----------------------------------------------------------------
% Requirements Configuration Parameters
% -----------------------------------------------------------------
% TBS size 
% 14 symbols 1 slot 
% slot 0 
% 1 layer 1 port 
% 1 frame 
% DMRS type 1
% PDSCH Mapping Type A
% RNTI = 20000
% Cell ID = 20;

% -----------------------------------------------------------------
% Configuration Parameters
% -----------------------------------------------------------------
NLAYERS = 1;
MCS = 12;

% Codebook Config
SUBBAND_AMPLITUDE = true;
N1 = 1; N2 = 1; O1 = 1; O2 = 1;
NUMBER_OF_BEAMS = 2;
PHASE_ALPHABET_SIZE = 4;

% Carrier Config
SUBCARRIER_SPACING = 30;
NSIZE_GRID = 273;
CYCLIC_PREFIX = "normal"; % 14 symbols
NSLOT = 0;
NFRAME = 0;
NCELL_ID = 20;

% DMRS Config
DMRS_CONFIGURATION_TYPE = 1;  % [0, 2, 4, 6, 10]
DMRS_TYPEA_POSITION = 2; % dmrs at symbol 2
DMRS_NUMCDMGROUP_WITHOUT_DATA = 2;

% PDSCH Config
PDSCH_MAPPING_TYPE = 'A';  % PDSCH Start at 2 or 3
PDSCH_RNTI = 20000;
PDSCH_PRBSET = 0:272;
DMRS_LENGTH = 1;

% -----------------------------------------------------------------
% Carrier Configuration
% -----------------------------------------------------------------
carrier = nrCarrierConfig;
% Sharetechnote frame structure 
% Table 5.3.2-1 138-101-1
% https://www.etsi.org/deliver/etsi_ts/138100_138199/13810101/17.08.00_60/ts_13810101v170800p.pdf
carrier.SubcarrierSpacing = SUBCARRIER_SPACING;  
carrier.NSizeGrid = NSIZE_GRID;
carrier.CyclicPrefix = CYCLIC_PREFIX;
carrier.NSlot = NSLOT;
carrier.NFrame = NFRAME;
carrier.NCellID = NCELL_ID;

% -----------------------------------------------------------------
% PDSCH Configuration
% -----------------------------------------------------------------
pdsch = customPDSCHConfig(); 

pdsch.DMRS.DMRSConfigurationType = DMRS_CONFIGURATION_TYPE; 
pdsch.DMRS.DMRSAdditionalPosition = 0; 
pdsch.DMRS.DMRSTypeAPosition = DMRS_TYPEA_POSITION; 
pdsch.DMRS.NumCDMGroupsWithoutData = DMRS_NUMCDMGROUP_WITHOUT_DATA;
pdsch.DMRS.DMRSLength = DMRS_LENGTH;

pdsch.NumLayers = NLAYERS;
pdsch.MappingType = PDSCH_MAPPING_TYPE;
pdsch.RNTI = PDSCH_RNTI;
% 273 PRB
pdsch.PRBSet = PDSCH_PRBSET;

% Table 5.1.3.1-2: MCS index table 2 for PDSCH - 138 214
% https://www.etsi.org/deliver/etsi_ts/138200_138299/138214/18.06.00_60/ts_138214v180600p.pdf
% In this code using TABLE 2
pdsch = pdsch.setMCS(MCS);

% -----------------------------------------------------------------
% Generate Bits
% -----------------------------------------------------------------
[~, pdschInfo] = nrPDSCHIndices(carrier, pdsch);
NREPerPRB = pdschInfo.NREPerPRB;

% TBS = nrTBS(pdsch.Modulation, pdsch.NumLayers, ...
%             length(pdsch.PRBSet), NREPerPRB, pdsch.TargetCodeRate);
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

NFFT = 4096; % Kích thước IFFT
numRe = size(frameGrid, 1); % Tổng số subcarriers mang dữ liệu (Ví dụ: 273*12 = 3276)
numSymb = size(frameGrid, 2); % Tổng số symbol trong frameGrid

datall = frameGrid(:, :, 1); % 1 Port

txDataF1 = [datall(numRe/2+1:end, :); ...
            zeros(NFFT - numRe, numSymb); ...
            datall(1:numRe/2, :)];

% Plot data before OFDM
pcolor(abs(txDataF1));
shading flat;

figure;
imagesc(20*log10(abs(txDataF1) + eps)); 

set(gca, 'YDir', 'normal'); 

colormap('turbo'); 
colorbar;

title('Dữ liệu trước khối IFFT (txDataF1)');
xlabel('OFDM Symbols (Toàn bộ Frame)');
ylabel('IFFT Bins (NFFT = 4096)');

txdata1 = ofdmModulation(txDataF1, NFFT);

centerFreq = 0;
nchannel = 1; 
nFrame = 5; 
scs = 30000; % SCS 30kHz
data_repeat = repmat(txdata1, nFrame, 1); 
savevsarecordingmulti('PDSCH_Waveform_1P1V.mat', data_repeat, NFFT*scs, centerFreq, nchannel);


% ----------------------------------------------------------------------
% HELPER FUNCTION
% ----------------------------------------------------------------------

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
