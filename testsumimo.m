clear; clc; close all;

setupPath();

% -----------------------------------------------------------------
% Configuration Parameters
% -----------------------------------------------------------------
nlayers = 2;
nTxAnts = 8;                
nRxAnts = 4;                 
sampleRate = 61440000;  
SNR_dB = 20;

% -----------------------------------------------------------------
% Channel Configuration
% -----------------------------------------------------------------
channel = nrTDLChannel();
channel.DelayProfile = 'TDL-C';       
channel.DelaySpread = 300e-9;
channel.MaximumDopplerShift = 5;      
channel.SampleRate = sampleRate;
channel.NumTransmitAntennas = nTxAnts; 
channel.NumReceiveAntennas = nRxAnts;

% -----------------------------------------------------------------
% Carrier Configuration
% -----------------------------------------------------------------
carrier = nrCarrierConfig;
% Sharetechnote frame structure 
% Table 5.3.2-1 138-101-1
% https://www.etsi.org/deliver/etsi_ts/138100_138199/13810101/17.08.00_60/ts_13810101v170800p.pdf
carrier.SubcarrierSpacing = 15;  
carrier.NSizeGrid = 273;

% -----------------------------------------------------------------
% CSI Configuration
% -----------------------------------------------------------------
csiConfig = nrCSIRSConfig;
csiConfig.CSIRSType = {'nzp'};
% https://www.etsi.org/deliver/etsi_ts/138200_138299/138211/18.06.00_60/ts_138211v180600p.pdf
% Bảng 7.4.1.5.3-1.
csiConfig.RowNumber = 6;           
csiConfig.Density = {'one'};
csiConfig.SubcarrierLocations = {[0 2 4 6]};
csiConfig.SymbolLocations = {0};
csiConfig.CSIRSPeriod = [4 0];
csiConfig.NumRB = 273;
csiConfig.RBOffset = 0;

% -----------------------------------------------------------------
% CSI Report Configuration
% -----------------------------------------------------------------
subbandAmplitude = true;
csiReport = nrCSIReportConfig;
csiReport.CQITable = "table2"; 
csiReport.CodebookType = "type2";
csiReport.PanelDimensions = [1 4 1]; 
csiReport.PMIFormatIndicator = "subband";
csiReport.CQIFormatIndicator = "subband";
csiReport.SubbandSize = 32;
csiReport.SubbandAmplitude = subbandAmplitude;
csiReport.NumberOfBeams = 2;
csiReport.PhaseAlphabetSize = 4;
csiReport.RIRestriction = [1 1 0 0]; 

[i1, i2] = csiRsMesurements(carrier, channel, csiConfig, csiReport, nlayers, "PropagateAndSync");

% -----------------------------------------------------------------
% Codebook Configuration
% -----------------------------------------------------------------
cfg = struct();
cfg.N1 = csiReport.PanelDimensions(2); 
cfg.N2 = csiReport.PanelDimensions(3);
cfg.O1 = 4;
cfg.O2 = 1;
cfg.NumberOfBeams = csiReport.PanelDimensions(1) * csiReport.NumberOfBeams;      
cfg.PhaseAlphabetSize = csiReport.PhaseAlphabetSize; 
cfg.SubbandAmplitude = csiReport.SubbandAmplitude;
cfg.numLayers = nlayers;   

% -----------------------------------------------------------------
% PDSCH Configuration
% -----------------------------------------------------------------
pdsch = customPDSCHConfig(); 

% Table 5.1.3.1-2: MCS index table 2 for PDSCH - 138 214
% https://www.etsi.org/deliver/etsi_ts/138200_138299/138214/18.06.00_60/ts_138214v180600p.pdf
pdsch = pdsch.setMCS(6); 

pdsch.CodebookConfig = cfg;
pdsch.Indices.i1 = i1;
pdsch.Indices.i2 = i2;
pdsch.DMRS.DMRSConfigurationType = 1;
pdsch.DMRS.DMRSAdditionalPosition = 1;
pdsch.NumLayers = nlayers;
% 273 PRB
pdsch.PRBSet = 0:272;

[~, pdschInfo] = nrPDSCHIndices(carrier, pdsch);
NREPerPRB = pdschInfo.NREPerPRB;

TBS = nrTBS(pdsch.Modulation, pdsch.NumLayers, ...
            length(pdsch.PRBSet), NREPerPRB, pdsch.TargetCodeRate);
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
txGrid = nrResourceGrid(carrier, 2 * cfg.N1 * cfg.N2); 
txGrid(antind) = antsym;
txGrid(dmrsAntInd) = dmrsAntSym;  

[txWaveform, waveformInfo] = nrOFDMModulate(carrier, txGrid);

% -----------------------------------------------------------------
% Channel
% -----------------------------------------------------------------
rxWaveform = channelPropagateAndSync( ...
        txWaveform, carrier, channel, dmrsInd, dmrsSym, SNR_dB);


% -----------------------------------------------------------------
% RX and Calculate BER
% -----------------------------------------------------------------
rxGrid = nrOFDMDemodulate(carrier, rxWaveform);

refDmrsSym = nrPDSCHDMRS(carrier, pdsch);
refDmrsInd = nrPDSCHDMRSIndices(carrier, pdsch);
[Hest, nVar] = nrChannelEstimate(carrier, rxGrid, refDmrsInd, refDmrsSym);
[pdschRx, pdschHest] = nrExtractResources(pdschInd, rxGrid, Hest);
[eqSymbols, csi] = nrEqualizeMMSE(pdschRx, pdschHest, nVar);
TBS = length(inputBits);
[rxBits, hasError] = PDSCHDecode(pdsch, carrier, eqSymbols, TBS, SNR_dB);
numErrors = biterr(double(inputBits(:)), double(rxBits(:)));
BER = numErrors / TBS;

disp(BER);