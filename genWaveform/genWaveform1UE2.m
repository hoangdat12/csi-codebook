clear; clc; close all;

setupPath();

ALL_Case = [
    % Case 1: Default
    struct('desc', 'Case 1: Default', ...
           'NLAYERS', 2, 'MCS', 27, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 1, ...
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20001, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', 'UE2_PDSCH_Waveform_4P2V');
];    

N1 = 2; N2 = 1; O1 = 4; O2 = 1;

% -----------------------------------------------------------------
% Configuration Parameters
% -----------------------------------------------------------------
for caseIdx = 1:length(ALL_Case)
    % -----------------------------------------------------------------
    % Carrier Configuration
    % -----------------------------------------------------------------
    carrier = nrCarrierConfig;
    
    % Lấy dữ liệu từ struct hiện tại bằng ALL_Case(caseIdx).
    carrier.SubcarrierSpacing = ALL_Case(caseIdx).SUBCARRIER_SPACING;  
    carrier.NSizeGrid         = ALL_Case(caseIdx).NSIZE_GRID;
    carrier.CyclicPrefix      = ALL_Case(caseIdx).CYCLIC_PREFIX;
    carrier.NSlot             = ALL_Case(caseIdx).NSLOT;
    carrier.NFrame            = ALL_Case(caseIdx).NFRAME;
    carrier.NCellID           = ALL_Case(caseIdx).NCELL_ID;

    % -----------------------------------------------------------------
    % PDSCH Configuration
    % -----------------------------------------------------------------
    pdsch = customPDSCHConfig(); 

    pdsch.DMRS.DMRSConfigurationType     = ALL_Case(caseIdx).DMRS_CONFIGURATION_TYPE; 
    pdsch.DMRS.DMRSTypeAPosition         = ALL_Case(caseIdx).DMRS_TYPEA_POSITION; 
    pdsch.DMRS.NumCDMGroupsWithoutData   = ALL_Case(caseIdx).DMRS_NUMCDMGROUP_WITHOUT_DATA;
    pdsch.DMRS.DMRSLength                = ALL_Case(caseIdx).DMRS_LENGTH;
    pdsch.DMRS.DMRSAdditionalPosition    = ALL_Case(caseIdx).DMRS_ADDITIONAL_POSITION; % <--- Ánh xạ trường mới thêm

    pdsch.NumLayers   = ALL_Case(caseIdx).NLAYERS;
    pdsch.MappingType = ALL_Case(caseIdx).PDSCH_MAPPING_TYPE;
    pdsch.RNTI        = ALL_Case(caseIdx).PDSCH_RNTI;
    pdsch.PRBSet      = ALL_Case(caseIdx).PDSCH_PRBSET;
    pdsch.SymbolAllocation = [ALL_Case(caseIdx).PDSCH_START_SYMBOL, 14 - ALL_Case(caseIdx).PDSCH_START_SYMBOL];

    % Table 5.1.3.1-2: MCS index table 2 for PDSCH - 138 214
    % https://www.etsi.org/deliver/etsi_ts/138200_138299/138214/18.06.00_60/ts_138214v180600p.pdf
    % In this code using TABLE 2
    pdsch = pdsch.setMCS(ALL_Case(caseIdx).MCS);

    % -----------------------------------------------------------------
    % Generate Bits
    % -----------------------------------------------------------------
    TBS = manualCalculateTBS(pdsch)

    inputBits = ones(TBS, 1);

    % -----------------------------------------------------------------
    % PDSCH Modulation
    % -----------------------------------------------------------------
    [layerMappedSym, pdschInd] = myPDSCHEncode(pdsch, carrier, inputBits);

    dmrsSym = genDMRS(carrier, pdsch);
    dmrsInd = DMRSIndices(pdsch, carrier);

    cfg = struct();
    cfg.CodebookConfig.N1 = N1;
    cfg.CodebookConfig.N2 = N2;
    cfg.CodebookConfig.O1 = O1;
    cfg.CodebookConfig.O2 = O2;
    cfg.CodebookConfig.nPorts = 2*N1*N2;
    cfg.CodebookConfig.codebookMode = 1;

    W = [
        0.2132 - 0.1066i  -0.0845 - 0.0845i;
        0.2132 + 0.1066i  -0.0845 + 0.0845i;
        0.4264 + 0.1066i   0.4781 + 0.0845i;
        0.4264 - 0.1066i   0.4781 - 0.0845i
    ];

    % =========================================================================
    % 1. PRECODING TRỰC TIẾP TRÊN SYMBOL (Không dùng Grid 3 chiều)
    % =========================================================================
    % layerMappedSym có kích thước [Số REs x nLayers]
    % Phép nhân ma trận này sẽ trả ra kích thước [Số REs x nPorts]
    precodedPdschSym = layerMappedSym * (W.');
    precodedDmrsSym  = dmrsSym * (W.');

    % Lấy index 2D (cột 1) để dùng chung cho mọi Antenna Ports. 
    % (Vị trí RE trên grid 2D là giống nhau đối với mọi port)
    pdschInd_2D = pdschInd(:, 1);
    dmrsInd_2D  = dmrsInd(:, 1);

    % =========================================================================
    % 2. MAPPING TRỰC TIẾP LÊN FRAME GRID THEO TỪNG PORT
    % =========================================================================
    nPorts = size(W, 1);
    K = carrier.NSizeGrid * 12;
    % Khởi tạo Frame Grid 3 chiều chỉ để lưu trữ cuối cùng (K x 280 x 4)
    frameGrid = zeros(K, 280, nPorts); 

    symbolsPerSlot = carrier.SymbolsPerSlot;
    currentSlotIdx = carrier.NSlot; 

    startSym = currentSlotIdx * symbolsPerSlot + 1;
    endSym = (currentSlotIdx + 1) * symbolsPerSlot;

    % Vòng lặp map lên grid 2D của từng Port
    for p = 1:nPorts
        % Tạo slot grid 2D trống cho port hiện tại
        slotGrid2D = zeros(K, symbolsPerSlot);

        % Mapping data và DMRS đã precoded lên grid 2D
        slotGrid2D(pdschInd_2D) = precodedPdschSym(:, p);
        slotGrid2D(dmrsInd_2D)  = precodedDmrsSym(:, p);
        
        % Đưa slot grid 2D này vào đúng vị trí trên Frame tổng
        frameGrid(:, startSym:endSym, p) = slotGrid2D;
    end

    NFFT = 4096; % Kích thước IFFT
    numRe = size(frameGrid, 1); 
    numSymb = size(frameGrid, 2); 

    numTxPorts = 4;

    txDataF_Port1 = [frameGrid(numRe/2+1:end, :, 1); ...
                    zeros(NFFT - numRe, numSymb); ...
                    frameGrid(1:numRe/2, :, 1)];

    txDataF_Port2 = [frameGrid(numRe/2+1:end, :, 2); ...
                    zeros(NFFT - numRe, numSymb); ...
                    frameGrid(1:numRe/2, :, 2)];
                    
    txDataF_Port3 = [frameGrid(numRe/2+1:end, :, 3); ...
                    zeros(NFFT - numRe, numSymb); ...
                    frameGrid(1:numRe/2, :, 3)];
                    
    txDataF_Port4 = [frameGrid(numRe/2+1:end, :, 4); ...
                    zeros(NFFT - numRe, numSymb); ...
                    frameGrid(1:numRe/2, :, 4)];       

    temp_txdata1 = ofdmModulation(txDataF_Port1, NFFT);
    temp_txdata2 = ofdmModulation(txDataF_Port2, NFFT);
    temp_txdata3 = ofdmModulation(txDataF_Port3, NFFT);
    temp_txdata4 = ofdmModulation(txDataF_Port4, NFFT);

    txdata1 = [temp_txdata1, temp_txdata2, temp_txdata3, temp_txdata4];

    centerFreq = 0;
    nchannel = numTxPorts; 
    nFrame = 5; 
    scs = 30000; % SCS 30kHz
    data_repeat = repmat(txdata1, nFrame, 1); 
    savevsarecordingmulti(ALL_Case(caseIdx).FILE_NAME, data_repeat, NFFT*scs, centerFreq, nchannel);

    exportFileName = 'PDSCH_4P2V_TypeII_ExportData.mat'; 

    fprintf('\n======================================================\n');
    fprintf(' BẮT ĐẦU SO SÁNH CHI TIẾT RESOURCE GRID \n');
    fprintf('======================================================\n');

    % 1. Load dữ liệu từ Code 1
    if exist(exportFileName, 'file')
        data_code1 = load(exportFileName);
    else
        error('Không tìm thấy file %s. Hãy chắc chắn bạn đã chạy Code 1.', exportFileName);
    end

    RG_code1 = data_code1.RG;

    % 2. Xử lý Resource Grid tại Slot 0
    numSubcarriers = 3276; % 273 PRB * 12
    numSymbols = 14;
    numRE_per_Slot = numSubcarriers * numSymbols; 
    numPorts = 4;

    % Lấy Data Grid Slot 0 của Code 1 (Kích thước: 45864 x 4)
    grid1_slot0 = RG_code1(1:numRE_per_Slot, :); 

    % Lấy Data Grid Slot 0 của Code 2 (Kích thước: 3276 x 14 x 4)
    grid2_slot0 = frameGrid(:, 1:14, :); 
    % Reshape Code 2 về [45864 x 4] để map 1-1 với Code 1
    grid2_slot0_reshaped = reshape(grid2_slot0, numRE_per_Slot, numPorts);

    % 3. Tìm các vị trí lệch nhau
    threshold = 1e-5; % Ngưỡng sai số (bỏ qua sai số do làm tròn dấu phẩy động của MATLAB)
    diff_Grid = abs(grid1_slot0 - grid2_slot0_reshaped);

    % Tìm linear index của các điểm bị lệch
    [err_rows, err_ports] = find(diff_Grid > threshold);

    if isempty(err_rows)
        fprintf('\n=> TUYỆT VỜI! KẾT QUẢ KHỚP NHAU 100%% TẠI MỌI VỊ TRÍ RE.\n');
    else
        total_errors = length(err_rows);
        fprintf('\n=> PHÁT HIỆN %d VỊ TRÍ CÓ SAI LỆCH GIỮA 2 CODE!\n\n', total_errors);
        
        % --- CHUYỂN ĐỔI LINEAR INDEX SANG TỌA ĐỘ (SUBCARRIER, SYMBOL) ---
        % Vì reshape hoạt động theo cột (Subcarrier chạy hết rồi mới tới Symbol)
        err_subcarriers = mod(err_rows - 1, numSubcarriers) + 1;
        err_symbols = floor((err_rows - 1) / numSubcarriers) + 1;
        
        % --- THỐNG KÊ LỖI THEO SYMBOL ---
        % Điều này rất quan trọng để biết lỗi do DMRS hay do Data
        fprintf('--- THỐNG KÊ LỖI THEO OFDM SYMBOL ---\n');
        unique_symbols = unique(err_symbols);
        for i = 1:length(unique_symbols)
            sym = unique_symbols(i);
            count_per_sym = sum(err_symbols == sym);
            
            % Gợi ý loại tín hiệu (Symbol 3 trong cấu hình Type A Pos 2 thường là DMRS)
            if sym == 3 || sym == 12 % Tùy thuộc vào additional position
                sig_type = 'Rất có thể là DMRS (hoặc PTRS)';
            else
                sig_type = 'Rất có thể là PDSCH Data';
            end
            fprintf(' - Symbol %2d : %6d lỗi (%s)\n', sym, count_per_sym, sig_type);
        end
        
        % --- IN RA 15 VỊ TRÍ LỖI ĐẦU TIÊN ĐỂ SOI CHI TIẾT ---
        fprintf('\n--- CHI TIẾT 15 VỊ TRÍ LỆCH ĐẦU TIÊN ---\n');
        fprintf('%-6s | %-12s | %-8s | %-6s | %-20s | %-20s | %-12s\n', ...
                'STT', 'Subcarrier', 'Symbol', 'Port', 'Giá trị Code 1', 'Giá trị Code 2', 'Độ lệch (Abs)');
        fprintf(repmat('-', 1, 100));
        fprintf('\n');
        
        num_display = min(15, total_errors);
        for k = 1:num_display
            r = err_rows(k);
            p = err_ports(k);
            sub_c = err_subcarriers(k);
            sym_b = err_symbols(k);
            
            val1 = grid1_slot0(r, p);
            val2 = grid2_slot0_reshaped(r, p);
            diff_val = diff_Grid(r, p);
            
            % Format số phức để in ra màn hình
            str_val1 = sprintf('%6.3f + %6.3fi', real(val1), imag(val1));
            str_val2 = sprintf('%6.3f + %6.3fi', real(val2), imag(val2));
            
            fprintf('%-6d | %-12d | %-8d | %-6d | %-20s | %-20s | %e\n', ...
                    k, sub_c, sym_b, p, str_val1, str_val2, diff_val);
        end
        
        if total_errors > 15
            fprintf('... (Còn %d vị trí lỗi khác không hiển thị)\n', total_errors - 15);
        end
    end
    fprintf('\n======================================================\n');
end