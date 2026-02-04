classdef IdealChannel < BaseChannel
    % -----------------------------------------------------------------
    % IdealChannel: Subclass for an Ideal Noiseless Channel
    % Inherits from BaseChannel
    % -----------------------------------------------------------------

    methods (Access = protected)
        % -----------------------------------------------------------------
        % Core processing step for the System Object
        % It returns:
        %   - rxWaveform: Received signal (Identical to Transmitted in this case)
        %   - rxInfo: Structure containing noise variance (0) and channel matrix
        % -----------------------------------------------------------------
        function [rxWaveform, rxInfo] = stepImpl(obj, txWaveform)
            NumTxAnt = size(txWaveform, 2);
            
            % -----------------------------------------------------------------
            % CHANNEL MATRIX GENERATION
            % -----------------------------------------------------------------
            % Create static Identity Matrix H (No fading, No interference)
            H = eye(obj.NumRxAnts, NumTxAnt);
            
            % -----------------------------------------------------------------
            % SIGNAL TRANSMISSION
            % -----------------------------------------------------------------
            % Pass signal through the channel
            rxClean = txWaveform * H.';
            
            % -----------------------------------------------------------------
            % NOISE HANDLING
            % -----------------------------------------------------------------
            % Bypass noise addition completely for the Ideal case
            % We explicitly return the clean signal and zero noise variance
            rxWaveform = rxClean;
            noiseVar = 0;
            
            % Pack output information
            rxInfo.NoiseVar = noiseVar;
            rxInfo.ChannelMatrix = H;
        end
    end
end