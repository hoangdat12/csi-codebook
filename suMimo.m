function [BER, UEInfor] = suMimo(carrier, basePDSCHConfig, UEInfor, SNR_dB, isLowerMCS)
    % -----------------------------------------------------------------
    % Input Parameters
    % -----------------------------------------------------------------
    if nargin < 5
        isLowerMCS = false;
    end

    % -----------------------------------------------------------------
    % PDSCH Configuration
    % -----------------------------------------------------------------
    pdsch = basePDSCHConfig; 

    % -----------------------------------------------------------------
    % Generate Bits
    % -----------------------------------------------------------------
    [~, pdschInfo] = nrPDSCHIndices(carrier, pdsch);
    NREPerPRB = pdschInfo.NREPerPRB;

    TBS = nrTBS(pdsch.Modulation, pdsch.NumLayers, ...
                length(pdsch.PRBSet), NREPerPRB, pdsch.TargetCodeRate);
    inputBits = randi([0 1], TBS, 1);

    % -----------------------------------------------------------------
    % TX
    % -----------------------------------------------------------------
    % UE Precoding matrix after measurement CSI
    UE_W = UEInfor.W;
    W_transposed = UE_W.';

    % Update MCS 
    % The value based on the Table 5.1.3.1 - 138 214
    % 11 -> 64QAM & 466/1024 Target code Rate
    % 6 -> 16QAM & 434/1024 Target code Rate

    % If the falg isLowerMCS is enable
    % Reduce MCS by 3 times
    % If MCS < 0 => set 0
    if isLowerMCS
        oldMCS = UEInfor.MCS;

        newMCS = max(0, oldMCS - 5);
        UEInfor.MCS = newMCS;
        
        pdsch = pdsch.setMCS(newMCS);
    else
        pdsch = pdsch.setMCS(UEInfor.MCS);
    end
    % -----------------------------------------------------------------
    % PDSCH Modulation
    % -----------------------------------------------------------------
    [layerMappedSym, pdschInd] = PDSCHEncode(pdsch, carrier, inputBits);

    [antsym, antind] = nrPDSCHPrecode(carrier, layerMappedSym, pdschInd, W_transposed);
    dmrsSym = nrPDSCHDMRS(carrier, pdsch);
    dmrsInd = nrPDSCHDMRSIndices(carrier, pdsch);
    [dmrsAntSym, dmrsAntInd] = nrPDSCHPrecode(carrier, dmrsSym, dmrsInd, W_transposed);

    numPorts = size(W_transposed, 2);
    txGrid = nrResourceGrid(carrier, numPorts); 

    txGrid(antind) = antsym;
    txGrid(dmrsAntInd) = dmrsAntSym;  

    txWaveform = nrOFDMModulate(carrier, txGrid);

    % -----------------------------------------------------------------
    % Channel
    % -----------------------------------------------------------------
    channel = UEInfor.channel;
    rxWaveform = channel(txWaveform);


    % -----------------------------------------------------------------
    % RX and Calculate BER
    % -----------------------------------------------------------------
    rxGrid = nrOFDMDemodulate(carrier, rxWaveform);

    refDmrsSym = nrPDSCHDMRS(carrier, pdsch);
    
    refDmrsInd = nrPDSCHDMRSIndices(carrier, pdsch);

    [Hest, nVar] = nrChannelEstimate(carrier, rxGrid, refDmrsInd, refDmrsSym);

    [pdschRx, pdschHest] = nrExtractResources(pdschInd, rxGrid, Hest);

    eqSymbols = nrEqualizeMMSE(pdschRx, pdschHest, nVar);

    TBS = length(inputBits);
    rxBits = PDSCHDecode(pdsch, carrier, eqSymbols, TBS, SNR_dB);
    numErrors = biterr(double(inputBits(:)), double(rxBits(:)));
    
    BER = numErrors / TBS;
end