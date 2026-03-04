clear; clc; close all;

setupPath();

PMIUE1.i1 = { [3 0], 0, [3 2], [6,3,5,7;4,6,7,7] };
PMIUE1.i2 = { [1,1,2,0;2,3,0,0], [1,1,1,1;1,1,1,1] };

PMIUE2.i1 = { [3 0], 5, [3 0], [5,4,5,7;7,4,1,6] };
PMIUE2.i2 = { [2,0,3,0;0,2,1,0], [1,1,1,1;1,1,1,1] };

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

W1 = generateTypeIIPrecoder(cfg, PMIUE1.i1, PMIUE1.i2, true);
W2 = generateTypeIIPrecoder(cfg, PMIUE2.i1, PMIUE2.i2, true);

if nLayers == 2
    THREAD_HOLD = 1e-15;
elseif nLayers == 3
    THREAD_HOLD = 1e-2;
else
    THREAD_HOLD = 1e-2;
end

BER_THREAD_HOLD = 10e-9;

pdsch = customPDSCHConfig;
pdsch.DMRS.DMRSConfigurationType = 1;
pdsch.DMRS.DMRSAdditionalPosition = 1;
pdsch.NumLayers = nLayers;
pdsch.PRBSet = 0:272;

carrier = nrCarrierConfig;
carrier.SubcarrierSpacing = 30;
% With 273 RB, we need scs 30 
carrier.NSizeGrid = 273;

[BER1, BER2] = muMimo(...
    carrier, pdsch, ...
    W1, W2, MCS, 20 ...
);

disp(BER1);
disp(BER2);

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
    rxWaveformUE1 = txWaveform;
    rxWaveformUE2 = txWaveform;

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