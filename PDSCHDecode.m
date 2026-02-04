% -----------------------------------------------------------------
% This function performs the full PDSCH decoding chain
% It return:
%   - out: The decoded transport block bits
%   - hasError: CRC error flag (0 = Success, 1 = Error)
% -----------------------------------------------------------------
function [out, hasError] = PDSCHDecode(pdsch, carrier, eqSymbols, TBS, SNR_dB)

    % -----------------------------------------------------------------
    % DEMODULATION & DESCRAMBLING
    % -----------------------------------------------------------------
    % Layer demapping (Extract the first codeword)
    demappedSym_Cell = nrLayerDemap(eqSymbols);
    sym_to_demod = demappedSym_Cell{1}; 

    % Calculate noise variance from SNR
    noiseVar = 10^(-SNR_dB/10); 

    % Symbol demodulation to get LLRs
    rawLLR = nrSymbolDemodulate(sym_to_demod, pdsch.Modulation, noiseVar);

    % Determine Scrambling ID
    if isempty(pdsch.NID)
        nid = carrier.NCellID; 
    else
        nid = pdsch.NID(1); 
    end
    
    % Generate scrambling sequence
    c_seq_rx = nrPDSCHPRBS(nid, pdsch.RNTI, 0, length(rawLLR));

    % Descramble LLRs (Flip sign where scrambling bit is 1)
    descrambledBits = rawLLR .* (1 - 2*double(c_seq_rx));

    % -----------------------------------------------------------------
    % RATE RECOVERY
    % -----------------------------------------------------------------
    % Redundancy version (RV)
    rv = 0; 

    % Recover rate matched bits
    raterecovered = nrRateRecoverLDPC(descrambledBits, TBS, pdsch.TargetCodeRate, ...
                                      rv, pdsch.Modulation, pdsch.NumLayers);

    % -----------------------------------------------------------------
    % DECODING CHAIN (LDPC & CRC)
    % -----------------------------------------------------------------
    % Determine Base Graph Number (BGN)
    % We create a dummy array of size (TBS + 24) to select the correct graph
    crcEnc_dummy = zeros(TBS + 24, 1); 
    bgn_rx = baseGraphSelection(crcEnc_dummy, pdsch.TargetCodeRate);

    % LDPC Decoding (Max 25 iterations)
    MAX_ITER = 25;
    [decBits, ~] = nrLDPCDecode(raterecovered, bgn_rx, MAX_ITER);

    % Code Block Desegmentation
    [rxPart, ~] = nrCodeBlockDesegmentLDPC(decBits, bgn_rx, TBS + 24);

    % CRC Decoding
    [out, hasError] = nrCRCDecode(rxPart, '24A');
end