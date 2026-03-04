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


% -----------------------------------------------------------------
% Configuration Parameters
% -----------------------------------------------------------------
NLAYERS = 1;
SUBBAND_AMPLITUDE = true;
N1 = 1; N2 = 1; O1 = 1; O2 = 1;
NUMBER_OF_BEAMS = 2;
PHASE_ALPHABET_SIZE = 4;
MCS = 12;

% -----------------------------------------------------------------
% Carrier Configuration
% -----------------------------------------------------------------
carrier = nrCarrierConfig;
% Sharetechnote frame structure 
% Table 5.3.2-1 138-101-1
% https://www.etsi.org/deliver/etsi_ts/138100_138199/13810101/17.08.00_60/ts_13810101v170800p.pdf
carrier.SubcarrierSpacing = 30;  
carrier.NSizeGrid = 273;
carrier.CyclicPrefix = "normal";
carrier.NSlot = 0;
carrier.NFrame = 0;

% -----------------------------------------------------------------
% PDSCH Configuration
% -----------------------------------------------------------------
pdsch = customPDSCHConfig(); 

pdsch.DMRS.DMRSConfigurationType = 1; % [0, 2, 4, 6, 10]
pdsch.DMRS.DMRSAdditionalPosition = 0; % 1 dmrs
pdsch.DMRS.DMRSTypeAPosition = 2; % symbols 2
pdsch.DMRS.NumCDMGroupsWithoutData = 2; % Default
pdsch.NumLayers = NLAYERS;
pdsch.MappingType = 'A'; % PDSCH Start at 2 or 3
% 273 PRB
pdsch.PRBSet = 0:272;

% Table 5.1.3.1-2: MCS index table 2 for PDSCH - 138 214
% https://www.etsi.org/deliver/etsi_ts/138200_138299/138214/18.06.00_60/ts_138214v180600p.pdf
pdsch = pdsch.setMCS(MCS);

% -----------------------------------------------------------------
% Generate Bits
% -----------------------------------------------------------------
[~, pdschInfo] = nrPDSCHIndices(carrier, pdsch);
NREPerPRB = pdschInfo.NREPerPRB;

TBS = nrTBS(pdsch.Modulation, pdsch.NumLayers, ...
            length(pdsch.PRBSet), NREPerPRB, pdsch.TargetCodeRate);

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

[txWaveform, waveformInfo] = nrOFDMModulate(carrier, frameGrid);
save('txWaveform.mat','txWaveform','waveformInfo');
