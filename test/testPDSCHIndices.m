clc; clear; close all;

setupPath();

% -------------------------------------------------------------
% CASE 1 - Baseline (SISO, Full Bandwidth, Type A)
% -------------------------------------------------------------

carrier = nrCarrierConfig;
carrier.NCellID = 1;
carrier.NSizeGrid = 52;

pdsch = nrPDSCHConfig;
pdsch.NSizeBWP = 52;
pdsch.NStartBWP = 0;
pdsch.PRBSet = 0:51; 
pdsch.SymbolAllocation = [0 14]; % Full slot
pdsch.MappingType = 'A';
pdsch.DMRS.DMRSConfigurationType = 1; 
pdsch.DMRS.DMRSLength = 1; 
pdsch.DMRS.DMRSAdditionalPosition = 1; 
pdsch.NumLayers = 1;

compareResults('CASE 1 (Baseline)', carrier, pdsch);

% -------------------------------------------------------------
% CASE 2 - DMRS Type 2 + Rate Matching (CDM Groups)
% -------------------------------------------------------------
carrier.NCellID = 10;

pdsch = nrPDSCHConfig;
pdsch.PRBSet = 0:20; 
pdsch.SymbolAllocation = [2 10];
pdsch.MappingType = 'B';         
pdsch.DMRS.DMRSConfigurationType = 2;
pdsch.DMRS.NumCDMGroupsWithoutData = 2; 

compareResults('CASE 2 (DMRS Type 2 + RateMatch)', carrier, pdsch);

% -------------------------------------------------------------
% CASE 3 - DMRS Type 2 + Rate Matching (CDM Groups) 
%          NumCDMGroupsWithoutData = 3
% -------------------------------------------------------------
carrier.NCellID = 10;

pdsch = nrPDSCHConfig;
pdsch.PRBSet = 0:20; 
pdsch.SymbolAllocation = [2 10];
pdsch.MappingType = 'B';         
pdsch.DMRS.DMRSConfigurationType = 2;
pdsch.DMRS.NumCDMGroupsWithoutData = 3; 

compareResults('CASE 3 (DMRS Type 2 + RateMatch + NumCDMGroupsWithoutData = 3)', carrier, pdsch);


% -------------------------------------------------------------
% CASE 4: Reserved PRBs (Resource Reservation)
% -------------------------------------------------------------
carrier.NCellID = 1;

pdsch = nrPDSCHConfig;
pdsch.PRBSet = 0:51;
pdsch.SymbolAllocation = [0 14];

res1 = nrPDSCHReservedConfig;
res1.PRBSet = 10:15;
res1.SymbolSet = 5:10;
res1.Period = []; 
pdsch.ReservedPRB = {res1};

compareResults('CASE 4 (Reserved PRB)', carrier, pdsch);

% -------------------------------------------------------------
% CASE 5: MIMO (2 Layers)
% -------------------------------------------------------------
pdsch = nrPDSCHConfig;
pdsch.PRBSet = 0:10;
pdsch.NumLayers = 3;
pdsch.DMRS.NumCDMGroupsWithoutData = 2; 

compareResults('CASE 5 (MIMO 2 Layers)', carrier, pdsch);

% -------------------------------------------------------------
% CASE 6: BWP Offset (Partial Bandwidth)
% -------------------------------------------------------------
carrier.NSizeGrid = 106;
carrier.NStartGrid = 0;

pdsch = nrPDSCHConfig;
pdsch.NSizeBWP = 50;
pdsch.NStartBWP = 10; 
pdsch.PRBSet = 0:49;

compareResults('CASE 6 (BWP Offset)', carrier, pdsch);

% -------------------------------------------------------------
% CASE 7: Interleaving
% -------------------------------------------------------------
pdsch = nrPDSCHConfig;
pdsch.NSizeBWP = 50;
pdsch.PRBSet = 0:21;
pdsch.VRBToPRBInterleaving = 1; 
pdsch.VRBBundleSize = 2;
pdsch.PRBSetType = 'VRB';

compareResults('CASE 7 (Interleaving)', carrier, pdsch);

% -------------------------------------------------------------
% CASE 8: Non-contiguous PRB Allocation (Disjoint Blocks)
% -------------------------------------------------------------
pdsch = nrPDSCHConfig;
pdsch.NSizeBWP = 52;
% Cấp phát 3 khối rời nhau: [0-4], [10-14], [20-24]
pdsch.PRBSet = [0:4, 10:14, 20:24]; 
pdsch.SymbolAllocation = [0 14];

compareResults('CASE 8 (Non-contiguous PRB)', carrier, pdsch);

% -------------------------------------------------------------
% CASE 9: Heavy DMRS (Double Symbol + Max Additional Pos)
% -------------------------------------------------------------
pdsch = nrPDSCHConfig;
pdsch.PRBSet = 0:51;
pdsch.MappingType = 'A';
pdsch.SymbolAllocation = [0 14];
% Cấu hình DMRS "nặng đô"
pdsch.DMRS.DMRSConfigurationType = 2;       % Type 2 (Mật độ SC cao)
pdsch.DMRS.DMRSLength = 2;                  % Chiếm 2 symbol liên tiếp
pdsch.DMRS.DMRSAdditionalPosition = 1;      % Thêm các vị trí phụ
pdsch.NumLayers = 1;

compareResults('CASE 9 (Heavy DMRS)', carrier, pdsch);

% -------------------------------------------------------------
% HELPER FUNCTION
% -------------------------------------------------------------
function compareResults(testName, carrier, pdsch)
    try
        myIndices = PDSCHIndices(carrier, pdsch);
        myIndices = double((myIndices)); 
    catch ME
        fprintf('%s: CRASHED\n  Error: %s\n', testName, ME.message);
        return;
    end

    % 2. Run Toolbox Function
    tbIndices = nrPDSCHIndices(carrier, pdsch);
    tbIndices = double((tbIndices));

    % 3. Compare
    if isequal(myIndices, tbIndices)
        fprintf('%s: PASSED::::: \n', testName);
    else
        fprintf('%s: FAILED::::: \n', testName);
        fprintf('   - My Length: %d\n', length(myIndices));
        fprintf('   - TB Length: %d\n', length(tbIndices));
        
        % Debug: Show the first mismatch index
        if length(myIndices) == length(tbIndices)
            diffIdx = find(myIndices ~= tbIndices, 1);
            fprintf('   - Mismatch at index %d: Mine=%d, TB=%d\n', ...
                diffIdx, myIndices(diffIdx), tbIndices(diffIdx));
        else
            missing = setdiff(tbIndices, myIndices);
            extra = setdiff(myIndices, tbIndices);
            if ~isempty(missing)
                fprintf('   - I am missing %d indices (e.g., %d)\n', length(missing), missing(1));
            end
            if ~isempty(extra)
                fprintf('   - I have %d extra indices (e.g., %d)\n', length(extra), extra(1));
            end
        end
    end
end