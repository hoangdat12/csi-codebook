clc; clear; close all;

setupPath();

% =============================================================
% CASE 1: Baseline (SISO, Type A, Config 1)
% Tương thích bảng: dmrs_singleA (Full 14 dòng)
% =============================================================
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

compareResults('CASE 1 (Baseline: Type A, SISO)', carrier, pdsch);

% =============================================================
% CASE 2: Mapping Type B (Mini-slot / Non-slot)
% Tương thích bảng: dmrs_singleB (Chỉ có dòng 2,4,6,7)
% =============================================================
pdsch = nrPDSCHConfig;
pdsch.NSizeBWP = 52;
pdsch.NStartBWP = 0;
pdsch.PRBSet = 0:51; 

% QUAN TRỌNG: Bảng của bạn chỉ hỗ trợ max Length 7. 
% Nếu để > 7 sẽ bị lỗi "No DM-RS defined".
pdsch.SymbolAllocation = [0 13]; 

pdsch.MappingType = 'B'; 
pdsch.DMRS.DMRSConfigurationType = 1; 
pdsch.DMRS.DMRSLength = 1; 
pdsch.DMRS.DMRSAdditionalPosition = 1; 
pdsch.NumLayers = 1;

compareResults('CASE 2 (Mapping Type B, Length 7)', carrier, pdsch);

% =============================================================
% CASE 3: DMRS Configuration Type 2 (High Frequency Density)
% Tương thích bảng: dmrs_doubleA (Size 14x2 -> Max AddPos = 1)
% =============================================================
pdsch = nrPDSCHConfig;
pdsch.NSizeBWP = 52;
pdsch.NStartBWP = 0;
pdsch.PRBSet = 0:51; 
pdsch.SymbolAllocation = [0 14]; % Full slot

pdsch.MappingType = 'A';
pdsch.DMRS.DMRSConfigurationType = 2; % Config Type 2
pdsch.DMRS.DMRSLength = 2;            % Double Symbol

% QUAN TRỌNG: Bảng dmrs_doubleA của bạn là cell(14,2).
% Nên AddPos tối đa là 1 (Cột 2). Nếu để 2 sẽ Crash.
pdsch.DMRS.DMRSAdditionalPosition = 1; 

pdsch.NumLayers = 1;

compareResults('CASE 3 (DMRS Config Type 2, Length 2)', carrier, pdsch);

% =============================================================
% CASE 4: DMRS Length 2 (High Time Density)
% Tương thích bảng: dmrs_doubleA (Size 14x2)
% =============================================================
pdsch = nrPDSCHConfig;
pdsch.NSizeBWP = 52;
pdsch.NStartBWP = 0;
pdsch.PRBSet = 0:51; 
pdsch.SymbolAllocation = [0 14]; % Full slot

pdsch.MappingType = 'A';
pdsch.DMRS.DMRSConfigurationType = 1; 
pdsch.DMRS.DMRSLength = 2;            % Double Symbol

% Tương tự Case 3, giữ AddPos = 1 để khớp với bảng của bạn.
pdsch.DMRS.DMRSAdditionalPosition = 1; 

pdsch.NumLayers = 1;

compareResults('CASE 4 (DMRS Length 2, AddPos 1)', carrier, pdsch);

% =============================================================
% CASE 5: MIMO (2 Layers)
% Tương thích bảng: dmrs_singleA
% =============================================================
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
pdsch.NumLayers = 2;             % 2 Layers

compareResults('CASE 5 (MIMO 2 Layers)', carrier, pdsch);


% -------------------------------------------------------------
% HELPER FUNCTION
% -------------------------------------------------------------
function compareResults(testName, carrier, pdsch)
        myIndices = DMRSIndices(pdsch, carrier);
        myIndices = double((myIndices)); 
    

    % 2. Run Toolbox Function
    tbIndices = nrPDSCHDMRSIndices(carrier, pdsch);
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