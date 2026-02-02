function [out, pdschInd] = PDSCHEncode(pdsch, carrier, inputBits)
    [pdschInd, indinfo] = nrPDSCHIndices(carrier, pdsch);
    G = indinfo.G;  

    crcEncoded = nrCRCEncode(inputBits,'24A');
    bgn = baseGraphSelection(crcEncoded, pdsch.TargetCodeRate);
    cbs = nrCodeBlockSegmentLDPC(crcEncoded, bgn);
    codedcbs = nrLDPCEncode(cbs, bgn);

    rv = 0;
    ratematched = nrRateMatchLDPC(codedcbs, G, rv, pdsch.Modulation, pdsch.NumLayers);

    if isempty(pdsch.NID)
        nid = carrier.NCellID;
    else
        nid = pdsch.NID(1);
    end
    rnti = pdsch.RNTI;

    c = nrPDSCHPRBS(nid, rnti, 0, length(ratematched));
    scrambled = mod(ratematched + c, 2);

    modulated = nrSymbolModulate(scrambled, pdsch.Modulation);

    out = nrLayerMap(modulated, pdsch.NumLayers);    
end

% function [antsym, antind] = PDSCHToolbox(pdschConfig, carrier, inputBits)
%     setupPath();   

%     nlayers = pdschConfig.NumLayers;

%     % -----------------------------------------------------------
%     % Calculate the available resources for PDSCH.
%     % The output 'G' is the maximum number of coded bits required 
%     %   after rate matching.
%     % -----------------------------------------------------------
%     [pdschInd, indinfo] = nrPDSCHIndices(carrier, pdschConfig);
%     G = indinfo.G;  

%     % -----------------------------------------------------------
%     % LDPC Coding Chain (3GPP TS 38.212)
%     % 1. CRC Attachment
%     % 2. Base Graph Selection
%     % 3. Code Block Segmentation
%     % 4. LDPC Encoding
%     % 5. Rate Matching
%     % -----------------------------------------------------------
%     crcEncoded = nrCRCEncode(inputBits,'24A');
%     bgn = baseGraphSelection(crcEncoded, pdschConfig.TargetCodeRate);
%     cbs = nrCodeBlockSegmentLDPC(crcEncoded, bgn);
%     codedcbs = nrLDPCEncode(cbs, bgn);

%     rv = 0;
%     ratematched = nrRateMatchLDPC(codedcbs, G, rv, pdschConfig.Modulation, nlayers);

%     % -----------------------------------------------------------
%     % Scrambling and Symbol Modulation
%     % Generating scrambled bits using NCellID and RNTI.
%     % -----------------------------------------------------------
%     if isempty(pdschConfig.NID)
%         nid = carrier.NCellID;
%     else
%         nid = pdschConfig.NID(1);
%     end
%     rnti = pdschConfig.RNTI;

%     c = nrPDSCHPRBS(nid, rnti, 0, length(ratematched));
%     scrambled = mod(ratematched + c, 2);

%     modulated = nrSymbolModulate(scrambled, pdschConfig.Modulation);

%     layerMappedSym = nrLayerMap(modulated, nlayers);
%     fprintf('Layer Mapping ::::: %d x %d \n\n', size(layerMappedSym));

%     % -----------------------------------------------------------
%     % PRECODING MATRIX GENERATION
%     % Matrix W dimensions: [numberOfPorts x nLayers] -> [16 x 2]
%     % Type II Precoding creates a non-orthogonal matrix.
%     % -----------------------------------------------------------
%     W = generateTypeIIPrecoder(pdschConfig, pdschConfig.Indices.i1, pdschConfig.Indices.i2);

%     % The function nrPDSCHPrecode requires the W matrix format: [nLayers x nPorts].
%     W_transposed = W.';

%     % antsym = [NRE x P]
%     % NRE = NRB x 12 x nsymbol
%     [antsym, antind] = nrPDSCHPrecode(carrier, layerMappedSym, pdschInd, W_transposed);

%     fprintf('Precoding ::::: %d x %d \n\n', size(antsym));
% end

