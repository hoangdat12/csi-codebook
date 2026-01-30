%% 5G NR TYPE II PRECODING LINK-LEVEL SIMULATION
% This script simulates a full 5G NR Transmitter-Channel-Receiver chain 
% using Type II (High-Resolution) Precoding Codebook.

clc; clear; close all;

setupPath();   

% -----------------------------------------------------------
% Transport Block and PDSCH Configuration
% Type II Precoding supports up to nLayers = 2 (v = {1, 2}).
% 273 RB, 14 symbols, 256QAM, 1 slot 14 symbols
% -----------------------------------------------------------
inputLen = 4000;
inputBits = randi([0 1], inputLen, 1); 

nlayers = 2;

carrier = nrCarrierConfig;
% Sharetechnote frame structure 
% Table 5.3.2-1 138-101-1
% https://www.etsi.org/deliver/etsi_ts/138100_138199/13810101/17.08.00_60/ts_13810101v170800p.pdf
carrier.SubcarrierSpacing = 15;  
carrier.NSizeGrid = 273;

cfg = struct();
cfg.N1 = 4;
cfg.N2 = 2;
cfg.O1 = 4;
cfg.O2 = 4;
cfg.NumberOfBeams = 4;
cfg.PhaseAlphabetSize = 8;
cfg.SubbandAmplitude = true;
cfg.numLayers = nlayers;

i11 = [2, 1];
i12 = 2;
i13 = [3, 1];
i14 = [4, 6, 5, 0, 2, 3, 1 ; 3, 2, 4, 1, 5, 6, 0];
i21 = [1, 3, 4, 2, 5, 7 ; 2, 0, 5, 1, 4, 6];
i22 = [0, 1, 0, 1, 0 ; 1, 1, 0, 0, 1];

pdsch = customPDSCHConfig(); 

% Table 5.1.3.1-2: MCS index table 2 for PDSCH - 138 214
% https://www.etsi.org/deliver/etsi_ts/138200_138299/138214/18.06.00_60/ts_138214v180600p.pdf
pdsch = pdsch.setMCS(21); 

pdsch.CodebookConfig = cfg;

pdsch.Indices.i1 = {i11, i12, i13, i14};
pdsch.Indices.i2 = {i21, i22};

pdsch.NumLayers = nlayers;
% 273 PRB
pdsch.PRBSet = 0:272;

[antsym, antind] = PDSCHToolbox(pdsch, carrier, inputBits);

% -----------------------------------------------------------
% RESOURCE GRID MAPPING & OFDM MODULATION
% Map the precoded symbols onto the Time-Frequency resource grid.
% -----------------------------------------------------------
txGrid = nrResourceGrid(carrier, 2 * cfg.N1 * cfg.N2); 
txGrid(antind) = antsym;

fprintf('Resources Grid Size ::::: %d x %d x %d\n', size(txGrid));