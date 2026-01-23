function [dmrssymbolset,ldash] = lookupDMRSTable(carrierConfig, pdschConfig)
% lookupDMRSTable: Xác định vị trí DM-RS trong miền thời gian (3GPP TS 38.211)

    % =====================================================================
    % 1. ĐỊNH NGHĨA BẢNG (Tables 7.4.1.1.2-3 & 7.4.1.1.2-4)
    % =====================================================================
    % 0: l0 (symbol đầu), -1: l1 (symbol 11/12)
    
    % --- Single Symbol Tables (Type A) ---
    dmrs_singleA = {
        [],[],  [],  [];                %  1
        [],[],  [],  [];                %  2
        0,  0,  0,    0;                %  3
        0,  0,  0,    0;                %  4
        0,  0,  0,    0;                %  5
        0,  0,  0,    0;                %  6
        0,  0,  0,    0;                %  7
        0,  [0,7],  [0,7],  [0,7];      %  8
        0,  [0,7],  [0,7],  [0,7];      %  9
        0,  [0,9], [0,6,9], [0,6,9];    % 10
        0,  [0,9], [0,6,9], [0,6,9];    % 11
        0,  [0,9], [0,6,9], [0,5,8,11]; % 12
        0, [0,-1], [0,7,11],[0,5,8,11]; % 13
        0, [0,-1], [0,7,11],[0,5,8,11]; % 14
    };

    % --- Single Symbol Tables (Type B) ---
    dmrs_singleB = {
        [],[],  [],  [];                %  1
         0, 0,   0,   0;                %  2
         0, 0,   0,   0;                %  3
         0, 0,   0,   0;                %  4
         0,[0,4],[0,4],  [0,4];         %  5
         0,[0,4],[0,4],  [0,4];         %  6
         0,[0,4],[0,4],  [0,4];         %  7
         0,[0,6],[0,3,6],[0,3,6];       %  8
         0,[0,7],[0,4,7],[0,4,7];       %  9
         0,[0,7],[0,4,7],[0,4,7];       % 10
         0,[0,8],[0,4,8],[0,3,6,9];     % 11
         0,[0,9],[0,5,9],[0,3,6,9];     % 12
         0,[0,9],[0,5,9],[0,3,6,9];     % 13
        [],[],  [],  [];                % 14
    };

    % --- Double Symbol Tables (Type A) ---
    dmrs_doubleA = {
        [],[]; [],[]; [],[];            % 1-3
        0,0; 0,0; 0,0; 0,0; 0,0; 0,0;   % 4-9
        0,[0,8]; 0,[0,8]; 0,[0,8];      % 10-12
        0,[0,10]; 0,[0,10]              % 13-14
    };

    % --- Double Symbol Tables (Type B) ---
    dmrs_doubleB = {
        [],[]; [],[]; [],[]; [],[];     % 1-4
        0,0; 0,0; 0,0;                  % 5-7
        0,[0,5]; 0,[0,5];               % 8-9
        0,[0,7]; 0,[0,7];               % 10-11
        0,[0,8]; 0,[0,8];               % 12-13
        [],[]                           % 14
    };

    % =====================================================================
    % 2. XỬ LÝ CẤU HÌNH
    % =====================================================================
    dmrsConfig = pdschConfig.DMRS;
    symbperslot = carrierConfig.SymbolsPerSlot;
    
    % Kiểm tra Mapping Type A hay B
    isTypeA = strcmp(pdschConfig.MappingType, 'A'); 

    % Chọn bảng
    if dmrsConfig.DMRSLength == 1
        if isTypeA
            selectedTable = dmrs_singleA;
        else
            selectedTable = dmrs_singleB;
        end
    else
        if isTypeA
            selectedTable = dmrs_doubleA;
        else
            selectedTable = dmrs_doubleB;
        end
    end

    % Xác định l0 cho Type A
    if isfield(dmrsConfig, 'DMRSTypeAPosition') && ...
       (dmrsConfig.DMRSTypeAPosition == 3 || strcmp(dmrsConfig.DMRSTypeAPosition, 'pos3'))
        l0_typeA = 3;
    else
        l0_typeA = 2; 
    end

    % Index cho cột (pos0=1, pos1=2...)
    colIdx = dmrsConfig.DMRSAdditionalPosition + 1;

    % =====================================================================
    % 3. TÍNH DURATION & TRA BẢNG
    % =====================================================================
    nPDSCHStart = pdschConfig.SymbolAllocation(1);
    nPDSCHSym = pdschConfig.SymbolAllocation(end);
    
    symbolset = nPDSCHStart : nPDSCHStart + nPDSCHSym - 1;
    symbolset = symbolset(symbolset < symbperslot);

    [lb, ub] = bounds(symbolset);
    if isTypeA
        lb = 0; % Type A tính thời lượng từ đầu slot
    end
    nsymbols = ub - lb + 1;

    if dmrsConfig.DMRSLength == 2 && nsymbols <= 4
        error('Invalid DMRSLength=2 for l_d <= 4');
    end


    % Tra cứu
    rawSymbols = [];
    if nsymbols > 0 && nsymbols <= size(selectedTable, 1) && colIdx <= size(selectedTable, 2)
        rawSymbols = selectedTable{nsymbols, colIdx};
    end

    if isempty(rawSymbols)
        dmrssymbolset = []; ldash = []; return;
    end

    if rawSymbols(end) == -1, rawSymbols(end) = 11; end

    % =====================================================================
    % 4. MAP VÀO RESOURCE GRID & EXPAND
    % =====================================================================
    if isTypeA
        dmrssymbolset = rawSymbols;
        if ~isempty(dmrssymbolset), dmrssymbolset(1) = l0_typeA; end
    else
        dmrssymbolset = rawSymbols + nPDSCHStart;
    end

    % Expand Double Symbol
    if dmrsConfig.DMRSLength == 2
        % [l1, l2] -> [l1, l1+1, l2, l2+1]
        dmrssymbolset = [dmrssymbolset; dmrssymbolset+1];
        dmrssymbolset = dmrssymbolset(:).';
        ldash = repmat([0, 1], 1, length(dmrssymbolset)/2);
    else
        ldash = zeros(size(dmrssymbolset));
    end

    % =====================================================================
    % 5. FILTERING: CHỈ GIỮ LẠI SYMBOL HỢP LỆ
    % =====================================================================
    % Loại bỏ các DM-RS nằm ngoài vùng cấp phát của PDSCH
    validMask = ismember(dmrssymbolset, symbolset);

    if isempty(dmrssymbolset)
        error('No valid DM-RS symbols inside PDSCH allocation');
    end
    
    dmrssymbolset = dmrssymbolset(validMask);
    ldash = ldash(validMask);
end