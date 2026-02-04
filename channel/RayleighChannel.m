classdef RayleighChannel < BaseChannel
    % -----------------------------------------------------------------
    % RayleighChannel: Subclass for Rayleigh Flat Fading Channel
    % Inherits from BaseChannel
    % -----------------------------------------------------------------

    % -----------------------------------------------------------------
    % PROPERTIES
    % -----------------------------------------------------------------
    properties (Nontunable)
        % Seed for Random Number Generator (0 = Random, >0 = Fixed)
        Seed = 0; 
    end

    % -----------------------------------------------------------------
    % PUBLIC METHODS
    % -----------------------------------------------------------------
    methods
        % -----------------------------------------------------------------
        % Constructor: Passes arguments to the BaseChannel constructor
        % -----------------------------------------------------------------
        function obj = RayleighChannel(varargin)
            obj@BaseChannel(varargin{:});
        end
    end

    % -----------------------------------------------------------------
    % PROTECTED METHODS
    % -----------------------------------------------------------------
    methods (Access = protected)
        
        % -----------------------------------------------------------------
        % Setup method: Initialize resources before processing
        % Used here to set the Random Number Generator seed
        % -----------------------------------------------------------------
        function setupImpl(obj)
            if obj.Seed > 0
                rng(obj.Seed);
            end
        end

        % -----------------------------------------------------------------
        % Core processing step for the System Object
        % It returns:
        %   - rxWaveform: Received signal after fading and noise
        %   - rxInfo: Structure containing noise variance and channel matrix
        % -----------------------------------------------------------------
        function [rxWaveform, rxInfo] = stepImpl(obj, txWaveform)
            NumTxAnt = size(txWaveform, 2);
            
            % -----------------------------------------------------------------
            % CHANNEL MATRIX GENERATION
            % -----------------------------------------------------------------
            % Generate Rayleigh Fading coefficients (i.i.d)
            % Complex Normal distribution CN(0, 1) normalized by sqrt(2)
            % This ensures unit average power gain (E[|h|^2] = 1)
            H = (randn(obj.NumRxAnts, NumTxAnt) + 1i*randn(obj.NumRxAnts, NumTxAnt)) / sqrt(2);
            
            % -----------------------------------------------------------------
            % SIGNAL TRANSMISSION
            % -----------------------------------------------------------------
            % Apply flat fading to the waveform
            % Mathematical operation: Y = X * H.'
            % Dimension check: [Samples x Tx] * [Tx x Rx] -> [Samples x Rx]
            rxClean = txWaveform * H.';
            
            % -----------------------------------------------------------------
            % NOISE ADDITION
            % -----------------------------------------------------------------
            % Add AWGN using the parent class method
            % This handles SNR calculations and noise generation
            [rxWaveform, noiseVar] = obj.addAWGN(rxClean);
            
            % Pack output information
            rxInfo.NoiseVar = noiseVar;
            rxInfo.ChannelMatrix = H;
            rxInfo.SNRdB = obj.SNRdB;
        end
    end
end