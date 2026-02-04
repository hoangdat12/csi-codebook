function [BER1, BER2] = muMimo(...
    carrier, basePDSCHConfig, ...
    UE1Infor, UE2Infor, SNR_dB ...
)
    
    % -----------------------------------------------------------------
    % UE1 Configuration
    % -----------------------------------------------------------------
    pdsch = basePDSCHConfig; 

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

    % UE Precoding matrix after measurement CSI
    UE1_W = UE1Infor.W;
    UE2_W = UE2Infor.W;

    % Update MCS 
    % The value based on the Table 5.1.3.1 - 138 214
    % 11 -> 64QAM & 466/1024 Target code Rate
    % 6 -> 16QAM & 434/1024 Target code Rate
    pdsch = pdsch.setMCS(UE1Infor.MCS);
    pdsch2 = pdsch2.setMCS(UE2Infor.MCS);

    % The UE specific channel
    UE1_Channel = UE1Infor.channel;
    UE2_Channel = UE2Infor.channel;

    % % -----------------------------------------------------------------
    % % MMSE Equalization
    % % -----------------------------------------------------------------
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
    % rxWaveformUE1 = channelPropagateAndSync( ...
    %         txWaveform, carrier, UE1_Channel, dmrsInd, dmrsSym, SNR_dB);

    % rxWaveformUE2 = channelPropagateAndSync( ...
    %         txWaveform, carrier, UE2_Channel, dmrsInd2, dmrsSym2, SNR_dB);

    rxWaveformUE1 = UE1_Channel(txWaveform);
    rxWaveformUE2 = UE2_Channel(txWaveform);

    % -----------------------------------------------------------------
    % RX
    % -----------------------------------------------------------------

    % -----------------------------------------------------------------
    % Extract data for UE1
    % -----------------------------------------------------------------
    % OFDM Demodulation
    rxGrid1 = nrOFDMDemodulate(carrier, rxWaveformUE1);

    refDmrsSym1 = nrPDSCHDMRS(carrier, pdsch);
    refDmrsInd1 = nrPDSCHDMRSIndices(carrier, pdsch);

    % Estimate
    [Hest1, nVar1] = nrChannelEstimate(carrier, rxGrid1, refDmrsInd1, refDmrsSym1);

    % Extract data
    [pdschRx1, pdschHest1] = nrExtractResources(pdschInd, rxGrid1, Hest1);
    eqSymbols1 = nrEqualizeMMSE(pdschRx1, pdschHest1, nVar1);

    TBS1 = length(inputBits);
    [rxBits1, ~] = PDSCHDecode(pdsch, carrier, eqSymbols1, TBS1, SNR_dB);

    % Compute BER
    numErrors1 = biterr(double(inputBits(:)), double(rxBits1(:)));
    BER1 = numErrors1 / TBS1;

    % -----------------------------------------------------------------
    % Extract Data for UE2
    % -----------------------------------------------------------------

    % OFDM Demodulation
    rxGrid2 = nrOFDMDemodulate(carrier, rxWaveformUE2);

    % Extract DMRS
    refDmrsSym2 = nrPDSCHDMRS(carrier, pdsch2); 
    refDmrsInd2 = nrPDSCHDMRSIndices(carrier, pdsch2); 

    % Estimate
    [Hest2, nVar2] = nrChannelEstimate(carrier, rxGrid2, refDmrsInd2, refDmrsSym2);

    % Extract PDSCH Data
    [pdschRx2, pdschHest2] = nrExtractResources(pdschInd2, rxGrid2, Hest2); 
    eqSymbols2 = nrEqualizeMMSE(pdschRx2, pdschHest2, nVar2);

    TBS2 = length(inputBits2);
    [rxBits2, ~] = PDSCHDecode(pdsch2, carrier, eqSymbols2, TBS2, SNR_dB);

    % Compute BER
    numErrors2 = biterr(double(inputBits2(:)), double(rxBits2(:)));
    BER2 = numErrors2 / TBS2;
end