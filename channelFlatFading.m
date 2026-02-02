function [rxWaveform, rxInfo] = channelFlatFading(txWaveform, SNRdB, nRxAnts)
    NRxAnt = nRxAnts; 
    NumTxAnt = size(txWaveform, 2); 

    H = eye(NRxAnt, NumTxAnt); 

    rxWaveform_Fading = txWaveform * H.'; 

    sigPower = mean(abs(rxWaveform_Fading).^2, 'all');
    
    SNR_lin = 10^(SNRdB/10);
    noiseVar = sigPower / SNR_lin;
    
    noiseScale = sqrt(noiseVar/2);
    noise = noiseScale * ...
            (randn(size(rxWaveform_Fading)) + 1i*randn(size(rxWaveform_Fading)));
        
    rxWaveform = rxWaveform_Fading + noise;

    rxInfo = struct();
    rxInfo.NoiseVar = noiseVar;  
    rxInfo.Offset = 0;          
    rxInfo.ChannelMatrix = H;     
end