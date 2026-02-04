% -----------------------------------------------------------------
% This function performs the full PDSCH encoding chain:
% CRC -> Segmentation -> LDPC Encode -> Rate Match -> Scramble -> Modulate
% It return:
%   - out: The layer-mapped complex symbols
%   - pdschInd: The PDSCH indices for grid mapping
% -----------------------------------------------------------------
function [out, pdschInd] = PDSCHEncode(pdsch, carrier, inputBits)

    % -----------------------------------------------------------------
    % PREPARATION & INDICES
    % -----------------------------------------------------------------
    % Generate PDSCH indices and information structure
    [pdschInd, indinfo] = nrPDSCHIndices(carrier, pdsch);
    
    % The maximum available bits for PDSCH (G)
    G = indinfo.G;  

    % -----------------------------------------------------------------
    % CODING CHAIN
    % -----------------------------------------------------------------
    % 1. CRC Encoding (Type 24A)
    crcEncoded = nrCRCEncode(inputBits, '24A');
    
    % 2. LDPC Base Graph Selection
    % Note: Requires 'baseGraphSelection' helper function
    bgn = baseGraphSelection(crcEncoded, pdsch.TargetCodeRate);
    
    % 3. Code Block Segmentation
    cbs = nrCodeBlockSegmentLDPC(crcEncoded, bgn);
    
    % 4. LDPC Encoding
    codedcbs = nrLDPCEncode(cbs, bgn);

    % 5. Rate Matching
    % Redundancy version (RV) is set to 0 for initial transmission
    rv = 0;
    ratematched = nrRateMatchLDPC(codedcbs, G, rv, pdsch.Modulation, pdsch.NumLayers);

    % -----------------------------------------------------------------
    % SCRAMBLING & MODULATION
    % -----------------------------------------------------------------
    % Determine Scrambling ID (use Cell ID if pdsch.NID is empty)
    if isempty(pdsch.NID)
        nid = carrier.NCellID;
    else
        nid = pdsch.NID(1);
    end
    
    rnti = pdsch.RNTI;

    % Generate PDSCH PRBS sequence
    c = nrPDSCHPRBS(nid, rnti, 0, length(ratematched));
    
    % Apply Scrambling (XOR operation via modulo 2)
    scrambled = mod(ratematched + c, 2);

    % Symbol Modulation (QPSK, 16QAM, etc.)
    modulated = nrSymbolModulate(scrambled, pdsch.Modulation);

    % -----------------------------------------------------------------
    % LAYER MAPPING
    % -----------------------------------------------------------------
    % Map symbols to spatial layers
    out = nrLayerMap(modulated, pdsch.NumLayers);    
end