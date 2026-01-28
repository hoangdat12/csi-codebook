%% 5G NR PHYSICAL DOWNLINK SHARED CHANNEL (PDSCH) TX CHAIN VERIFICATION
% This script verifies custom 5G NR physical layer implementations against 
% the standard MATLAB 5G Toolbox functions.
% Reference: 3GPP TS 38.211 (Modulation) and TS 38.212 (Multiplexing/Coding).

clc; clear; close all;

setupPath();

%% TRANSMITTER CONFIGURATION (TX)
% -----------------------------------------------------------
inputLen = 4000; % [bits] Transport block size
inputBits = randi([0 1], inputLen, 1); 

bitRate = 0.8;
nlayers = 2; % MIMO 2x2 configuration

% Carrier and PDSCH Configuration
carrier = nrCarrierConfig;
pdschConfig = customPDSCHConfig; 
pdschConfig.NumLayers = nlayers;
pdschConfig.Modulation = 'QPSK';

% Calculate available resources (G) for PDSCH after rate matching
[pdschInd, indinfo] = nrPDSCHIndices(carrier, pdschConfig);
G = indinfo.G;   

%% TRANSPORT BLOCK CRC ATTACHMENT
% 3GPP TS 38.212 Section 7.2.1
% -----------------------------------------------------------

% MATLAB 5G Toolbox
crcEncoded = nrCRCEncode(inputBits,'24A');

% Custom Implementation
if length(inputBits) > 3824, crcPoly = '24A'; else, crcPoly = '16'; end
tbCrcBits = createCRC(inputBits, crcPoly);
myCRCEncoded = [inputBits; tbCrcBits];

% Verification
isEqual = isequal(crcEncoded, myCRCEncoded);

if isEqual
    disp('-> SUCCESS: createCRC function matches nrCRCEncode perfectly.');
else
    disp('-> ERROR: Mismatch found. Check the polynomial or shift register logic.');
    numErrors = sum(crcEncoded ~= myCRCEncoded);
    fprintf('Number of mismatched bits: %d\n', numErrors);
end

%% LDPC CODE BLOCK SEGMENTATION
% 3GPP TS 38.212 Section 7.2.2
% -----------------------------------------------------------

% Base Graph Selection
bgn = baseGraphSelection(crcEncoded, bitRate);

% MATLAB 5G Toolbox
cbs = nrCodeBlockSegmentLDPC(crcEncoded, bgn);

% Custom Implementation
myCbs = cbSegmentation(myCRCEncoded, bgn);

% Verification
isEqual = isequal(cbs, myCbs);

if isEqual
    disp('-> SUCCESS: cbSegmentation function matches nrCodeBlockSegmentLDPC.');
else
    disp('-> ERROR: Segmentation mismatch. Check Zc calculation or filler bits.');
    % Note: Using (:) to compare all elements as a single column vector
    numErrors = sum(cbs(:) ~= myCbs(:));
    fprintf('Number of mismatched bits: %d\n', numErrors);
end

%% LDPC ENCODING
% 3GPP TS 38.212 Section 7.2.2
% -----------------------------------------------------------
% MATLAB 5G Toolbox Encoder used for next steps
codedcbs = nrLDPCEncode(cbs, bgn);

%% RATE MATCHING & CONCATENATION
% 3GPP TS 38.212 Section 5.4.2.1
% -----------------------------------------------------------

rv = 0; % Redundancy Version 0

% MATLAB 5G Toolbox (Includes Concatenation)
ratematched = nrRateMatchLDPC(codedcbs, G, rv, pdschConfig.Modulation, nlayers);

% Custom Implementation
GManual = pdschConfig.calculateManualG();
myRateMatched = rateMatching(codedcbs, GManual, rv, pdschConfig.Modulation, nlayers);
codeBlockConcatenation = concentration(myRateMatched);

% Verification
isEqual = isequal(ratematched, codeBlockConcatenation);

if isEqual
    disp('-> SUCCESS: rateMatching and concentration functions match nrRateMatchLDPC.');
else
    disp('-> ERROR: Mismatch found. Check the Circular Buffer or Bit Interleaver logic.');
    numErrors = sum(ratematched ~= codeBlockConcatenation);
    fprintf('Number of mismatched bits: %d\n', numErrors);
end

%% SCRAMBLING
% 3GPP TS 38.211 Section 7.3.1.1 (Pseudo-random sequence generation)
% -----------------------------------------------------------

% RNTI and Cell ID Setup
if isempty(pdschConfig.NID)
    nid = carrier.NCellID;
else
    nid = pdschConfig.NID(1);
end
rnti = pdschConfig.RNTI;

% MATLAB 5G Toolbox
c = nrPDSCHPRBS(nid, rnti, 0, length(ratematched));
scrambled = mod(ratematched + c, 2);

% Custom Implementation
% Initialization factor c_init formula per 3GPP
c_init = (double(rnti) * 2^15) + (double(0) * 2^14) + double(nid);
myScrambledBits = scrambling(codeBlockConcatenation, c_init);

% Verification
isEqual = isequal(scrambled, myScrambledBits);

if isEqual
    disp('-> SUCCESS: scrambling function matches nrPDSCHPRBS perfectly.');
else
    disp('-> ERROR: Mismatch found. Check the Gold Sequence (c_init) generator.');
    numErrors = sum(scrambled ~= myScrambledBits);
    fprintf('Number of mismatched bits: %d\n', numErrors);
end

%% MODULATION
% 3GPP TS 38.211 Section 5.1
% -----------------------------------------------------------

% MATLAB 5G Toolbox
modulated = nrSymbolModulate(scrambled, pdschConfig.Modulation);

% Custom Implementation
myModSymbols = modulation(myScrambledBits, pdschConfig.Modulation);

% Verification via Floating-Point Error Check
max_error = max(abs(modulated - myModSymbols));

if max_error < 1e-15
    disp('-> SUCCESS: modulation function is highly accurate (Machine precision limit).');
else
    disp('-> ERROR: Floating-point mismatch detected. Check QAM mapping constants.');
end

%% LAYER MAPPING
% 3GPP TS 38.211 Section 7.3.1.3
% -----------------------------------------------------------

% MATLAB 5G Toolbox
layerMapped = nrLayerMap(modulated, nlayers);

% Custom Implementation
layersMappedSymbols = layerMapping(myModSymbols, nlayers);

% Compare Layer 1 (Column 1)
err_Layer1 = max(abs(layerMapped(:, 1) - layersMappedSymbols(:, 1)));

% Compare Layer 2 (Column 2)
err_Layer2 = max(abs(layerMapped(:, 2) - layersMappedSymbols(:, 2)));

% Display detailed results

if (err_Layer1 < 1e-15) && (err_Layer2 < 1e-15)
    disp('-> SUCCESS: layerMapping function matches nrLayerMap.');
else
    disp('-> WARNING: Data mismatch detected. Check the reshape/transpose logic.');
end

%% Antenna Port Mapping
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

% --- MATLAB 5G Toolbox Implementation ---
% The nrPDSCHPrecode function requires the precoding matrix W 
% to be transposed into the format: [nLayers x nPorts].
W_transposed = W.'; 
[antsym, antind] = nrPDSCHPrecode(carrier, layerMapped, pdschInd, W_transposed);

% --- Custom Implementation ---
% Matrix multiplication to map 2 Spatial Layers onto 16 Antenna Ports.
% Formula: y = W * x (implemented efficiently via vectorization).
myAntSym = precoding(layersMappedSymbols, W);

% --- VERIFICATION ---
% Evaluate maximum floating-point precision error across all 16 Antenna Ports.
max_error_precoding = max(abs(antsym(:) - myAntSym(:)));

if max_error_precoding < 1e-14
    disp('-> SUCCESS: precoding function matches nrPDSCHPrecode.');
else
    disp('-> ERROR: Precoding mismatch. Check the matrix multiplication dimensions.');
end

%% Layer Mapping

% -----------------------------------------------------------
% RESOURCE GRID MAPPING & OFDM MODULATION
% Map the precoded symbols onto the Time-Frequency resource grid.
% -----------------------------------------------------------
txGrid = nrResourceGrid(carrier, size(W_transposed, 2)); 
txGrid(antind) = antsym;

myGrid = ResourceGrid(carrier, size(W_transposed, 2));
mappingGrid = ResourceMapping(myGrid, myAntSym, pdschConfig, carrier);

% =====================================================================
% KIỂM TRA TRỰC QUAN: SO SÁNH 2 LƯỚI TÀI NGUYÊN (ANTENNA PORT 1)
% =====================================================================
% Tính độ lệch lớn nhất giữa 2 lưới (Bỏ qua DMRS vì bạn đánh dấu là -1)
disp('--- KẾT QUẢ SO SÁNH CUỐI CÙNG ---');
is_same_shape = isequal(size(txGrid), size(mappingGrid));
fprintf('Kích thước 3D giống nhau: %s\n', mat2str(is_same_shape));