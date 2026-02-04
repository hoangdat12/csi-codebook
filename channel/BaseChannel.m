classdef BaseChannel < matlab.System
    % -----------------------------------------------------------------
    % BaseChannel: Parent class containing common properties and logic
    % -----------------------------------------------------------------
    
    % -----------------------------------------------------------------
    % PROPERTIES
    % -----------------------------------------------------------------
    properties
        SNRdB = 10;
        NumRxAnts = 1;
    end

    % -----------------------------------------------------------------
    % PUBLIC METHODS
    % -----------------------------------------------------------------
    methods
        % -----------------------------------------------------------------
        % Common Constructor for all subclasses
        % -----------------------------------------------------------------
        function obj = BaseChannel(varargin)
            setProperties(obj, nargin, varargin{:});
        end
    end

    % -----------------------------------------------------------------
    % PROTECTED METHODS
    % -----------------------------------------------------------------
    methods (Access = protected)
        % -----------------------------------------------------------------
        % Common function to add AWGN noise
        % It returns:
        %   - noisySig: The signal with added noise
        %   - noiseVar: The calculated noise variance
        % -----------------------------------------------------------------
        function [noisySig, noiseVar] = addAWGN(obj, signal)
            
            % Check for Ideal case (SNR = Infinite)
            if isinf(obj.SNRdB)
                noisySig = signal;
                noiseVar = 0;
            else
                % Calculate Signal Power
                sigPower = mean(abs(signal).^2, 'all');
                
                % Convert SNR to linear scale
                SNR_lin = 10^(obj.SNRdB/10);
                
                % Calculate Noise Variance and Scale
                noiseVar = sigPower / SNR_lin;
                noiseScale = sqrt(noiseVar/2);
                
                % Generate Complex Gaussian Noise
                noise = noiseScale * ...
                    (randn(size(signal)) + 1i*randn(size(signal)));
                
                % Add noise to signal
                noisySig = signal + noise;
            end
        end
    end
end