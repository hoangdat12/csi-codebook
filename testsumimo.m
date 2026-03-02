clear; clc; close all;

setupPath();

% -----------------------------------------------------------------
% Configuration Parameters
% -----------------------------------------------------------------
NLAYERS = 2;
SUBBAND_AMPLITUDE = true;
N1 = 4; N2 = 1; O1 = 4; O2 = 1;
NUMBER_OF_BEAMS = 2;
PHASE_ALPHABET_SIZE = 4;
MCS = 12;

% Currently support 2 or 4 layers
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

% -----------------------------------------------------------------
% Carrier Configuration
% -----------------------------------------------------------------
carrier = nrCarrierConfig;
% Sharetechnote frame structure 
% Table 5.3.2-1 138-101-1
% https://www.etsi.org/deliver/etsi_ts/138100_138199/13810101/17.08.00_60/ts_13810101v170800p.pdf
carrier.SubcarrierSpacing = 30;  
carrier.NSizeGrid = 273;

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
cfg.numLayers = NLAYERS;   

% -----------------------------------------------------------------
% PDSCH Configuration
% -----------------------------------------------------------------
pdsch = customPDSCHConfig(); 

pdsch.CodebookConfig = cfg;
pdsch.DMRS.DMRSConfigurationType = 1;
pdsch.DMRS.DMRSAdditionalPosition = 1;
pdsch.NumLayers = NLAYERS;
% 273 PRB
pdsch.PRBSet = 0:272;

% -----------------------------------------------------------------
% Mesurements
% -----------------------------------------------------------------
% [MCS, PMI] = csiRsMesurements(carrier, channel, csiConfig, csiReport, pdsch, NLAYERS);
% MCS = 

pdsch.Indices.i1 = {i11, i12, i13, i14};
pdsch.Indices.i2 = {i21, i22};

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

W = generateTypeIIPrecoder(pdsch, pdsch.Indices.i1, pdsch.Indices.i2, true)

W_transposed = W.';
[antsym, antind] = nrPDSCHPrecode(carrier, layerMappedSym, pdschInd, W_transposed);
dmrsSym = nrPDSCHDMRS(carrier, pdsch);
dmrsInd = nrPDSCHDMRSIndices(carrier, pdsch);
[dmrsAntSym, dmrsAntInd] = nrPDSCHPrecode(carrier, dmrsSym, dmrsInd, W_transposed);

txGrid = nrResourceGrid(carrier, 2 * cfg.N1 * cfg.N2); 
txGrid(antind) = antsym;
txGrid(dmrsAntInd) = dmrsAntSym;  

[txWaveform, waveformInfo] = nrOFDMModulate(carrier, txGrid);


% -----------------------------------------------------------------
% Channel
% -----------------------------------------------------------------
rxWaveform = txWaveform;

% -----------------------------------------------------------------
% RX and Calculate BER
% -----------------------------------------------------------------
rxBits = rxPDSCHDecode(carrier, pdsch, rxWaveform, txWaveform, TBS);

numErrors = biterr(double(inputBits), double(rxBits));
BER = numErrors / TBS;

fprintf('BER: %.5f. \n', BER);
