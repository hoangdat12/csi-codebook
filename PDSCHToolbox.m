%% 5G NR TYPE II PRECODING LINK-LEVEL SIMULATION
% This script simulates a full 5G NR Transmitter-Channel-Receiver chain 
% using Type II (High-Resolution) Precoding Codebook.

clc; clear; close all;

setupPath();   

%% TRANSMITTER CONFIGURATION (TX)

% -----------------------------------------------------------
% Transport Block and PDSCH Configuration
% Type II Precoding supports up to nLayers = 2 (v = {1, 2}).
% 273 RB, 14 symbols, 256QAM, 1 slot 14 symbols
% -----------------------------------------------------------
inputLen = 4000;
inputBits = randi([0 1], inputLen, 1); 

bitRate = 0.8;
nlayers = 2;

carrier = nrCarrierConfig;
% Assuming customPDSCHConfig is available, otherwise use nrPDSCHConfig
pdschConfig   = nrPDSCHConfig; 
pdschConfig.NumLayers = nlayers;
pdschConfig.Modulation = 'QPSK';

% -----------------------------------------------------------
% Calculate the available resources for PDSCH.
% The output 'G' is the maximum number of coded bits required 
%   after rate matching.
% -----------------------------------------------------------
[pdschInd, indinfo] = nrPDSCHIndices(carrier, pdschConfig);
G = indinfo.G;   

%% BASEBAND PROCESSING (LDPC & MODULATION)

% -----------------------------------------------------------
% LDPC Coding Chain (3GPP TS 38.212)
% 1. CRC Attachment
% 2. Base Graph Selection
% 3. Code Block Segmentation
% 4. LDPC Encoding
% 5. Rate Matching
% -----------------------------------------------------------
crcEncoded = nrCRCEncode(inputBits,'24A');
bgn = baseGraphSelection(crcEncoded, bitRate);
cbs = nrCodeBlockSegmentLDPC(crcEncoded, bgn);
codedcbs = nrLDPCEncode(cbs, bgn);

rv = 0;
ratematched = nrRateMatchLDPC(codedcbs, G, rv, pdschConfig.Modulation, nlayers);

% -----------------------------------------------------------
% Scrambling and Symbol Modulation
% Generating scrambled bits using NCellID and RNTI.
% -----------------------------------------------------------
if isempty(pdschConfig.NID)
    nid = carrier.NCellID;
else
    nid = pdschConfig.NID(1);
end
rnti = pdschConfig.RNTI;

c = nrPDSCHPRBS(nid, rnti, 0, length(ratematched));
scrambled = mod(ratematched + c, 2);

modulated = nrSymbolModulate(scrambled, pdschConfig.Modulation);

% Reshape the modulated symbols to map onto the designated layers
portsym = reshape(modulated, [], nlayers);

% -----------------------------------------------------------
% TYPE II CSI REPORT CONFIGURATION (3GPP TS 38.214)
% Number of antenna ports is derived as: P_csi-rs = 2 * N1 * N2
% In this case: 2 * 4 * 2 = 16 ports.
% -----------------------------------------------------------
cfg = struct();
cfg.CodebookConfig.N1 = 4;
cfg.CodebookConfig.N2 = 2;
cfg.CodebookConfig.O1 = 4;
cfg.CodebookConfig.O2 = 4;
cfg.CodebookConfig.NumberOfBeams = 4; % L = 4
cfg.CodebookConfig.PhaseAlphabetSize = 8; % Npsk = 8
cfg.CodebookConfig.SubbandAmplitude = true;
cfg.CodebookConfig.numLayers = nlayers;

% -----------------------------------------------------------
% PMI Report simulation from UE
% i1: Wideband indices (spatial beams)
% i2: Subband indices (co-phasing and amplitude)
% -----------------------------------------------------------
i11 = [2, 1];
i12 = 2;
i13 = [3, 1];
i14 = [4, 6, 5, 0, 2, 3, 1 ; 3, 2, 4, 1, 5, 6, 0];
i21 = [1, 3, 4, 2, 5, 7 ; 2, 0, 5, 1, 4, 6];
i22 = [0, 1, 0, 1, 0 ; 1, 1, 0, 0, 1];

i1 = {i11, i12, i13, i14};
i2 = {i21, i22};

% -----------------------------------------------------------
% PRECODING MATRIX GENERATION
% Matrix W dimensions: [numberOfPorts x nLayers] -> [16 x 2]
% Type II Precoding creates a non-orthogonal matrix.
% -----------------------------------------------------------
W = generateTypeIIPrecoder(cfg, i1, i2);

% The function nrPDSCHPrecode requires the W matrix format: [nLayers x nPorts].
W_transposed = W.';

[antsym, antind] = nrPDSCHPrecode(carrier, portsym, pdschInd, W_transposed);



% -----------------------------------------------------------
% RESOURCE GRID MAPPING & OFDM MODULATION
% Map the precoded symbols onto the Time-Frequency resource grid.
% -----------------------------------------------------------
txGrid = nrResourceGrid(carrier, size(W_transposed, 2)); 
txGrid(antind) = antsym;

[txWaveform, ofdmInfo] = nrOFDMModulate(carrier, txGrid);

%% CHANNEL SIMULATION

% -----------------------------------------------------------
% Additive White Gaussian Noise (AWGN) Channel
% In this simple simulation, the flat fading channel H is assumed to be 1.
% -----------------------------------------------------------
SNR = 30; % Signal-to-Noise Ratio in dB
rxWaveform = awgn(txWaveform, SNR, 'measured');
fprintf('Signal transmitted through AWGN channel with SNR = %d dB.\n', SNR);

%% RECEIVER PROCESSING (RX)

% -----------------------------------------------------------
% OFDM Demodulation
% Convert the Time-Domain waveform back to Frequency-Domain grid.
% -----------------------------------------------------------
rxGrid = nrOFDMDemodulate(carrier, rxWaveform);
rx_antsym = rxGrid(antind);

% -----------------------------------------------------------
% CHANNEL EQUALIZATION (ZERO FORCING)
% For Type II, the matrix W_transposed is not unitary (W'W != I).
% Therefore, the Pseudo-Inverse (pinv) is used instead of Hermitian transpose
% to equalize the signal and separate the MIMO layers.
% -----------------------------------------------------------
H_eff = W_transposed; 
rx_layers = rx_antsym * pinv(H_eff); 

%% VISUALIZATION

% -----------------------------------------------------------
% QPSK Constellation Diagram
% Evaluate the Equalization performance.
% -----------------------------------------------------------
figure('Name', 'Receiver Constellation');
plot(rx_layers(:), 'o');
grid on; 
title('QPSK Constellation at Receiver (Post-Equalization)');
xlabel('In-Phase (I)'); ylabel('Quadrature (Q)');
axis([-2 2 -2 2]);

% -----------------------------------------------------------
% Signal Spectrogram
% Display the 5G NR Tx Waveform frequency distribution.
% -----------------------------------------------------------
figure('Name', 'Tx Waveform Spectrogram');
spectrogram(txWaveform(:,1), ones(ofdmInfo.Nfft,1), 0, ofdmInfo.Nfft, 'centered', ofdmInfo.SampleRate, 'yaxis', 'MinThreshold', -130);
title('5G NR Signal Spectrogram (Tx Waveform)');

