% -----------------------------------------------------------------
% This function use to get the channel for TEST
% It return:
%   - channel: AWGN | Rayleigh | Ideal channel.
% -----------------------------------------------------------------
function channel = getChannel(channelType, SNR_dB, nRxAnts, ueIdx, sampleRate) 
    switch channelType
        case 'AWGN'
            channel = AWGNChannel('SNRdB', SNR_dB, 'NumRxAnts', nRxAnts);
            
        case 'Rayleigh'
            channel = RayleighChannel('SNRdB', SNR_dB, 'NumRxAnts', nRxAnts);
            
        case 'Ideal'
            channel = IdealChannel('SNRdB', SNR_dB, 'NumRxAnts', nRxAnts);

        case 'TDL'
            channel = nrTDLChannel;
            channel.NumTransmitAntennas = 8;
            channel.NumReceiveAntennas = 4;
            channel.SampleRate = sampleRate;
            channel.DelayProfile = 'TDL-C';
            channel.DelaySpread = 0;
            channel.Seed = ueIdx;
            channel.MaximumDopplerShift = 5;
            
        otherwise
            error('Invalid Type "%s"', channelType);
    end
end