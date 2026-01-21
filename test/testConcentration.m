setupPath();

% -------------------------------------------------------------
% Test case
% -------------------------------------------------------------

testCases = [
    struct('C', 1,   'E', 100,  'desc', 'TC1: Single Block (C=1)'),
    struct('C', 2,   'E', 150,  'desc', 'TC2: Two Blocks (C=2)'),
    struct('C', 10,  'E', 64,   'desc', 'TC3: Many Blocks (C=10)'),
    struct('C', 5,   'E', 1000, 'desc', 'TC4: Large Blocks')
];

% -------------------------------------------------------------
% Testing Logic
% -------------------------------------------------------------

for i = 1:length(testCases)
    % Get parameters from test case.
    tc = testCases(i);
    fprintf('Test Case::: %-40s ===> ', tc.desc);
    
    % --- MOCK DATA GENERATION (FAKE INPUT) ---
    % Create the expected full vector first (Reference)
    totalBits = tc.C * tc.E;
    expectedResult = randi([0 1], totalBits, 1);
    
    % Split it into Cell Array (Simulating RateMatching output)
    mockRateMatchedBits = cell(tc.C, 1);
    for blockIdx = 1:tc.C
        startIndex = (blockIdx - 1) * tc.E + 1;
        endIndex = blockIdx * tc.E;
        mockRateMatchedBits{blockIdx} = expectedResult(startIndex:endIndex);
    end

    % --- Implemented Function ---
    myResult = concentration(mockRateMatchedBits);

    % --- 3. COMPARISON LOGIC ---
    
    % Check 1: Is it a vector column?
    isVectorCol = iscolumn(myResult);
    
    % Check 2: Value matching?
    isValMatch = isequal(myResult, expectedResult);

    if isVectorCol && isValMatch
        fprintf('PASSED\n');
    else
        fprintf('FAILED (Size or Value mismatch)\n');
    end
end