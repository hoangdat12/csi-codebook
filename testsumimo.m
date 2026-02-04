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


% Channel for test
% Rayleigh || AWGN || Ideal || CDL
% With Ideal channel, we can't choose the PMI orthogonal 
% Because of all channel use the same PMI
channelType = "Ideal";
channel = getChannel(channelType, SNR_dB, nRxAnts, 1, [4 1 2 1 1]); 

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
% CSI Report Configuration Type II
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

pdsch.CodebookConfig = cfg;
pdsch.DMRS.DMRSConfigurationType = 1;
pdsch.DMRS.DMRSAdditionalPosition = 1;
pdsch.NumLayers = nlayers;
% 273 PRB
pdsch.PRBSet = 0:272;

% -----------------------------------------------------------------
% Mesurements
% -----------------------------------------------------------------
[MCS, PMI] = csiRsMesurements(carrier, channel, csiConfig, csiReport, pdsch, nlayers);

pdsch.Indices.i1 = PMI.i1;
pdsch.Indices.i2 = PMI.i2;

% Table 5.1.3.1-2: MCS index table 2 for PDSCH - 138 214
% https://www.etsi.org/deliver/etsi_ts/138200_138299/138214/18.06.00_60/ts_138214v180600p.pdf
pdsch = pdsch.setMCS(MCS); 

% -----------------------------------------------------------------
% Generate Bits
% -----------------------------------------------------------------
[~, pdschInfo] = nrPDSCHIndices(carrier, pdsch);
NREPerPRB = pdschInfo.NREPerPRB;

disp(pdsch.Modulation);

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
rxWaveform = channel(txWaveform);

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


% -----------------------------------------------------------------
% This function use to get the channel for TEST
% It return:
%   - channel: AWGN | Rayleigh | Ideal channel.
% -----------------------------------------------------------------
function channel = getChannel(channelType, SNR_dB, nRxAnts, ueIdx, cdlChannelAntenna) 
    switch channelType
        case 'AWGN'
            channel = AWGNChannel('SNRdB', SNR_dB, 'NumRxAnts', nRxAnts);
            
        case 'Rayleigh'
            channel = RayleighChannel('SNRdB', SNR_dB, 'NumRxAnts', nRxAnts);
            
        case 'Ideal'
            channel = IdealChannel('SNRdB', SNR_dB, 'NumRxAnts', nRxAnts);

        case 'CDL'
            cdlChannel = nrCDLChannel;
            cdlChannel.DelayProfile = 'CDL-C';
            % Format [M, N, P, Mg, Ng] 
            %   M: The number of antenna in the vertical = N1
            %   N: The number of antenna in the horizontal = N2
            %   P: Polarization
            %   Mg: The number of panel row
            %   Ng: The number of panel column
            cdlChannel.TransmitAntennaArray.Size = cdlChannelAntenna;
            cdlChannel.ReceiveAntennaArray.Size = [2, 1, 2, 1, 1];   
            cdlChannel.Seed = ueIdx; 

            channel = cdlChannel;
            
        otherwise
            error('Invalid Type "%s"', channelType);
    end
end