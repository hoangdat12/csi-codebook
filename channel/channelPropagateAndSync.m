function [rxWaveform, rxInfo] = ...
    channelPropagateAndSync(txWaveform, carrier, channel, refInd, refSym, SNRdB)

    % ------------------------------------------------------------
    % Setup Info
    % ------------------------------------------------------------
    OFDMInfo = nrOFDMInfo(carrier);
    
    chInfo = info(channel);
    maxChDelay = ceil(max(chInfo.PathDelays * OFDMInfo.SampleRate)) ...
             + chInfo.ChannelFilterDelay;

    % ------------------------------------------------------------
    % Propagation
    % ------------------------------------------------------------
    txWaveformPad = [txWaveform; zeros(maxChDelay, size(txWaveform,2))];
    
    [rxWaveform, pathGains, sampleTimes] = channel(txWaveformPad);
    
    pathFilters = getPathFilters(channel);

    % ------------------------------------------------------------
    % Timing Sync
    % ------------------------------------------------------------
    offset = nrTimingEstimate(carrier, rxWaveform, refInd, refSym);
    
    if offset > length(rxWaveform) || offset < 0
        offset = 0; 
    end

    rxWaveform = rxWaveform(1+offset:end, :);

    % ------------------------------------------------------------
    % AWGN
    % ------------------------------------------------------------
    sigPower = mean(abs(rxWaveform).^2, 'all');
    SNR_lin = 10^(SNRdB/10);
    noiseVar = sigPower / SNR_lin;
    
    noiseScale = sqrt(noiseVar/2);
    noise = noiseScale * ...
            (randn(size(rxWaveform)) + 1i*randn(size(rxWaveform)));

    rxWaveform = rxWaveform + noise;

    rxInfo = struct();
    rxInfo.Offset = offset;
    rxInfo.NoiseVar = noiseVar;
    rxInfo.PathGains = pathGains;     
    rxInfo.SampleTimes = sampleTimes;
    rxInfo.PathFilters = pathFilters; 
end