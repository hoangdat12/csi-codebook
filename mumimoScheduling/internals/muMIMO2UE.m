function [BER1, BER2] = muMIMO2UE(baseConfig, W1, W2, SNR_dB) 
% This function is a pipeline for mesurement the BER of transmit MUMIMO 2 UE.
%
% W1 and W2 must satisfy the orthogonality threshold (chordal distance
%     >= 0.9999) since the Tx/Rx chain does not apply ZF or MMSE interference
%     cancellation between UEs. Insufficient orthogonality will cause
%     inter-user interference and degrade BER directly.
%
% Pipeline: TX -> AWGN Channel -> RX
%
    
    % ------------------------------------------------------------------------
    % Conver the output to the Configuration
    % ------------------------------------------------------------------------
    nLayers = baseConfig.NLAYERS;

    carrier = nrCarrierConfig;
    carrier.SubcarrierSpacing = baseConfig.SUBCARRIER_SPACING;  
    carrier.NSizeGrid         = baseConfig.NSIZE_GRID;
    carrier.CyclicPrefix      = baseConfig.CYCLIC_PREFIX;
    carrier.NSlot             = baseConfig.NSLOT;
    carrier.NFrame            = baseConfig.NFRAME;
    carrier.NCellID           = baseConfig.NCELL_ID;

    % ── PDSCH UE1 ────────────────────────────────────────────────────────
    pdsch1 = customPDSCHConfig(); 
    pdsch1.DMRS.DMRSConfigurationType   = baseConfig.DMRS_CONFIGURATION_TYPE; 
    pdsch1.DMRS.DMRSTypeAPosition       = baseConfig.DMRS_TYPEA_POSITION; 
    pdsch1.DMRS.NumCDMGroupsWithoutData = baseConfig.DMRS_NUMCDMGROUP_WITHOUT_DATA;
    pdsch1.DMRS.DMRSLength              = baseConfig.DMRS_LENGTH;
    pdsch1.DMRS.DMRSAdditionalPosition  = baseConfig.DMRS_ADDITIONAL_POSITION;
    pdsch1.NumLayers        = nLayers;
    pdsch1.MappingType      = baseConfig.PDSCH_MAPPING_TYPE;
    pdsch1.RNTI             = baseConfig.PDSCH_RNTI;
    pdsch1.PRBSet           = baseConfig.PDSCH_PRBSET;
    pdsch1.SymbolAllocation = [baseConfig.PDSCH_START_SYMBOL, 14 - baseConfig.PDSCH_START_SYMBOL];
    pdsch1                  = pdsch1.setMCS(baseConfig.MCS);
    pdsch1.DMRS.DMRSPortSet = 0:3;
    pdsch1.DMRS.NSCID       = 0;

    % ── PDSCH UE2 ────────────────────────────────────────────────────────
    pdsch2 = customPDSCHConfig(); 
    pdsch2.DMRS.DMRSConfigurationType   = baseConfig.DMRS_CONFIGURATION_TYPE; 
    pdsch2.DMRS.DMRSTypeAPosition       = baseConfig.DMRS_TYPEA_POSITION; 
    pdsch2.DMRS.NumCDMGroupsWithoutData = baseConfig.DMRS_NUMCDMGROUP_WITHOUT_DATA;
    pdsch2.DMRS.DMRSLength              = baseConfig.DMRS_LENGTH;
    pdsch2.DMRS.DMRSAdditionalPosition  = baseConfig.DMRS_ADDITIONAL_POSITION;
    pdsch2.NumLayers        = nLayers;
    pdsch2.MappingType      = baseConfig.PDSCH_MAPPING_TYPE;
    pdsch2.RNTI             = baseConfig.PDSCH_RNTI + 1; 
    pdsch2.PRBSet           = baseConfig.PDSCH_PRBSET;
    pdsch2.SymbolAllocation = [baseConfig.PDSCH_START_SYMBOL, 14 - baseConfig.PDSCH_START_SYMBOL];
    pdsch2                  = pdsch2.setMCS(baseConfig.MCS);
    pdsch2.DMRS.DMRSPortSet = 4:7;
    pdsch2.DMRS.NSCID       = 0;

    % ------------------------------------------------------------------------
    % Based on the pdsch Configuration, calculate the Transport Block Size - TBS
    % This parameters is the maximum data bits of PDSCH.
    % ------------------------------------------------------------------------
    TBS1       = manualCalculateTBS(pdsch1);
    TBS2       = manualCalculateTBS(pdsch2);
    inputBits1 = ones(TBS1, 1);
    inputBits2 = zeros(TBS2, 1);

    % ------------------------------------------------------------------------
    % This is the process of encapsulate the TB Data from MAC -> PDSCH
    % The process include: CRC Attach -> Base Graph Selection -> Segmentation
    %   -> LDPC Encoded -> Rate Matching -> Scrambling -> Modulation 
    %   -> Layer Mapping 
    % ------------------------------------------------------------------------
    [layerMappedSym1, pdschInd1] = myPDSCHEncode(pdsch1, carrier, inputBits1);
    [layerMappedSym2, pdschInd2] = myPDSCHEncode(pdsch2, carrier, inputBits2);

    % ------------------------------------------------------------------------
    % Generate DMRS for each PDSCH channel. This signal use at the RX side for 
    %   estimate the channel and decoded the PDSCH data.
    % ------------------------------------------------------------------------
    dmrsSym1 = genDMRS(carrier, pdsch1);   dmrsInd1 = DMRSIndices(pdsch1, carrier);
    dmrsSym2 = genDMRS(carrier, pdsch2);   dmrsInd2 = DMRSIndices(pdsch2, carrier);

    % ------------------------------------------------------------------------
    % Antenna Port Mapping And Resource Mapping
    % This step use the output after the Layer Mapping and multiply with 
    %   Precoding Matrix, The matrix use the Type I CSI-RS Codebook.
    % This simulation doesn't use Interleaving between VRB and PRB.
    % ------------------------------------------------------------------------

    % ── Resource grid (manual, supports any nPorts) ───────────────────────
    nPorts        = size(W1, 1); 
    nLayers1      = pdsch1.NumLayers;
    nLayers2      = pdsch2.NumLayers;
    symbolsPerSlot = carrier.SymbolsPerSlot;          % 14
    NFFT          = computeNFFT(carrier.SubcarrierSpacing);
    K             = carrier.NSizeGrid * 12;           % useful subcarriers

    % Layer grids  [K x symbolsPerSlot x nLayers]
    layerGrid_UE1 = zeros(K, symbolsPerSlot, nLayers1);
    layerGrid_UE2 = zeros(K, symbolsPerSlot, nLayers2);

    for layer = 1:nLayers1
        layerGrid_UE1(pdschInd1(:,layer)) = layerMappedSym1(:,layer);
        layerGrid_UE1(dmrsInd1(:,layer))  = dmrsSym1(:,layer);
    end
    for layer = 1:nLayers2
        layerGrid_UE2(pdschInd2(:,layer)) = layerMappedSym2(:,layer);
        layerGrid_UE2(dmrsInd2(:,layer))  = dmrsSym2(:,layer);
    end

    % Flatten layer grids and apply precoding matrices
    layerFlat_UE1 = reshape(layerGrid_UE1, K*symbolsPerSlot, nLayers1);
    layerFlat_UE2 = reshape(layerGrid_UE2, K*symbolsPerSlot, nLayers2);
    portFlat_UE1  = layerFlat_UE1 * W1.';  % [K*T x nPorts]
    portFlat_UE2  = layerFlat_UE2 * W2.';
    portFlat      = portFlat_UE1 + portFlat_UE2;  % superimpose both UEs

    portGrid = reshape(portFlat, K, symbolsPerSlot, nPorts);

    % ------------------------------------------------------------------------
    % OFDM Modulation - 30kHZ - 4096 NFFT
    % ------------------------------------------------------------------------
    txdataF_test  = subcarrierMap(portGrid(:,:,1), NFFT);
    txTest        = ofdmModulation(txdataF_test, NFFT);
    samplePerSlot = length(txTest);
    txWaveform    = zeros(samplePerSlot, nPorts);

    % OFDM modulate all ports
    for p = 1:nPorts
        txdataF_p        = subcarrierMap(portGrid(:,:,p), NFFT);  % [NFFT x nSymbols]
        txWaveform(:, p) = ofdmModulation(txdataF_p, NFFT);
    end

    % ------------------------------------------------------------------------
    % AWGN Channels
    % ------------------------------------------------------------------------
    if nargin < 4 || isempty(SNR_dB)
        % Noiseless path: pass signal through unchanged
        rxWaveform  = txWaveform;
        noiseVarEst = eps;
    else
        % Add AWGN and estimate noise variance for the MMSE equalizer
        rxWaveform  = awgn(txWaveform, SNR_dB, 'measured');
        signalPower = mean(abs(txWaveform(:)).^2);
        noisePower  = signalPower / (10^(SNR_dB/10));
        noiseVarEst = noisePower;
    end

    % -------------------------------------------------------------------------
    % RX Side
    % Decoding pipeline: RX Waveform -> OFDM Demodulation -> Extract PDSCH REs
    %   -> DMRS-based LS Channel Estimation -> MMSE Equalization -> PDSCH Decoding
    % -------------------------------------------------------------------------
    [rxBits1, ~] = rxPDSCHDecode(carrier, pdsch1, rxWaveform, TBS1, NFFT, noiseVarEst);
    [rxBits2, ~] = rxPDSCHDecode(carrier, pdsch2, rxWaveform, TBS2, NFFT, noiseVarEst);

    % ------------------------------------------------------------------------
    % Calculate BER of each UE in the process
    % ------------------------------------------------------------------------
    numErrors  = biterr(double(inputBits1), double(rxBits1));
    BER1       = numErrors / TBS1;
    numErrors2 = biterr(double(inputBits2), double(rxBits2));
    BER2       = numErrors2 / TBS2;
end

function [rxBits, eqSymbols, Hest] = rxPDSCHDecode(carrier, pdsch, rxWaveform, TBS, NFFT, noiseVar)
% This function use to decoded the PDSCH Data at the RX side 
% Decoding Pipeline: RX Waveform -> OFDM Demodulation -> Extract PDSCH REs
%   -> DMRS-based LS Channel Estimation -> MMSE Equalization -> PDSCH Decoding

    K              = carrier.NSizeGrid * 12;
    symbolsPerSlot = carrier.SymbolsPerSlot;
    nPorts         = size(rxWaveform, 2);
    nLayers        = pdsch.NumLayers;

    % OFDM demodulate all receive ports
    rxGrid = zeros(K, symbolsPerSlot, nPorts);
    for p = 1:nPorts
        rxdataF_p     = ofdmDemodulation(rxWaveform(:, p), NFFT, K, ...
                                         carrier.SubcarrierSpacing);
        rxGrid(:,:,p) = rxdataF_p(:, 1:symbolsPerSlot);
    end

    % Extract PDSCH REs for the target UE
    pdschInd  = nrPDSCHIndices(carrier, pdsch);
    planeSize = K * symbolsPerSlot;

    % Strip layer offset if indices exceed the 2D plane size
    pdschInd2D = pdschInd(:,1);
    if any(pdschInd2D > planeSize)
        pdschInd2D = pdschInd2D - 0*planeSize;
    end

    nRE     = size(pdschInd, 1);
    pdschRx = zeros(nRE, nPorts);
    for p = 1:nPorts
        grid_p        = rxGrid(:,:,p);
        pdschRx(:, p) = grid_p(pdschInd2D);
    end

    % DMRS-based least-squares channel estimation
    HportLayer = estimateChannelFromDMRS(rxGrid, carrier, pdsch);

    % Replicate channel estimate across all PDSCH REs
    Hest = repmat(reshape(HportLayer, [1, nPorts, nLayers]), [nRE, 1, 1]);

    % MMSE equalization and PDSCH decoding
    eqSymbols = nrEqualizeMMSE(pdschRx, Hest, noiseVar);
    rxBits    = PDSCHDecode(pdsch, carrier, eqSymbols, TBS, noiseVar);
end

function HportLayer = estimateChannelFromDMRS(rxGrid, carrier, pdsch)
% This function use to perform channels estimate based on the DMRS symbols

    K              = carrier.NSizeGrid * 12;
    symbolsPerSlot = carrier.SymbolsPerSlot;
    planeSize      = K * symbolsPerSlot;

    nPorts  = size(rxGrid, 3);
    nLayers = pdsch.NumLayers;

    dmrsInd = DMRSIndices(pdsch, carrier);  % [nDmrsRE x nLayers]
    dmrsTx  = genDMRS(carrier, pdsch);      % [nDmrsRE x nLayers]

    HportLayer = zeros(nPorts, nLayers);

    for l = 1:nLayers
        % Strip layer offset to map indices into the 2D [K x symbolsPerSlot] plane
        ind2D = dmrsInd(:, l);
        if any(ind2D > planeSize)
            ind2D = ind2D - (l-1)*planeSize;
        end

        for p = 1:nPorts
            rxTmp = rxGrid(:,:,p);
            y     = rxTmp(ind2D);
            x     = dmrsTx(:, l);

            % Least-squares estimate per RE, averaged across DMRS pilots
            h_ls           = y ./ x;
            HportLayer(p,l) = mean(h_ls);
        end
    end
end

function rxdataF = ofdmDemodulation(rxdata, NFFT, K, SCS)
    mu          = log2(SCS / 15);           % numerology index
    cp_samples0 = round(176 * NFFT / 2048); % extended CP (first symbol per half-slot)
    cp_samples  = round(144 * NFFT / 2048); % normal CP
    nSymPerSlot = 14;

    rxdataF = zeros(K, nSymPerSlot);
    idx     = 0;

    for i = 1:nSymPerSlot
        % First symbol of each half-slot uses the extended CP length
        if mod(i, 7 * 2^mu) == 1
            cp_len = cp_samples0;
        else
            cp_len = cp_samples;
        end

        sym_start = idx + cp_len + 1;
        sym_end   = sym_start + NFFT - 1;
        time_sym  = rxdata(sym_start : sym_end);
        freq_sym  = fft(time_sym, NFFT);

        % Map positive and negative frequency bins to subcarrier grid
        half = K / 2;
        rxdataF(:, i) = [freq_sym(2 : half+1);              % positive frequencies
                         freq_sym(NFFT - half + 1 : NFFT)]; % negative frequencies
        idx = idx + cp_len + NFFT;
    end
end

function txdataF = subcarrierMap(grid_K_T, NFFT)
    % Map subcarrier grid onto NFFT-point frequency axis (DC-centered)
    [K, nSym] = size(grid_K_T);
    half      = K / 2;
    txdataF   = zeros(NFFT, nSym);
    txdataF(2 : half+1,          :) = grid_K_T(1:half,     :); % positive
    txdataF(NFFT-half+1 : NFFT, :) = grid_K_T(half+1:end, :); % negative
end

function NFFT = computeNFFT(SCS)
    % NFFT scales linearly with subcarrier spacing relative to 15 kHz baseline
    base = 2048;
    NFFT = base * SCS / 15;
end