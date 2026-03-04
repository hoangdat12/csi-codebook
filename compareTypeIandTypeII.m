clear; clc; close all;

setupPath();

% -----------------------------------------------------------------
% Configuration Parameters
% -----------------------------------------------------------------
nLayers = 2;
SNR_dB = 20;
NumUEs = 20;
% The value in the range = {8, 16, 32}, because of the related RowNumber.
nTxAnts = 8;                
nRxAnts = 4;                 
sampleRate = 61440000;

N1 = 4; N2 = 1; O1 = 4; O2 = 1;
codebookMode = 1;

% Channel for test
% AWGN || Ideal || TDL
% With Ideal channel, we can't choose the PMI orthogonal 
% Because of all channel use the same PMI
channelType = "AWGN";

% Threadhold for identify PMI Pair
THREAD_HOLD = 1e-15;


% -----------------------------------------------------------------
% Carrier Configuration
% -----------------------------------------------------------------
carrier = nrCarrierConfig;
carrier.SubcarrierSpacing = 30;
% With 273 RB, we need scs 30 
carrier.NSizeGrid = 273;

% -----------------------------------------------------------------
% Find the orthogonal PMI
% -----------------------------------------------------------------
% Because of nrCQIReport function just only use 
% DMRSLength, DMRSAdditionalPosition and DMRSEnhancedR18 from PDSCH DM-RS configuration
% So the pdsch for both use in the aspect of prepareData function
pdsch = customPDSCHConfig;
pdsch.DMRS.DMRSConfigurationType = 1;
pdsch.DMRS.DMRSAdditionalPosition = 1;
pdsch.NumLayers = nLayers;

% 273 PRB
% The PDSCH channel occupies the entire bandwidth
pdsch.PRBSet = 0:272;

%--------------------------------------------------------------
% TYPE I
%--------------------------------------------------------------

% Loop from 1 to 4 layers
port = 2 * N1 * N2;
all_W = generatePrecodingMatrix(N1, N2, O1, O2, nLayers, codebookMode);

channelList = cell(1, length(all_W));

schedulingList = scheduling(all_W, channelList, THREAD_HOLD);
pairedUEs = schedulingList.pair;

for idx = 1:length(pairedUEs)
    transmittUEPair = pairedUEs(idx);

    % UE1
    W1   = transmittUEPair.UE1.W;

    % UE 2
    W2   = transmittUEPair.UE2.W;

    [BER1, BER2] = muMimo(carrier, pdsch, W1, W2, 12, SNR_dB);

    if BER1 > 0 || BER2 > 0
        fprintf('Warning at idx = %d | BER1 = %.4e | BER2 = %.4e\n', ...
                idx, BER1, BER2);
    end
end


%--------------------------------------------------------------
% TYPE II
%--------------------------------------------------------------

% Csi Config
csiConfig = nrCSIRSConfig;
csiConfig.CSIRSType = {'nzp'};
% https://www.etsi.org/deliver/etsi_ts/138200_138299/138211/18.06.00_60/ts_138211v180600p.pdf
% Bảng 7.4.1.5.3-1.
% 6 -> 8 Ports
% 11 -> 16 Ports
% 16 -> 32 Ports

if nTxAnts == 8
    rowNumber = 6;
    csiReportAntenna = [1 4 1];
    csiReportSymbolLocations = {0};
elseif nTxAnts == 16
    rowNumber = 11;
    csiReportAntenna = [1 4 2];
    csiReportSymbolLocations = {0};
else 
    rowNumber = 17;
    csiReportAntenna = [1 4 4];
    csiReportSymbolLocations = {[2 3]};
end

csiConfig.RowNumber = rowNumber;           
csiConfig.Density = {'one'};
csiConfig.SubcarrierLocations = {[0 2 4 6]};
csiConfig.SymbolLocations = csiReportSymbolLocations;
csiConfig.CSIRSPeriod = [4 0];
csiConfig.NumRB = 273;
csiConfig.RBOffset = 0;

% CSI Report Config (Type II)
subbandAmplitude = true;
csiReport = nrCSIReportConfig;
% Table 2 support 256QAM
csiReport.CQITable = "table2"; 
csiReport.CodebookType = "type2";
% [Ng N1 N2]
csiReport.PanelDimensions = csiReportAntenna; 
% Report PMI for each subband
csiReport.PMIFormatIndicator = "subband";
% Report CQI for every subband
csiReport.CQIFormatIndicator = "subband";
csiReport.SubbandSize = 32;
csiReport.SubbandAmplitude = subbandAmplitude;
csiReport.NumberOfBeams = 2;
csiReport.PhaseAlphabetSize = 4;
csiReport.RIRestriction = [1 1 0 0]; 


% -----------------------------------------------------------------
% TX
% -----------------------------------------------------------------

% -----------------------------------------------------------------
% Preparation
% -----------------------------------------------------------------
[all_W, PMIList, channelList] = prepareData(...
        NumUEs, carrier, csiConfig, csiReport, pdsch, sampleRate,...
        nRxAnts, SNR_dB, nLayers, channelType ...
    );

schedulingList = scheduling(all_W, channelList, THREAD_HOLD);
pairedUEs = schedulingList.pair;
unPairedUEs = schedulingList.unPair;

pairPMI = cell(length(pairedUEs), 1);
for idx = 1:length(pairedUEs)
    transmittUEPair = pairedUEs(idx);

    % UE1
    idx1 = transmittUEPair.UE1.ueIdx;

    % UE 2
    idx2 = transmittUEPair.UE2.ueIdx;
    
    PMIUE1 = PMIList{idx1};
    PMIUE2 = PMIList{idx2};
    pairPMI{idx} = struct('PMIUE1', PMIUE1, 'PMIUE2', PMIUE2);
end

MCS = 12;
nLayers = 2;

cfg = struct();
cfg.CodebookConfig.N1 = 4; 
cfg.CodebookConfig.N2 = 1;
cfg.CodebookConfig.O1 = 4;
cfg.CodebookConfig.O2 = 1;
cfg.CodebookConfig.NumberOfBeams = 2;      
cfg.CodebookConfig.PhaseAlphabetSize = 4; 
cfg.CodebookConfig.SubbandAmplitude = true;
cfg.CodebookConfig.numLayers = nLayers;   

for idx=1:length(pairPMI)
    PMIUE1 = pairPMI{idx}.PMIUE1;
    PMIUE2 = pairPMI{idx}.PMIUE2;

    W1 = generateTypeIIPrecoder(cfg, PMIUE1.i1, PMIUE1.i2, true);
    W2 = generateTypeIIPrecoder(cfg, PMIUE2.i1, PMIUE2.i2, true);

    [BER1, BER2] = muMimo(...
        carrier, pdsch, ...
        W1, W2, MCS, 20 ...
    );

    if BER1 > 0 || BER2 > 0
        fprintf('Warning at idx = %d | BER1 = %.4e | BER2 = %.4e\n', ...
                idx, BER1, BER2);
    end
end

function [BER1, BER2] = muMimo(...
    carrier, basePDSCHConfig, ...
    UE1_W, UE2_W, MCS, SNR_dB ...
)
    
    % -----------------------------------------------------------------
    % UE1 Configuration
    % -----------------------------------------------------------------
    pdsch = basePDSCHConfig; 

    pdsch.DMRS.DMRSPortSet = [0, 1]; 
    pdsch = pdsch.setMCS(MCS);

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
    pdsch2 = pdsch2.setMCS(MCS);

    [~, pdschInfo] = nrPDSCHIndices(carrier, pdsch2);
    NREPerPRB = pdschInfo.NREPerPRB;

    TBS2 = nrTBS(pdsch2.Modulation, pdsch2.NumLayers, ...
                length(pdsch2.PRBSet), NREPerPRB, pdsch2.TargetCodeRate);
    inputBits2 = randi([0 1], TBS2, 1);

    H_composite = [UE1_W.'; UE2_W.'];

    numTx = size(UE1_W, 1);
    W_total_T = getMMSEPrecoder(H_composite, SNR_dB, numTx);

    % Extract W precoding from the Final W after MMSE
    nLayers1 = size(UE1_W, 2);
    W_transposed = W_total_T(1:nLayers1, :);      
    W2_transposed = W_total_T(nLayers1+1:end, :);  

    % W_transposed = UE1_W.';      
    % W2_transposed = UE2_W.';  

    % -----------------------------------------------------------------
    % PDSCH Modulation
    % -----------------------------------------------------------------
    [layerMappedSym, pdschInd] = PDSCHEncode(pdsch, carrier, inputBits);
    [layerMappedSym2, pdschInd2] = PDSCHEncode(pdsch2, carrier, inputBits2);

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
    txWaveform = nrOFDMModulate(carrier, txGrid);

    % -----------------------------------------------------------------
    % Channel
    % -----------------------------------------------------------------
    % rxWaveformUE1 = txWaveform;

    % channel = nrTDLChannel;
    % channel.NumTransmitAntennas = 8;
    % channel.NumReceiveAntennas = 4;
    % channel.SampleRate = 61440000;
    % channel.DelayProfile = 'TDL-C';
    % channel.DelaySpread = 0;
    % channel.Seed = 1;
    % channel.MaximumDopplerShift = 5;

    rxWaveformUE1 = txWaveform;

    signalPower = var(rxWaveformUE1);

    signalPower_dBW = 10 * log10(mean(signalPower));
    noisePower_dBW = signalPower_dBW - 20;
    noiseVariance = 10^(noisePower_dBW / 10);
    noise = sqrt(noiseVariance / 2) * (randn(size(rxWaveformUE1)) + 1i * randn(size(rxWaveformUE1)));
    rxWaveformUE1 = rxWaveformUE1 + noise;

    rxWaveformUE2 = txWaveform;

    signalPower = var(rxWaveformUE2);

    signalPower_dBW = 10 * log10(mean(signalPower));
    noisePower_dBW = signalPower_dBW - 20;
    noiseVariance = 10^(noisePower_dBW / 10);
    noise = sqrt(noiseVariance / 2) * (randn(size(rxWaveformUE2)) + 1i * randn(size(rxWaveformUE2)));
    rxWaveformUE2 = rxWaveformUE2 + noise;

    % -----------------------------------------------------------------
    % RX
    % -----------------------------------------------------------------

    % -----------------------------------------------------------------
    % Extract data for UE1
    % -----------------------------------------------------------------
    % OFDM Demodulation
    rxBits = rxPDSCHDecode(carrier, pdsch, rxWaveformUE1, txWaveform, TBS);

    numErrors = biterr(double(inputBits), double(rxBits));
    BER1 = numErrors / TBS;

    % -----------------------------------------------------------------
    % Extract Data for UE2
    % -----------------------------------------------------------------
    rxBits2 = rxPDSCHDecode(carrier, pdsch2, rxWaveformUE2, txWaveform, TBS2);

    numErrors2 = biterr(double(inputBits2), double(rxBits2));
    BER2 = numErrors2 / TBS;
end

function [all_W, PMIList, channelList] = prepareData(...
        NumUEs, carrier, csiConfig, csiReport, pdsch, sampleRate,...
        nRxAnts, SNR_dB, nLayers, channelType...
)

    % Initial channel list
    channelList = cell(1, NumUEs);

    all_W = cell(1, NumUEs);
    PMIList = cell(1, NumUEs);

    % Starting calculate the csi
    for ueIdx = 1:NumUEs
        channel = getChannel(channelType, SNR_dB, nRxAnts, ueIdx, sampleRate); 

        channelList{ueIdx} = channel;
        
        % CSI Mesurement
        [~, PMI] = csiRsMesurements(carrier, channel, csiConfig, csiReport, pdsch, nLayers);

        cfg = struct();
        cfg.CodebookConfig.N1 = csiReport.PanelDimensions(2); 
        cfg.CodebookConfig.N2 = csiReport.PanelDimensions(3);
        cfg.CodebookConfig.O1 = 4;
        cfg.CodebookConfig.O2 = 1;
        cfg.CodebookConfig.NumberOfBeams = csiReport.PanelDimensions(1) * csiReport.NumberOfBeams;      
        cfg.CodebookConfig.PhaseAlphabetSize = csiReport.PhaseAlphabetSize; 
        cfg.CodebookConfig.SubbandAmplitude = csiReport.SubbandAmplitude;
        cfg.CodebookConfig.numLayers = nLayers;         

        W = generateTypeIIPrecoder(cfg, PMI.i1, PMI.i2, true);
        all_W{ueIdx} = W;
        PMIList{ueIdx} = PMI;
    end
end

function cfg = getCfigVariable(N1, N2, O1, O2, codebookMode)
    cfg.CodebookConfig.N1 = N1;
    cfg.CodebookConfig.N2 = N2;
    cfg.CodebookConfig.O1 = O1;
    cfg.CodebookConfig.O2 = O2;
    cfg.CodebookConfig.nPorts = 2*N1*N2;
    cfg.CodebookConfig.codebookMode = codebookMode;
end

function W = generatePrecodingMatrix(N1, N2, O1, O2, nLayers, codebookMode)
    % Create lookup table
    [i11_lookup, i12_lookup, i13_lookup, i2_lookup] = lookupPMITable(N1, N2, O1, O2, nLayers, codebookMode);

    % Get total PMI. Because of lookup table [PMI_length x 1]
    totalPmi = length(i2_lookup);

    W = cell(totalPmi, 1);

    for pmi_value = 0:totalPmi-1
        % Matlab index start from 1.
        pmi_idx = pmi_value + 1;

        % Mapping from PMI to i11, i12, i2
        i11 = i11_lookup(pmi_idx);
        i12 = i12_lookup(pmi_idx);
        i13 = i13_lookup(pmi_idx);
        i2  = i2_lookup(pmi_idx);

        cfg = getCfigVariable(N1, N2, O1, O2, codebookMode);

        i1 = {i11, i12, i13};

        W_raw = generateTypeISinglePanelPrecoder(cfg, nLayers, i1, i2);
        W{pmi_idx} = complex(W_raw);
    end
end

function [i11_lookup, ...
    i12_lookup, ...
    i13_lookup, ...
    i2_lookup ...
] = lookupPMITable(N1, N2, O1, O2, nLayers, codebookMode)
    % Find the end value of each range of each value [i11, i12, i13, 14]
    % Because of they all start at the 0 value and end with X value
    % X will be returned at this function
    [idx11_end, idx12_end, idx13_end, idx2_end] = findRangeValues(N1, N2, O1, O2, nLayers, codebookMode);

    % After determined range values of i11, i12, i13, i2
    % Create Lookup table.
    [i11_lookup, i12_lookup, i13_lookup, i2_lookup] = genLookupTable(idx11_end, idx12_end, idx13_end, idx2_end);
end

function [i11_lookup, i12_lookup, i13_lookup, i2_lookup] = genLookupTable(idx11_end, idx12_end, idx13_end, idx2_end)
    % The number of PMI index
    N = (idx11_end+1) * (idx12_end+1) * ...
        (idx13_end+1) * (idx2_end+1);

    % Preallocate
    i11_lookup = zeros(N,1);
    i12_lookup = zeros(N,1);
    i13_lookup = zeros(N,1);
    i2_lookup  = zeros(N,1);

    n = 1;
    for idx11 = 0:idx11_end
        for idx12 = 0:idx12_end
            for idx13 = 0:idx13_end
                for idx2 = 0:idx2_end
                    i11_lookup(n) = idx11;
                    i12_lookup(n) = idx12;
                    i13_lookup(n) = idx13;
                    i2_lookup(n)  = idx2;
                    n = n + 1;
                end
            end
        end
    end
end
