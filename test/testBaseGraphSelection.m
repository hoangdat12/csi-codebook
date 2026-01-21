setupPath();

% -------------------------------------------------------------
% Test case
% -------------------------------------------------------------

% Selection Logic Reference:
% BG2 if: A <= 292 OR (A <= 3824 AND R <= 0.67) OR R < 0.25
% BG1 if: Otherwise (Large Block & High Rate)

testCases = [
    % Group 1: Small Block Length (A <= 292) -> Always BG2
    struct('A', 100,  'R', 0.9,  'expect', 2, 'desc', 'Small Block (A=100 < 292)'),
    struct('A', 292,  'R', 0.8,  'expect', 2, 'desc', 'Boundary Block (A=292)'),

    % Group 2: Medium Block Length (292 < A <= 3824)
    struct('A', 1000, 'R', 0.5,  'expect', 2, 'desc', 'Medium Block, Low Rate (R <= 0.67)'),
    struct('A', 1000, 'R', 0.67, 'expect', 2, 'desc', 'Medium Block, Boundary Rate (R=0.67)'),
    struct('A', 1000, 'R', 0.68, 'expect', 1, 'desc', 'Medium Block, High Rate (R > 0.67)'),
    struct('A', 3824, 'R', 0.8,  'expect', 1, 'desc', 'Boundary Block (A=3824), High Rate'),

    % Group 3: Low Rate (R < 0.25) -> Always BG2
    struct('A', 5000, 'R', 0.2,  'expect', 2, 'desc', 'Large Block but Low Rate (R < 0.25)'),

    % Group 4: Standard BG1 case
    struct('A', 4000, 'R', 0.5,  'expect', 1, 'desc', 'Large Block (A > 3824), High Rate')
];

% -------------------------------------------------------------
% Testing Logic
% -------------------------------------------------------------

for i = 1:length(testCases)
    % Get parameters from test case.
    tc = testCases(i);
    fprintf('Test Case::: %-50s ===> ', tc.desc);
    
    % Generate dummy input bits (only length matters).
    inBits = zeros(tc.A, 1); 
    
    % Call the implemented function.
    actualBGN = baseGraphSelection(inBits, tc.R);
    
    % Compare result with expectation.
    if actualBGN == tc.expect
        fprintf('PASSED (BG%d)\n', actualBGN);
    else
        fprintf('FAILED (Expected BG%d, Got BG%d)\n', tc.expect, actualBGN);
    end
end