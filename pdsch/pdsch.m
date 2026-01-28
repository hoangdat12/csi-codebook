function outSignals = pdsch(inputBits, pdschConfig, carrierConfig)
    % Get config parameter
    targetCodeRate = pdschConfig.TargetCodeRate;
    rv = pdschConfig.RedundancyVersion;
    nLayers = pdschConfig.NumLayers;
    
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
    if isempty(pdschConfig.NID)
        nid = carrierConfig.NCellID;
    else
        nid = pdschConfig.NID(1);
    end
    rnti = pdschConfig.RNTI;

    c_init = (double(rnti) * 2^15) + (double(0) * 2^14) + double(nid);
    scrambledBits = scrambling(codeBlockConcatenation, c_init);

    % Modulation
    modSymbols = modulation(scrambledBits, modType);

    % Layer Mapping
    layersMappedSymbols = layerMapping(modSymbols, nLayers);

    cfg = struct();
    cfg.CodebookConfig.N1 = 4;
    cfg.CodebookConfig.N2 = 2;
    cfg.CodebookConfig.O1 = 4;
    cfg.CodebookConfig.O2 = 4;
    cfg.CodebookConfig.NumberOfBeams = 4; % L = 4
    cfg.CodebookConfig.PhaseAlphabetSize = 8; % Npsk = 8
    cfg.CodebookConfig.SubbandAmplitude = true;
    cfg.CodebookConfig.numLayers = nLayers;

    % -----------------------------------------------------------
    % PMI Report simulation from UE
    % i1: Wideband indices (spatial beams)
    % i2: Subband indices (co-phasing and amplitude)
    % -----------------------------------------------------------
    i11 = [2, 1];
    i12 = 2;
    i13 = [3, 1];
    i14 = [4, 6, 5, 0, 2, 3, 1 ; 3, 2, 4, 1, 5, 6, 0];
    i21 = [1, 3, 4, 2, 5, 7 ; 2, 0, 5, 1, 4, 6];
    i22 = [0, 1, 0, 1, 0 ; 1, 1, 0, 0, 1];

    i1 = {i11, i12, i13, i14};
    i2 = {i21, i22};

    % -----------------------------------------------------------
    % PRECODING MATRIX GENERATION
    % Matrix W dimensions: [numberOfPorts x nLayers] -> [16 x 2]
    % Type II Precoding creates a non-orthogonal matrix.
    % -----------------------------------------------------------
    W = generateTypeIIPrecoder(cfg, i1, i2);

    precoded = precoding(layersMappedSymbols, W);
    
    % Output
    outSignals = precoded;
end
