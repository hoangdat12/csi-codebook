setupPath();

% -------------------------------------------------------------
% Test case
% -------------------------------------------------------------

testCases = [
    struct('N', 150,  'E', 140,  'Rv', 0, 'mod', 'QPSK',   'rate', 0.2, 'desc', 'TC1: BG2 Puncturing (E < N)'),
    struct('N', 150,  'E', 1200, 'Rv', 0, 'mod', 'QPSK',   'rate', 0.2, 'desc', 'TC2: BG2 Repetition (E >> N)'),
    struct('N', 4000, 'E', 6000, 'Rv', 0, 'mod', '16QAM',  'rate', 0.8, 'desc', 'TC3: BG1 Large Block'),
    struct('N', 500,  'E', 400,  'Rv', 2, 'mod', '64QAM',  'rate', 0.5, 'desc', 'TC4: HARQ Retransmission (Rv=2)'),
    struct('N', 1000, 'E', 800,  'Rv', 3, 'mod', '256QAM', 'rate', 0.6, 'desc', 'TC5: High Modulation (Rv=3)')
];

% -------------------------------------------------------------
% Testing Logic
% -------------------------------------------------------------
nLayers = 1; 

for i = 1:length(testCases)
    % Get parameters from test case.
    tc = testCases(i);
    fprintf('Test Case::: %s ===> ', tc.desc);
    
    inBits = randi([0 1], tc.N, 1);

    % Choose CRC
    if tc.N > 3824, crcPoly = '24A';
    else,           crcPoly = '16'; 
    end
        
    % Create CRC & Attach
    tbCrcBits = createCRC(inBits, crcPoly);
    tbCrcAttachedBits = [inBits; tbCrcBits];

    % Base Graph & Segmentation
    bgn = baseGraphSelection(inBits, tc.rate);
    cbs = cbSegmentation(tbCrcAttachedBits, bgn);

    % Encoding
    encodedBits = nrLDPCEncode(cbs, bgn);

    % Rate Matching 
    rateMatchedBits = rateMatching(encodedBits, tc.E, tc.Rv, tc.mod, nLayers);

    % --- Comparison Logic ---

    % implemented function
    myResult = double(rateMatchedBits{1}); 
    refInput = double(encodedBits);
    
    % Matlab toolbox
    refResult = nrRateMatchLDPC(refInput, tc.E, tc.Rv, tc.mod, nLayers);

    % Compare
    if isequal(myResult, refResult)
        fprintf('PASSED\n');
    else
        fprintf('FAILED\n');
    end
end