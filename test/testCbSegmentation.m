setupPath();

%% Test Case

% ----------------------------------------------------------------------
% All the test case will be perform to verify the SEGMENTATION FUNCTION
% Test case format: [inputBits, codeRate, Test Case description]
% ----------------------------------------------------------------------

testCases = {
    8000,  0.75, 'Test Case 1: BG1 - 8000 bits - Normal (C=1)';
    17000, 0.75, 'Test Case 2: BG1 - 17000 bits - Segmentation (C=3)';
    4000,  0.2,  'Test Case 3: BG2 - 4000 bits - Forced Segment (C=2)';
    500,   0.5,  'Test Case 4: BG2 - 500 bits - Small Block (C=1)';
    8424,  0.8,  'Test Case 5: BG1 - 8424 bits - Boundary (C=1, F=0)'
};

% ----------------------------------------------------------------------
% Loop for every case and perform testing.
% ----------------------------------------------------------------------

for i = 1:size(testCases, 1)
    % Total bits
    A = testCases{i, 1};
    % Code Rate
    R = testCases{i, 2};
    % Description
    name = testCases{i, 3};
        
    performSingleTest(A, R, name);
end

%% Helper Function

% ---------------------------------------------------------
% This function will perform test for every case.
% ---------------------------------------------------------
function performSingleTest(totalBits, codeRate, testName)
    fprintf('------------------------------------------------------------\n');
    fprintf('Running: %s\n', testName);
    
    % Random input for perform test.
    inputBits = randi([0 1], totalBits, 1);
    
    % Choose CRC for each length of the input bits.
    if totalBits > 3824
        crcPoly = '24A';
    else
        crcPoly = '16'; 
    end
    
    % Create CRC sequence. Base on the inputBits and crcPoly.
    tbCrcBits = createCRC(inputBits, crcPoly);
    tbCrcAttachedBits = [inputBits; tbCrcBits];

    % The total length of inputBits + CRC sequence
    B_actual = length(tbCrcAttachedBits);

    % Select the base grapth for segmentation.
    bgn = baseGraphSelection(inputBits, codeRate);

    % Perform segmentation logic
    cbs = cbSegmentation(tbCrcAttachedBits, bgn);

    % Getting the acctual K and C values for comparision.
    [actual_K, actual_C] = size(cbs);

    % ====================================================
    % Manual calculation and comparision
    % ====================================================
    
    % Identify the max block size - Kcb
    if bgn == 1
        Kcb = 8448;
    else
        Kcb = 3840;
    end
    
    % Compute the number of codeblock
    if B_actual <= Kcb
        expected_C = 1;
        L = 0;
    else
        L = 24; 
        expected_C = ceil(B_actual / (Kcb - L));
    end
    
    % The total bits after attach CRC for each codeblock if number of codeblock != 1
    if expected_C == 1
        B_prime = B_actual;
    else
        B_prime = B_actual + (expected_C * L);
    end
    
    % The number of bits for each block
    Kd = ceil(B_prime / expected_C);
    
    % Identify the number of column in the base graphs
    if bgn == 1
        Kb = 22;
    else
        if B_actual > 640
            Kb = 10;
        elseif B_actual > 560
            Kb = 9;
        elseif B_actual > 192
            Kb = 8;
        else
            Kb = 6;
        end
    end
    
    % Find Zc (Lifting Size) based on Table 5.3.2-1 
    Zlist = [2:16 18:2:32 36:4:64 72:8:128 144:16:256 288:32:384];
    min_Zc = Kd / Kb;

    % Find the smallest Zc in the table such that Zc >= min_Zc
    valid_Zcs = Zlist(Zlist >= min_Zc);
    
    expected_Zc = valid_Zcs(1);
    
    % Calculate standard K: 22*Zc for BG1, always 10*Zc for BG2 (per TS 38.212)
    if bgn == 1
        expected_K = 22 * expected_Zc;
    else
        expected_K = 10 * expected_Zc; 
    end

    % ====================================================
    % COMPARE AND DISPLAY RESULTS
    % ====================================================
    if (actual_C == expected_C) && (actual_K == expected_K)
        fprintf('RESULT: [SUCCESS] Matching!\n\n');
    else
        fprintf('RESULT: [FAILURE] Mismatch! Check implementation.\n\n');
    end
end