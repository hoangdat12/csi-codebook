setupPath();

% -------------------------------------------------------------
% Test Configuration
% -------------------------------------------------------------
% TS 38.211 Table 7.3.1.3-1:
% 1 Layer  -> 1 Codeword
% 2 Layers -> 1 Codeword
% 3 Layers -> 1 Codeword
% 4 Layers -> 1 Codeword

testCases = [
    struct('nLayers', 1, 'nSym', 100,  'desc', 'TC1: SISO (1 Layer)'),
    struct('nLayers', 2, 'nSym', 200,  'desc', 'TC2: MIMO 2x2 (2 Layers)'),
    struct('nLayers', 3, 'nSym', 300,  'desc', 'TC3: MIMO 3 Layers'),
    struct('nLayers', 4, 'nSym', 1000, 'desc', 'TC4: MIMO 4 Layers')
];

% -------------------------------------------------------------
% Testing Loop
% -------------------------------------------------------------
disp('==========================================================');
disp('TESTING: layerMapping function');
disp('==========================================================');

for i = 1:length(testCases)
    tc = testCases(i);
    fprintf('Running %-30s ... ', tc.desc);
    
    % 1. Generate Random Complex Symbols (Simulating QPSK/QAM)
    % Create random real and imaginary parts
    realPart = randn(tc.nSym, 1);
    imagPart = randn(tc.nSym, 1);
    inputSymbols = complex(realPart, imagPart);
    
    % 2. Call YOUR Function (DUT)
    try
        myResult = layerMapping(inputSymbols, tc.nLayers);
    catch ME
        fprintf('❌ ERROR: %s\n', ME.message);
        continue;
    end
    
    % 3. Call MATLAB Toolbox Function (Reference)
    % Note: nrLayerMap expects a Cell Array of codewords {cw0}
    refResult = nrLayerMap({inputSymbols}, tc.nLayers);
    
    % 4. Comparison
    % Check size
    if ~isequal(size(myResult), size(refResult))
        fprintf('❌ FAILED (Size Mismatch)\n');
        continue;
    end
    
    % Check values (allow small tolerance for float, though usually exact)
    diff = sum(abs(myResult - refResult), 'all');
    
    if diff == 0
        fprintf('✅ PASSED\n');
    else
        fprintf('❌ FAILED (Value Mismatch)\n');
    end
end

% -------------------------------------------------------------
% Manual Visual Check (Small Data)
% -------------------------------------------------------------
disp('----------------------------------------------------------');
disp('VISUAL CHECK (2 Layers, 8 Symbols)');
disp('----------------------------------------------------------');

% Small data: [0, 1, 2, 3, 4, 5, 6, 7]
smallInput = (0:7).'; 
nLay = 2;

myOut = layerMapping(smallInput, nLay);

disp('Input Vector:');
disp(smallInput.');

disp('Mapped Layers (Columns are Layers):');
disp(myOut);

% Expected logic for 2 layers:
% Layer 0 (Col 1): Even indices [0, 2, 4, 6]
% Layer 1 (Col 2): Odd indices  [1, 3, 5, 7]