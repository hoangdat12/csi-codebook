clear; clc; close all;

setupPath();

% -----------------------------------------------------------------
% Configuration Parameters
% -----------------------------------------------------------------
nLayers = 2;
SNR_dB = 20;
NumUEs = 10;
nTxAnts = 8;                
nRxAnts = 2;                 
sampleRate = 61440000;        
% Orthogonal => Best Pair PMI
% Non-Orthogonal => Worst Pair PMI
comparisionCase = "Orthogonal";

% The value based on the Table 5.1.3.1 - 138 214
% 11 -> 64QAM & 466/1024 Target code Rate
% 6 -> 16QAM & 434/1024 Target code Rate
MSCReport = 6;

% Threadhold for identify PMI Pair
if nLayers == 2
    THREAD_HOLD = 1e-15;
elseif nLayers == 3
    THREAD_HOLD = 1e-2;
else
    THREAD_HOLD = 1e-2;
end

% Csi Config
csiConfig = nrCSIRSConfig;
csiConfig.CSIRSType = {'nzp'};
% https://www.etsi.org/deliver/etsi_ts/138200_138299/138211/18.06.00_60/ts_138211v180600p.pdf
% Bảng 7.4.1.5.3-1.
% 6 -> 8 Ports
csiConfig.RowNumber = 6;           
csiConfig.Density = {'one'};
csiConfig.SubcarrierLocations = {[0 2 4 6]};
csiConfig.SymbolLocations = {0};
csiConfig.CSIRSPeriod = [4 0];
csiConfig.NumRB = 273;
csiConfig.RBOffset = 0;

% CSI Report Config (Type II)
subbandAmplitude = true;
csiReport = nrCSIReportConfig;
% Table 2 support 256QAM
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
% Carrier Configuration
% -----------------------------------------------------------------
carrier = nrCarrierConfig;
carrier.SubcarrierSpacing = 15; 
carrier.NSizeGrid = 273;

% -----------------------------------------------------------------
% UE1 Configuration
% -----------------------------------------------------------------
pdsch = customPDSCHConfig(); 
pdsch = pdsch.setMCS(MSCReport); % 16QAM

pdsch.NumLayers = nLayers;
pdsch.PRBSet = 0:272; 
pdsch.DMRS.DMRSConfigurationType = 1;
pdsch.DMRS.DMRSAdditionalPosition = 1;
pdsch.DMRS.DMRSPortSet = [0, 1]; 

[~, pdschInfo] = nrPDSCHIndices(carrier, pdsch);
NREPerPRB = pdschInfo.NREPerPRB;

% Get the optimize input length for transmit
TBS = nrTBS(pdsch.Modulation, pdsch.NumLayers, ...
            length(pdsch.PRBSet), NREPerPRB, pdsch.TargetCodeRate);
inputBits = randi([0 1], TBS, 1);

% -----------------------------------------------------------------
% UE2 Configuration
% -----------------------------------------------------------------
pdsch2 = pdsch; 
pdsch2.DMRS.DMRSPortSet = [2, 3]; 

[~, pdschInfo] = nrPDSCHIndices(carrier, pdsch2);
NREPerPRB = pdschInfo.NREPerPRB;

TBS = nrTBS(pdsch2.Modulation, pdsch2.NumLayers, ...
            length(pdsch2.PRBSet), NREPerPRB, pdsch2.TargetCodeRate);
inputBits2 = randi([0 1], TBS, 1);

% -----------------------------------------------------------------
% TX
% -----------------------------------------------------------------

% -----------------------------------------------------------------
% PDSCH Modulation
% -----------------------------------------------------------------
[layerMappedSym, pdschInd] = PDSCHEncode(pdsch, carrier, inputBits);
[layerMappedSym2, pdschInd2] = PDSCHEncode(pdsch2, carrier, inputBits2);


% -----------------------------------------------------------------
% Find the orthogonal PMI
% -----------------------------------------------------------------
[best_pair_info, worst_pair_info, ~, ~] = ...
    prepareData(...
        NumUEs, carrier, csiConfig, csiReport,...
        THREAD_HOLD, nTxAnts, nRxAnts, sampleRate, nLayers...
    );

if comparisionCase == "Orthogonal"
    current_info = best_pair_info;
else
    current_info = worst_pair_info;
end

% UE Precoding matrix after measurement CSI
UE1_W = current_info.UE1.W;
UE2_W = current_info.UE2.W;

% The UE specific channel
UE1_Channel = current_info.UE1.channel;
UE2_Channel = current_info.UE2.channel;

% -----------------------------------------------------------------
% MMSE Equalization
% -----------------------------------------------------------------
H_composite = [UE1_W.'; UE2_W.'];

numTx = size(UE1_W, 1);
W_total_T = getMMSEPrecoder(H_composite, SNR_dB, numTx);

% Extract W precoding from the Final W after MMSE
nLayers1 = size(UE1_W, 2);
W_transposed = W_total_T(1:nLayers1, :);      
W2_transposed = W_total_T(nLayers1+1:end, :);  


% -----------------------------------------------------------------
% Precoding 
% -----------------------------------------------------------------
[antsym, antind] = nrPDSCHPrecode(carrier, layerMappedSym, pdschInd, W_transposed);
[antsym2, antind2] = nrPDSCHPrecode(carrier, layerMappedSym2, pdschInd2, W2_transposed);

% -----------------------------------------------------------------
% DMRS
% -----------------------------------------------------------------
dmrsSym = nrPDSCHDMRS(carrier, pdsch);
dmrsInd = nrPDSCHDMRSIndices(carrier, pdsch);
[dmrsAntSym, dmrsAntInd] = nrPDSCHPrecode(carrier, dmrsSym, dmrsInd, W_transposed);

dmrsSym2 = nrPDSCHDMRS(carrier, pdsch2);
dmrsInd2 = nrPDSCHDMRSIndices(carrier, pdsch2);
[dmrsAntSym2, dmrsAntInd2] = nrPDSCHPrecode(carrier, dmrsSym2, dmrsInd2, W2_transposed);

% -----------------------------------------------------------------
% Resource Mapping
% -----------------------------------------------------------------
numPorts = size(W_transposed, 2);

txGrid = nrResourceGrid(carrier, numPorts); 

txGrid(antind) = antsym;
txGrid(dmrsAntInd) = dmrsAntSym;

txGrid(antind2) = txGrid(antind2) + antsym2;
txGrid(dmrsAntInd2) = txGrid(dmrsAntInd2) + dmrsAntSym2;

% OFDM Modulation
[txWaveform, waveformInfo] = nrOFDMModulate(carrier, txGrid);

% -----------------------------------------------------------------
% Channel
% -----------------------------------------------------------------
% rxWaveformUE1 = channelPropagateAndSync( ...
%         txWaveform, carrier, UE1_Channel, dmrsInd, dmrsSym, SNR_dB);

% rxWaveformUE2 = channelPropagateAndSync( ...
%         txWaveform, carrier, UE2_Channel, dmrsInd2, dmrsSym2, SNR_dB);

[rxWaveformUE1, ~] = channelFlatFading(txWaveform, SNR_dB, 4);
[rxWaveformUE2, ~] = channelFlatFading(txWaveform, SNR_dB, 4);

% -----------------------------------------------------------------
% RX
% -----------------------------------------------------------------
% OFDM Demodulation
rxGrid1 = nrOFDMDemodulate(carrier, rxWaveformUE1);
rxGrid2 = nrOFDMDemodulate(carrier, rxWaveformUE2);

% -----------------------------------------------------------------
% Extract data for UE1
% -----------------------------------------------------------------
refDmrsSym1 = nrPDSCHDMRS(carrier, pdsch);
refDmrsInd1 = nrPDSCHDMRSIndices(carrier, pdsch);

% Estimate
[Hest1, nVar1] = nrChannelEstimate(carrier, rxGrid1, refDmrsInd1, refDmrsSym1);

% Extract data
[pdschRx1, pdschHest1] = nrExtractResources(pdschInd, rxGrid1, Hest1);
[eqSymbols1, csi1] = nrEqualizeMMSE(pdschRx1, pdschHest1, nVar1);

TBS1 = length(inputBits);
[rxBits1, ~] = PDSCHDecode(pdsch, carrier, eqSymbols1, TBS1, SNR_dB);

% Compute BER
numErrors1 = biterr(double(inputBits(:)), double(rxBits1(:)));
BER1 = numErrors1 / TBS1;
disp(['BER UE 1: ', num2str(BER1)]);

% -----------------------------------------------------------------
% Extract Data for UE2
% -----------------------------------------------------------------

% Extract DMRS
refDmrsSym2 = nrPDSCHDMRS(carrier, pdsch2); 
refDmrsInd2 = nrPDSCHDMRSIndices(carrier, pdsch2); 

% Estimate
[Hest2, nVar2] = nrChannelEstimate(carrier, rxGrid2, refDmrsInd2, refDmrsSym2);

% Extract PDSCH Data
[pdschRx2, pdschHest2] = nrExtractResources(pdschInd2, rxGrid2, Hest2); 
[eqSymbols2, csi2] = nrEqualizeMMSE(pdschRx2, pdschHest2, nVar2);

TBS2 = length(inputBits2);
[rxBits2, ~] = PDSCHDecode(pdsch2, carrier, eqSymbols2, TBS2, SNR_dB);

% Compute BER
numErrors2 = biterr(double(inputBits2(:)), double(rxBits2(:)));
BER2 = numErrors2 / TBS2;
disp(['BER UE 2: ', num2str(BER2)]);


% -----------------------------------------------------------------
% HELPER FUNCTION
% -----------------------------------------------------------------

function [...
    best_pair_info, worst_pair_info, all_candidates, info ] = ...
prepareData(...
        NumUEs, carrier, csiConfig, csiReport,...
        THREAD_HOLD, nTxAnts, nRxAnts, sampleRate, nLayers...
)

    % Initial channel list
    channelList = cell(1, NumUEs);

    for ueIdx = 1:NumUEs
        tdl = nrTDLChannel();
        tdl.DelayProfile = 'TDL-A';       
        tdl.DelaySpread = 300e-9;
        tdl.MaximumDopplerShift = 0;      
        tdl.SampleRate = sampleRate;
        tdl.NumTransmitAntennas = nTxAnts; 
        tdl.NumReceiveAntennas = nRxAnts;
        tdl.Seed = ueIdx;
        channelList{ueIdx} = tdl;
    end

    % Initial W
    all_W = cell(1, NumUEs);

    % Codebook Config - The same for all UE
    cfg = struct();
    cfg.CodebookConfig.N1 = csiReport.PanelDimensions(2); 
    cfg.CodebookConfig.N2 = csiReport.PanelDimensions(3);
    cfg.CodebookConfig.O1 = 4;
    cfg.CodebookConfig.O2 = 1;
    cfg.CodebookConfig.NumberOfBeams = csiReport.PanelDimensions(1) * csiReport.NumberOfBeams;      
    cfg.CodebookConfig.PhaseAlphabetSize = csiReport.PhaseAlphabetSize; 
    cfg.CodebookConfig.SubbandAmplitude = csiReport.SubbandAmplitude;
    cfg.CodebookConfig.numLayers = nLayers;          

    % Starting calculate the csi
    for ueIdx = 1:NumUEs
        currentChannel = channelList{ueIdx};
        
        [i1, i2] = csiRsMesurements(carrier, currentChannel, csiConfig, csiReport, nLayers);
        
        W = generateTypeIIPrecoder(cfg, i1, i2, true);
        
        all_W{ueIdx} = W;
    end

    % Perform UE pairing.
    [best_pair_info, worst_pair_info, all_candidates, info] = ...
        findBestUEPair(all_W, channelList, THREAD_HOLD);

    disp(['Best UE pair correlation:::: ', num2str(info.best_Cmn)]);
    disp(['Worst UE pair correlation:::: ', num2str(info.worst_Cmn)]);
end