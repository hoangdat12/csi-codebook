function out = PDSCHToolbox(pdschConfig, carrier, bitRate, nlayers, inputBits)
    setupPath();   

    % -----------------------------------------------------------
    % Calculate the available resources for PDSCH.
    % The output 'G' is the maximum number of coded bits required 
    %   after rate matching.
    % -----------------------------------------------------------
    [pdschInd, indinfo] = nrPDSCHIndices(carrier, pdschConfig);
    G = indinfo.G;  

    disp(G);

    % -----------------------------------------------------------
    % LDPC Coding Chain (3GPP TS 38.212)
    % 1. CRC Attachment
    % 2. Base Graph Selection
    % 3. Code Block Segmentation
    % 4. LDPC Encoding
    % 5. Rate Matching
    % -----------------------------------------------------------
    crcEncoded = nrCRCEncode(inputBits,'24A');
    bgn = baseGraphSelection(crcEncoded, bitRate);
    cbs = nrCodeBlockSegmentLDPC(crcEncoded, bgn);
    codedcbs = nrLDPCEncode(cbs, bgn);

    rv = 0;
    ratematched = nrRateMatchLDPC(codedcbs, G, rv, pdschConfig.Modulation, nlayers);

    % -----------------------------------------------------------
    % Scrambling and Symbol Modulation
    % Generating scrambled bits using NCellID and RNTI.
    % -----------------------------------------------------------
    if isempty(pdschConfig.NID)
        nid = carrier.NCellID;
    else
        nid = pdschConfig.NID(1);
    end
    rnti = pdschConfig.RNTI;

    c = nrPDSCHPRBS(nid, rnti, 0, length(ratematched));
    scrambled = mod(ratematched + c, 2);

    modulated = nrSymbolModulate(scrambled, pdschConfig.Modulation);

    layerMappedSym = nrLayerMap(modulated, nlayers);

    disp(size(layerMappedSym));

    % -----------------------------------------------------------
    % TYPE II CSI REPORT CONFIGURATION (3GPP TS 38.214)
    % Number of antenna ports is derived as: P_csi-rs = 2 * N1 * N2
    % In this case: 2 * 4 * 2 = 16 ports.
    % -----------------------------------------------------------
    cfg = struct();
    cfg.CodebookConfig.N1 = 4;
    cfg.CodebookConfig.N2 = 2;
    cfg.CodebookConfig.O1 = 4;
    cfg.CodebookConfig.O2 = 4;
    cfg.CodebookConfig.NumberOfBeams = 4; % L = 4
    cfg.CodebookConfig.PhaseAlphabetSize = 8; % Npsk = 8
    cfg.CodebookConfig.SubbandAmplitude = true;
    cfg.CodebookConfig.numLayers = nlayers;

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

    % The function nrPDSCHPrecode requires the W matrix format: [nLayers x nPorts].
    W_transposed = W.';

    [antsym, antind] = nrPDSCHPrecode(carrier, layerMappedSym, pdschInd, W_transposed);

    % -----------------------------------------------------------
    % RESOURCE GRID MAPPING & OFDM MODULATION
    % Map the precoded symbols onto the Time-Frequency resource grid.
    % -----------------------------------------------------------
    txGrid = nrResourceGrid(carrier, size(W_transposed, 2)); 
    txGrid(antind) = antsym;

    out = txGrid;
end

