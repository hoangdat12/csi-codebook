function [BER1, BER2] = muMIMO2UE(baseConfig, W1, W2, SNR_dB) 
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

    % ── Encode ───────────────────────────────────────────────────────────
    TBS1       = manualCalculateTBS(pdsch1);
    TBS2       = manualCalculateTBS(pdsch2);
    inputBits1 = ones(TBS1, 1);
    inputBits2 = zeros(TBS2, 1);

    [layerMappedSym1, pdschInd1] = myPDSCHEncode(pdsch1, carrier, inputBits1);
    [layerMappedSym2, pdschInd2] = myPDSCHEncode(pdsch2, carrier, inputBits2);

    dmrsSym1 = genDMRS(carrier, pdsch1);   dmrsInd1 = DMRSIndices(pdsch1, carrier);
    dmrsSym2 = genDMRS(carrier, pdsch2);   dmrsInd2 = DMRSIndices(pdsch2, carrier);

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

    layerFlat_UE1   = reshape(layerGrid_UE1, K*symbolsPerSlot, nLayers1);
    layerFlat_UE2   = reshape(layerGrid_UE2, K*symbolsPerSlot, nLayers2);
    portFlat_UE1    = layerFlat_UE1 * W1.';   % [K*T x nPorts]
    portFlat_UE2    = layerFlat_UE2 * W2.';
    portFlat        = portFlat_UE1 + portFlat_UE2;

    portGrid        = reshape(portFlat, K, symbolsPerSlot, nPorts);

    txdataF_test  = subcarrierMap(portGrid(:,:,1), NFFT);
    txTest        = ofdmModulation(txdataF_test, NFFT);
    samplePerSlot = length(txTest);          % lấy size thực từ hàm của bạn
    txWaveform    = zeros(samplePerSlot, nPorts);
    for p = 1:nPorts
        txdataF_p        = subcarrierMap(portGrid(:,:,p), NFFT);
        txWaveform(:, p) = ofdmModulation(txdataF_p, NFFT);
    end
    for p = 1:nPorts
        txdataF_p        = subcarrierMap(portGrid(:,:,p), NFFT);  % [NFFT x nSymbols]
        txWaveform(:, p) = ofdmModulation(txdataF_p, NFFT);
    end

    nRx = 4;   
    [rxWaveform_UE1, H1_path, H1_info] = applyCDLChannel(txWaveform, carrier, nRx, 'CDL-A', 1);
    [rxWaveform_UE2, H2_path, H2_info] = applyCDLChannel(txWaveform, carrier, nRx, 'CDL-A', 2);

    if nargin < 4 || isempty(SNR_dB)
        noiseVarEst1 = eps;
        noiseVarEst2 = eps;
    else
        % Tính Noise riêng biệt cho từng UE để đảm bảo độ chính xác LLR
        signalPower1 = mean(abs(rxWaveform_UE1(:)).^2);
        noisePower1  = signalPower1 / (10^(SNR_dB/10));
        noiseVarEst1 = noisePower1;
        
        signalPower2 = mean(abs(rxWaveform_UE2(:)).^2);
        noisePower2  = signalPower2 / (10^(SNR_dB/10));
        noiseVarEst2 = noisePower2;

        % Thêm AWGN vào mỗi UE riêng
        rxWaveform_UE1 = awgn(rxWaveform_UE1, SNR_dB, 'measured');
        rxWaveform_UE2 = awgn(rxWaveform_UE2, SNR_dB, 'measured');
    end

    % ── RX Decode ─────────────────────────────────────────────────────────
    [rxBits1, ~] = rxPDSCHDecode(carrier, pdsch1, rxWaveform_UE1, TBS1, NFFT, noiseVarEst1);
    [rxBits2, ~] = rxPDSCHDecode(carrier, pdsch2, rxWaveform_UE2, TBS2, NFFT, noiseVarEst2);

    numErrors  = biterr(double(inputBits1), double(rxBits1));
    BER1       = numErrors / TBS1;
    numErrors2 = biterr(double(inputBits2), double(rxBits2));
    BER2       = numErrors2 / TBS2;
end

% Cập nhật hàm rxPDSCHDecode thêm tham số noiseVar
function [rxBits, eqSymbols, Hest] = rxPDSCHDecode(carrier, pdsch, rxWaveform, TBS, NFFT, noiseVar)
    K              = carrier.NSizeGrid * 12;
    symbolsPerSlot = carrier.SymbolsPerSlot;
    nPorts         = size(rxWaveform, 2);
    nLayers        = pdsch.NumLayers;

    % ── OFDM demodulate ───────────────────────────────────────────────
    rxGrid = zeros(K, symbolsPerSlot, nPorts);
    for p = 1:nPorts
        rxdataF_p     = ofdmDemodulation(rxWaveform(:, p), NFFT, K, ...
                                         carrier.SubcarrierSpacing);
        rxGrid(:,:,p) = rxdataF_p(:, 1:symbolsPerSlot);
    end

    % ── Lấy PDSCH RE của UE cần decode ────────────────────────────────
    pdschInd = nrPDSCHIndices(carrier, pdsch);
    planeSize = K * symbolsPerSlot;

    % Nếu index có offset theo layer thì bỏ offset
    pdschInd2D = pdschInd(:,1);
    if any(pdschInd2D > planeSize)
        pdschInd2D = pdschInd2D - 0*planeSize;   % cột 1 -> layer 1
    end

    nRE = size(pdschInd, 1);
    pdschRx = zeros(nRE, nPorts);
    for p = 1:nPorts
        grid_p        = rxGrid(:,:,p);
        pdschRx(:, p) = grid_p(pdschInd2D);
    end

    % ── DMRS-based channel estimation ─────────────────────────────────
    HportLayer = estimateChannelFromDMRS(rxGrid, carrier, pdsch);

    % Kênh lý tưởng hiện tại: replicate cho toàn bộ RE PDSCH
    Hest = repmat(reshape(HportLayer, [1, nPorts, nLayers]), [nRE, 1, 1]);

    % Sử dụng noiseVar thực tế được truyền xuống thay vì cố định là eps
    eqSymbols = nrEqualizeMMSE(pdschRx, Hest, noiseVar);
    rxBits    = PDSCHDecode(pdsch, carrier, eqSymbols, TBS, noiseVar);
end

function HportLayer = estimateChannelFromDMRS(rxGrid, carrier, pdsch)
    K              = carrier.NSizeGrid * 12;
    symbolsPerSlot = carrier.SymbolsPerSlot;
    planeSize      = K * symbolsPerSlot;

    nPorts  = size(rxGrid, 3);
    nLayers = pdsch.NumLayers;

    dmrsInd = DMRSIndices(pdsch, carrier);   % [nDmrsRE x nLayers]
    dmrsTx  = genDMRS(carrier, pdsch);       % [nDmrsRE x nLayers]

    HportLayer = zeros(nPorts, nLayers);

    for l = 1:nLayers
        % Bỏ offset theo layer để map về mặt phẳng 2D [K x symbolsPerSlot]
        ind2D = dmrsInd(:, l);
        if any(ind2D > planeSize)
            ind2D = ind2D - (l-1)*planeSize;
        end

        for p = 1:nPorts
            rxTmp = rxGrid(:,:,p);
            y = rxTmp(ind2D);
            x = dmrsTx(:, l);

            h_ls = y ./ x;
            HportLayer(p, l) = mean(h_ls);
        end
    end
end

function rxdataF = ofdmDemodulation(rxdata, NFFT, K, SCS)
    mu          = log2(SCS / 15);          % numerology
    cp_samples0 = round(176 * NFFT / 2048);
    cp_samples  = round(144 * NFFT / 2048);
    nSymPerSlot = 14;                      % normal CP, one slot
    rxdataF = zeros(K, nSymPerSlot);
    idx     = 0;
    for i = 1:nSymPerSlot
        if mod(i, 7 * 2^mu) == 1
            cp_len = cp_samples0;
        else
            cp_len = cp_samples;
        end
        sym_start = idx + cp_len + 1;
        sym_end   = sym_start + NFFT - 1;
        time_sym  = rxdata(sym_start : sym_end);
        freq_sym  = fft(time_sym, NFFT);
        half      = K / 2;
        rxdataF(:, i) = [freq_sym(2 : half+1);                    % positive
                         freq_sym(NFFT - half + 1 : NFFT)];       % negative
        idx = idx + cp_len + NFFT;
    end
end

function txdataF = subcarrierMap(grid_K_T, NFFT)
    [K, nSym] = size(grid_K_T);
    half       = K / 2;
    txdataF    = zeros(NFFT, nSym);
    txdataF(2 : half+1,            :) = grid_K_T(1:half,      :);
    txdataF(NFFT-half+1 : NFFT,   :) = grid_K_T(half+1:end,  :);
end

function NFFT = computeNFFT(SCS)
    base = 2048;  % SCS=15 kHz
    NFFT = base * SCS / 15;
end

%% ── applyCDLChannel.m ────────────────────────────────────────────────────
function [rxWaveform, pathGains, pathFilters] = applyCDLChannel(txWaveform, carrier, nRx, profile, seed)
    % txWaveform: [nSamples x nTx]  nTx=32
    % rxWaveform: [nSamples x nRx]

    nTx = size(txWaveform, 2);   % 32
    SCS = carrier.SubcarrierSpacing * 1e3;   % Hz
    sampleRate = computeNFFT(carrier.SubcarrierSpacing) * SCS;

    cdl = nrCDLChannel;
    cdl.DelayProfile        = profile;          % 'CDL-A'
    cdl.DelaySpread         = 30e-9;            % 30 ns
    cdl.CarrierFrequency    = 3.5e9;            % 3.5 GHz (FR1)
    cdl.MaximumDopplerShift = 5;                % 5 Hz (UE tốc độ thấp)
    cdl.SampleRate          = sampleRate;
    cdl.TransmitAntennaArray.Size  = [nTx, 1, 1, 1, 1];
    cdl.ReceiveAntennaArray.Size   = [nRx, 1, 1, 1, 1];
    cdl.NormalizePathGains  = true;
    cdl.NormalizeChannelOutputs = false;
    cdl.RandomStream        = 'mt19937ar with seed';
    cdl.Seed                = seed * 100;       % seed khác nhau cho UE1/UE2

    [rxWaveform, pathGains, pathFilters] = cdl(txWaveform);
end
