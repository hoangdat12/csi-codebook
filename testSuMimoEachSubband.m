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
% Rayleigh || AWGN || Ideal || TDL
% With Ideal channel, we can't choose the PMI orthogonal 
% Because of all channel use the same PMI
channelType = "TDL";
channel = getChannel(channelType, SNR_dB, nRxAnts, 1, sampleRate); 

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
csiConfig.RowNumber = rowNumber;           
csiConfig.Density = {'one'};
csiConfig.SubcarrierLocations = {[0 2 4 6]};
csiConfig.SymbolLocations = csiReportSymbolLocations;
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
csiReport.PanelDimensions = csiReportAntenna; 
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
[MCS, PMI] = csiRsMesurementsV2(carrier, channel, csiConfig, csiReport, pdsch, nlayers);

for k = 1:length(PMI.i1)
    val = PMI.i1{k};
    val_str = mat2str(val); 
    fprintf('i1%d :::::::::: %s\n', k, val_str);
end

% In phần i2 (có chia subband)
for k = 1:length(PMI.i2)
    data = PMI.i2{k};
    num_subbands = size(data, 3);
    
    for sb = 1:num_subbands
        val_sb = data(:,:,sb);
        val_sb_str = mat2str(val_sb);
        fprintf('i2%d - subband %d :::::::::: %s\n', k, sb, val_sb_str);
    end
end

% 1. Xác định kích thước
numSubbands = size(PMI.i2{1}, 3);

i21_cell = PMI.i2{1};
i22_cell = PMI.i2{2};

all_W = complex(zeros(nTxAnts, nlayers, numSubbands)); 

for sb = 1:numSubbands
    i21 = i21_cell(:, :, sb);
    i22 = i22_cell(:, :, sb);
    i2 = {i21, i22};
    
    % Tính toán
    W_subband = generateTypeIIPrecoder(pdsch, PMI.i1, i2, true);
    
    all_W(:, :, sb) = W_subband; 
end

W_subband = all_W(:, :, 1);
W_transposed = W_subband.';

% Table 5.1.3.1-2: MCS index table 2 for PDSCH - 138 214
% https://www.etsi.org/deliver/etsi_ts/138200_138299/138214/18.06.00_60/ts_138214v180600p.pdf
pdsch = linkAdaption(pdsch, MCS, SNR_dB);

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
layerGrid = nrResourceGrid(carrier, nlayers); 

dmrsSym = nrPDSCHDMRS(carrier, pdsch);
dmrsInd = nrPDSCHDMRSIndices(carrier, pdsch);

layerGrid(pdschInd) = layerMappedSym;
layerGrid(dmrsInd) = dmrsSym;  

txGrid = nrResourceGrid(carrier, 2 * cfg.N1 * cfg.N2);
nSC_Total = size(txGrid, 1);
SCs_per_Subband = floor(nSC_Total / numSubbands);


for sb = 1:numSubbands
    idx_start = (sb - 1) * SCs_per_Subband + 1;
    idx_end   = sb * SCs_per_Subband;
    
    if sb == numSubbands
        idx_end = nSC_Total;
    end
    
    X_subband = layerGrid(idx_start:idx_end, :, :);
    
    W_subband = all_W(:, :, sb);
    
    [K, L, R] = size(X_subband); 
    X_flat = reshape(X_subband, K*L, R);
    
    Y_flat = X_flat * W_subband.'; 
    
    Y_subband = reshape(Y_flat, K, L, nTxAnts);
    
    txGrid(idx_start:idx_end, :, :) = Y_subband;
end

[txWaveform, waveformInfo] = nrOFDMModulate(carrier, txGrid);

% -----------------------------------------------------------------
% Channel
% -----------------------------------------------------------------
rxWaveform = channel(txWaveform);

% -----------------------------------------------------------------
% RX and Calculate BER
% -----------------------------------------------------------------
rxBits = rxPDSCHDecode(carrier, pdsch, rxWaveform, txWaveform, TBS);

numErrors = biterr(double(inputBits), double(rxBits));
BER = numErrors / TBS;

fprintf('SNR: %d dB | BER: %.5f. \n', SNR_dB, BER);
