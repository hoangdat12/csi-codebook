%% 5G NR RESOURCE MAPPING FUNCTION
% Standard: 3GPP TS 38.211 Section 7.3.1.5, 7.3.1.6 & 7.4.1.1
% Function: Maps Reserved PRBs, DM-RS, and PDSCH Data (inSym) onto 3D Grid
% -------------------------------------------------------------------------
function mappingGrid = ResourceMapping(grid, inSym, pdsch, carrier)

    % =====================================================================
    % GRID INITIALIZATION & PARAMETERS
    % =====================================================================
    mappingGrid = grid; 
    numberOfSlot = carrier.NSlot;
    SUBCARRIERS_PER_PRB = 12;

    % Trích xuất các tham số hệ thống từ struct
    NStartGrid = carrier.NStartGrid;
    NSizeBWP = pdsch.NSizeBWP;
    NStartBWP = pdsch.NStartBWP;
    DMRSReferencePoint = pdsch.DMRS.DMRSReferencePoint;
    prbset = pdsch.PRBSet;

    % =====================================================================
    % RESERVED RESOURCE MAPPING (ZERO-POWER / GUARD BANDS)
    % =====================================================================
    reservedList = pdsch.ReservedPRB;
    if ~iscell(reservedList), reservedList = {reservedList}; end

    for i = 1:length(reservedList)
        resCfg = reservedList{i}; 
        if isobject(resCfg) && isprop(resCfg, 'PRBSet') && ~isempty(resCfg.PRBSet)
            period = resCfg.Period;
            isReservedSlot = isempty(period) || (mod(numberOfSlot, period) == 0);
            if isReservedSlot
                startIdx = (resCfg.PRBSet * SUBCARRIERS_PER_PRB) + 1;
                allIndicesMatrix = startIdx + (0:SUBCARRIERS_PER_PRB - 1)';
                resSubcIdx = allIndicesMatrix(:).';
                resSymIdx = resCfg.SymbolSet + 1;
                mappingGrid(resSubcIdx, resSymIdx, :) = NaN; 
            end
        end
    end

   % =====================================================================
    % VRB-TO-PRB INTERLEAVING (SỬA ĐỔI)
    % =====================================================================
    % 1. Xác định điểm tham chiếu bắt đầu (Reference Point)
    if strcmp(DMRSReferencePoint, 'CRB0')
        % Sử dụng hàm ifElse hoặc logic đơn giản để lấy rbrefpoint
        if isempty(NStartBWP)
            rbrefpoint = double(NStartGrid);
        else
            rbrefpoint = double(NStartBWP(1));
        end
    else
        rbrefpoint = 0;
    end

    % 2. Kiểm tra điều kiện Interleaving
    if pdsch.VRBToPRBInterleaving && strcmpi(pdsch.PRBSetType, 'PRB')
        L = pdsch.VRBBundleSize;
        % Nb: Số lượng cụm (bundles)
        nBundle = ceil((NSizeBWP + mod(rbrefpoint, L)) / L);
        
        if nBundle > 1
            % Tính kích thước thực tế của từng cụm (cụm đầu/cuối có thể nhỏ hơn L)
            numRBinBundle = zeros(1, nBundle);
            numRBinBundle(1) = L - mod(rbrefpoint, L);
            rem_last = mod(rbrefpoint + NSizeBWP, L);
            
            if rem_last > 0
                numRBinBundle(end) = rem_last;
            else
                numRBinBundle(end) = L;
            end
            
            if nBundle > 2
                numRBinBundle(2:end-1) = L;
            end
            
            % Hoán vị cụm f(j) bằng ma trận hàng-cột R=2 (Theo TS 38.211 Section 7.3.1.6)
            R = 2; 
            C = floor(nBundle / R);
            f = zeros(1, nBundle);
            for j = 0:(nBundle-1)
                if j == nBundle - 1 && mod(nBundle, R) ~= 0
                    % Nếu nBundle lẻ, cụm cuối cùng giữ nguyên
                    f(j+1) = j;
                else
                    % Công thức hoán vị: f(j) = r*C + c
                    r = mod(j, R);
                    c = floor(j / R);
                    f(j+1) = r * C + c;
                end
            end
            
            % Tạo bảng ánh xạ vrbToPrbMap cho toàn bộ BWP
            % vrbToPrbMap(vrb_idx + 1) = prb_idx
            vrbToPrbMap = zeros(1, NSizeBWP);
            
            % Tính vị trí bắt đầu của mỗi PRB bundle trong dải vật lý
            prbBundleStart = [0, cumsum(numRBinBundle(1:end-1))];
            
            currentVRBStart = 0;
            for j = 0:(nBundle-1)
                L_j = numRBinBundle(j+1); % Kích thước cụm hiện tại
                
                % Cụm VRB thứ j ánh xạ tới cụm PRB thứ f(j+1)
                targetPRBStart = prbBundleStart(f(j+1) + 1);
                
                % Gán dải VRB vào dải PRB tương ứng
                vrbIndices = currentVRBStart + (1:L_j);
                vrbToPrbMap(vrbIndices) = targetPRBStart + (0:L_j-1);
                
                currentVRBStart = currentVRBStart + L_j;
            end

            interleavedPRB = vrbToPrbMap;

            mapMatrix = repmat(interleavedPRB,numel(prbset),1) == repmat(reshape(prbset,[],1),1,NSizeBWP);
            prbsetInterleave = interleavedPRB(any(mapMatrix,1));
        else
            prbsetInterleave = prbset;
        end
    else
        prbsetInterleave = prbset;
    end

    % =====================================================================
    % DM-RS & CDM GROUP RESOURCE ALLOCATION
    % =====================================================================
    dmrsConfig = pdsch.DMRS;
    [dmrsSymbolIndices_0based, ~] = lookupDMRSTable(carrier, pdsch);
    dmrsSymIdx = dmrsSymbolIndices_0based + 1; % Convert to 1-based indexing for MATLAB

    % Determine base pattern and shift step based on configuration type
    if dmrsConfig.DMRSConfigurationType == 1
        % Type 1: 6 REs per PRB per CDM group [cite: 15]
        base_pattern = [1, 3, 5, 7, 9, 11]; 
        shift_step = 1; % Delta shift between CDM groups
    else
        % Type 2: 4 REs per PRB per CDM group [cite: 15]
        base_pattern = [1, 2, 7, 8]; 
        shift_step = 2; % Delta shift between CDM groups
    end

    % Vectorized calculation of all DMRS offsets to avoid dynamic resizing
    % This accounts for CDM groups without data [cite: 15]
    group_shifts = (0:(dmrsConfig.NumCDMGroupsWithoutData - 1)) * shift_step;
    all_dmrs_offsets = unique(base_pattern(:) + group_shifts); 

    % Calculate global subcarrier indices based on physical resource blocks
    % startSubc: starting subcarrier of each PRB after interleaving [cite: 19, 21, 25]
    startSubc = prbsetInterleave(:) * SUBCARRIERS_PER_PRB;

    % Use broadcasting to combine PRB starts with DMRS RE offsets
    % dmrsSubcIdx identifies all REs reserved for DMRS across the grid [cite: 15, 19]
    dmrsSubcIdx = reshape(startSubc + all_dmrs_offsets', [], 1);

    % Mark reserved REs in the mapping grid across all antenna ports [cite: 4, 11]
    numPorts = size(mappingGrid, 3);
    for p = 1:numPorts
        for t = 1:length(dmrsSymIdx)
            currentSym = dmrsSymIdx(t);
            % Mark DMRS locations as -1 to prevent PDSCH data mapping 
            mappingGrid(dmrsSubcIdx, currentSym, p) = -1; 
        end
    end

    % =====================================================================
    % PDSCH BOUNDING BOX & MASKING
    % =====================================================================
    startSym = pdsch.SymbolAllocation(1);
    numSym = pdsch.SymbolAllocation(2);
    pdschSymIdx = (startSym : (startSym + numSym - 1)) + 1; 
    
    allSymIdx = 1:size(mappingGrid, 2);
    nonPdschSymIdx = setdiff(allSymIdx, pdschSymIdx);
    mappingGrid(:, nonPdschSymIdx, :) = NaN; 

    % Tính toán tất cả subcarriers thuộc PDSCH sau khi interleaving
    pdschSubcIdx = reshape((prbsetInterleave(:) * SUBCARRIERS_PER_PRB) + (1:SUBCARRIERS_PER_PRB), 1, []);
    allSubcIdx = 1:size(mappingGrid, 1);
    nonPdschSubcIdx = setdiff(allSubcIdx, pdschSubcIdx);
    mappingGrid(nonPdschSubcIdx, :, :) = NaN;

    % =====================================================================
    % PDSCH DATA INJECTION
    % =====================================================================
    % Tìm các RE còn trống (được đánh dấu là 0)
    pdschIdx = find(mappingGrid == 0);

    % Kiểm tra năng lực grid dựa trên số lượng symbol đầu vào
    if numel(inSym) > length(pdschIdx)
        error('Dữ liệu inSym vượt quá khả năng chứa của Resource Grid!');
    end

    mappingGrid(pdschIdx(1:numel(inSym))) = inSym(:);
end
