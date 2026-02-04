classdef AWGNChannel < BaseChannel
    % -----------------------------------------------------------------
    % AWGNChannel: Subclass for Additive White Gaussian Noise Channel
    % Inherits from BaseChannel
    % -----------------------------------------------------------------

    methods (Access = protected)
        % -----------------------------------------------------------------
        % Core processing step for the System Object
        % It returns:
        %   - rxWaveform: Received signal after channel and noise
        %   - rxInfo: Structure containing noise variance and channel matrix
        % -----------------------------------------------------------------
        function [rxWaveform, rxInfo] = stepImpl(obj, txWaveform)
            NumTxAnt = size(txWaveform, 2);
            
            % -----------------------------------------------------------------
            % CHANNEL MATRIX GENERATION
            % -----------------------------------------------------------------
            % Create static Identity Matrix H
            % For pure AWGN, the channel response is ideal (1)
            H = eye(obj.NumRxAnts, NumTxAnt);
            
            % -----------------------------------------------------------------
            % SIGNAL TRANSMISSION
            % -----------------------------------------------------------------
            % Pass signal through the channel
            % Note: Transpose H to match matrix dimensions (Tx * H.')
            rxClean = txWaveform * H.';
            
            % -----------------------------------------------------------------
            % NOISE ADDITION
            % -----------------------------------------------------------------
            % Add AWGN using the parent class method
            [rxWaveform, noiseVar] = obj.addAWGN(rxClean);
            
            % Pack output information
            rxInfo.NoiseVar = noiseVar;
            rxInfo.ChannelMatrix = H;
        end
    end
end