clear; clc; close all;

setupPath();

% -----------------------------------------------------------------
% Requirements Configuration Parameters - CASE 1 Default 
% -----------------------------------------------------------------
% TBS size 
% 14 symbols per slot 
% slot 0 
% 1 layer 
% 1 port 
% 1 frame 
% SCS 30k
% 273 PRB
% Cell ID = 20

% DMRS type 1
% DMRS Length 1
% DMRS Symbol position 2
% DMRS additional position 0

% PDSCH Mapping Type A
% PDSCH Start Symbol 0
% PDSCH Number of Symbol 14
% RNTI = 20000
% Cell ID = 20;
% PDSCH Allocation = 0:272
% Table 2 - MCS 12 - 64QAM
% Target Code Rate 517/1024

NLAYERS = 1;
MCS = 12;

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

