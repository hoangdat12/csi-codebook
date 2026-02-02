function [out, hasError] = PDSCHDecode(pdsch, carrier, eqSymbols, TBS, SNR_dB)
    demappedSym_Cell = nrLayerDemap(eqSymbols);
    sym_to_demod = demappedSym_Cell{1}; 

    noiseVar = 10^(-SNR_dB/10); 
    rawLLR = nrSymbolDemodulate(sym_to_demod, pdsch.Modulation, noiseVar);

    if isempty(pdsch.NID), nid = carrier.NCellID; else, nid = pdsch.NID(1); end
    c_seq_rx = nrPDSCHPRBS(nid, pdsch.RNTI, 0, length(rawLLR));

    descrambledBits = rawLLR .* (1 - 2*double(c_seq_rx));

    rv = 0; 
    raterecovered = nrRateRecoverLDPC(descrambledBits, TBS, pdsch.TargetCodeRate, ...
                                    rv, pdsch.Modulation, pdsch.NumLayers);

    crcEnc_dummy = zeros(TBS + 24, 1); 
    bgn_rx = baseGraphSelection(crcEnc_dummy, pdsch.TargetCodeRate);

    [decBits, ~] = nrLDPCDecode(raterecovered, bgn_rx, 25);

    [rxPart, ~] = nrCodeBlockDesegmentLDPC(decBits, bgn_rx, TBS + 24);

    [out, hasError] = nrCRCDecode(rxPart, '24A');
end