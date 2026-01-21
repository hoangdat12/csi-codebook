function outSignals = pdsch(inputBits, pdschConfig, carrierConfig)

    % Get config parameter
    targetCodeRate = pdschConfig.TargetCodeRate;
    rv = pdschConfig.RedundancyVersion;
    nLayers = pdschConfig.NumLayers;
    nID = pdschConfig.NID;
    nRNTI = pdschConfig.RNTI;
    
    switch pdschConfig.Modulation
        case 'QPSK',   Qm = 2;
        case '16QAM',  Qm = 4;
        case '64QAM',  Qm = 6;
        case '256QAM', Qm = 8;
        otherwise,     Qm = 2; 
    end

    % CRC Attach
    if length(inputBits) > 3824, crcPoly = '24A'; else, crcPoly = '16'; end
    tbCrcBits = createCRC(inputBits, crcPoly);
    tbCrcAttached = [inputBits; tbCrcBits];
    
    % Selection baseGraph for LDPC encoded
    bgn = baseGraphSelection(inputBits, targetCodeRate);
    
    % Segmentation transport block
    cbs = cbSegmentation(tbCrcAttached, bgn);
    encodedBits = nrLDPCEncode(cbs, bgn);    

    % Convert from QM to get moduation Type
    switch Qm
        case 1, modType = 'BPSK';
        case 2, modType = 'QPSK';
        case 4, modType = '16QAM';
        case 6, modType = '64QAM';
        case 8, modType = '256QAM';
        otherwise, error('Unsupported Modulation Order Qm');
    end

    % Calculation the maximum bit can be sent 
    G = pdschConfig.calculateManualG();
    rmBitsCell = rateMatching(encodedBits, G, rv, modType, nLayers);
    
    % Concatenation
    codeBlockConcatenation = concentration(rmBitsCell);

    % Scrambling
    c_init = double(nRNTI) * 2^15 + q * 2^14 + double(nID);
    scrambledBits = scrambling(codeBlockConcatenation, c_init);

    % Modulation
    modSymbols = modulation(scrambledBits, modType);

    % Layer Mapping
    layersMappedSymbols = layerMapping(modSymbols, nLayers);

    % Get codebook config
    cbConfig = pdschConfig.CodebookConfig;
    
    % Identify the number of antenna
    if isfield(cbConfig, 'n1')
        nTxAnts = 2 * cbConfig.n1 * cbConfig.n2;
    else
        nTxAnts = nLayers; 
    end
    
    % Compute Precoding Matrix
    W = getPrecodingMatrix(cbConfig, PMI, nLayers, nTxAnts);
    
    % Port Mapping
    antennaPortMappedSyms = layersMappedSymbols * W.';
    
    % Output
    outSignals = antennaPortMappedSyms;
end
