clc; clear; close all;
setupPath();

% =========================================================
% 1. CẤU HÌNH HỆ THỐNG (Khởi tạo biến config)
% =========================================================
config.Num_UEs = 1000;           % Tổng số người dùng (UEs) trong cell
config.SubcarrierSpacing = 30; % 30 kHz (Ví dụ cho 5G NR)
config.NSizeGrid = 273;        % Băng thông (số PRBs)
config.SNR_dB = 30;            % Mức nhiễu mô phỏng
config.MCS = 27;                % Chỉ số MCS
config.PRBSet = 0:272;         % Cấp phát toàn bộ băng tần

% =========================================================================
% 2. Prepare precoder matrix W for all UEs
% =========================================================================
disp('--- Generating data for 10,000 UEs (32T32R) ---');
[W_all, UE_Reported_Indices] = prepareData(config);

% =========================================================================
% 3. Pre-Processing: Build representative UE pool via K-Means clustering
% =========================================================================
poolConfig = struct();
poolConfig.numClusters    = 50;
poolConfig.targetPoolSize = 200;
poolConfig.kmeansMaxIter  = 100;

disp('--- Running K-Means to build Representative Pool ---');
[W_pool, pool_indices] = buildRepresentativePool(W_all, poolConfig);

maxTrials = 1000;

found = false;

pdsch = customPDSCHConfig;
pdsch.DMRS.DMRSConfigurationType = 1;
pdsch.DMRS.DMRSLength = 2; % <--- THÊM DÒNG NÀY (Double Symbol DMRS)
pdsch.DMRS.DMRSAdditionalPosition = 1;
pdsch.NumLayers = 2;
pdsch.PRBSet = 0:272;
pdsch.DMRS.NumCDMGroupsWithoutData = 2;

carrier = nrCarrierConfig;
carrier.SubcarrierSpacing = 30;
% With 273 RB, we need scs 30 
carrier.NSizeGrid = 273;

for t = 1:maxTrials
    idx = randperm(length(W_pool), 2);
    i = idx(1);
    j = idx(2);

    W1 = W_pool(:,:,i);
    W2 = W_pool(:,:,j);

    % run simulation
    [BER1, BER2] = muMimo(...
        carrier, pdsch, ...
        W1, W2, 27, 30 ...
    );

    if BER1 == 0 && BER2 == 0
        disp("FOUND GOOD PAIR!");
        found = true;
        disp(W1);
        disp(W2);
        break;
    end
end

if ~found
    disp("No good pair found");
end

% -------------------------------------------------------------------
% Local function
% -------------------------------------------------------------------
function [BER1, BER2] = muMimo(...
    carrier, basePDSCHConfig, ...
    UE1_W, UE2_W, MCS, SNR_dB ...
)
    
    % -----------------------------------------------------------------
    % UE1 Configuration
    % -----------------------------------------------------------------
    pdsch = basePDSCHConfig; 

    % pdsch.DMRS.DMRSPortSet = [0, 1, 2, 3]; 
    pdsch.DMRS.DMRSPortSet = [0, 1]; 
    pdsch = pdsch.setMCS(MCS);
    pdsch.DMRS.NumCDMGroupsWithoutData = 2;

    [~, pdschInfo] = nrPDSCHIndices(carrier, pdsch);
    NREPerPRB = pdschInfo.NREPerPRB;

    % Get the optimize input length for transmit
    TBS = nrTBS(pdsch.Modulation, pdsch.NumLayers, ...
                length(pdsch.PRBSet), NREPerPRB, pdsch.TargetCodeRate);
    inputBits = randi([0 1], TBS, 1);

    % -----------------------------------------------------------------
    % UE2 Configuration
    % -----------------------------------------------------------------
    pdsch2 = pdsch; 
    % pdsch2.DMRS.DMRSPortSet = [4, 5, 6, 7]; 
    pdsch2.DMRS.DMRSPortSet = [2, 3]; 
    pdsch2 = pdsch2.setMCS(MCS);
    pdsch2.DMRS.NumCDMGroupsWithoutData = 2;

    [~, pdschInfo] = nrPDSCHIndices(carrier, pdsch2);
    NREPerPRB = pdschInfo.NREPerPRB;

    TBS2 = nrTBS(pdsch2.Modulation, pdsch2.NumLayers, ...
                length(pdsch2.PRBSet), NREPerPRB, pdsch2.TargetCodeRate);
    inputBits2 = randi([0 1], TBS2, 1);

    H_composite = [UE1_W.'; UE2_W.'];

    numTx = size(UE1_W, 1);
    W_total_T = getMMSEPrecoder(H_composite, SNR_dB, numTx);

    % Extract W precoding from the Final W after MMSE
    nLayers1 = size(UE1_W, 2);
    W_transposed = W_total_T(1:nLayers1, :);      
    W2_transposed = W_total_T(nLayers1+1:end, :);  

    % W_transposed = UE1_W.';      
    % W2_transposed = UE2_W.';  

    % -----------------------------------------------------------------
    % PDSCH Modulation
    % -----------------------------------------------------------------
    [layerMappedSym, pdschInd] = PDSCHEncode(pdsch, carrier, inputBits);
    [layerMappedSym2, pdschInd2] = PDSCHEncode(pdsch2, carrier, inputBits2);

    % -----------------------------------------------------------------
    % Precoding 
    % -----------------------------------------------------------------
    [antsym, antind] = nrPDSCHPrecode(carrier, layerMappedSym, pdschInd, W_transposed);
    [antsym2, antind2] = nrPDSCHPrecode(carrier, layerMappedSym2, pdschInd2, W2_transposed);

    % -----------------------------------------------------------------
    % DMRS
    % -----------------------------------------------------------------
    dmrsSym = nrPDSCHDMRS(carrier, pdsch);
    dmrsInd = nrPDSCHDMRSIndices(carrier, pdsch);
    [dmrsAntSym, dmrsAntInd] = nrPDSCHPrecode(carrier, dmrsSym, dmrsInd, W_transposed);

    dmrsSym2 = nrPDSCHDMRS(carrier, pdsch2);
    dmrsInd2 = nrPDSCHDMRSIndices(carrier, pdsch2);
    [dmrsAntSym2, dmrsAntInd2] = nrPDSCHPrecode(carrier, dmrsSym2, dmrsInd2, W2_transposed);

    % -----------------------------------------------------------------
    % Resource Mapping
    % -----------------------------------------------------------------
    numPorts = size(W_transposed, 2);

    txGrid = nrResourceGrid(carrier, numPorts); 

    txGrid(antind) = antsym;
    txGrid(dmrsAntInd) = dmrsAntSym;

    txGrid(antind2) = txGrid(antind2) + antsym2;
    txGrid(dmrsAntInd2) = txGrid(dmrsAntInd2) + dmrsAntSym2;

    % OFDM Modulation
    txWaveform = nrOFDMModulate(carrier, txGrid);

    % -----------------------------------------------------------------
    % Channel
    % -----------------------------------------------------------------
    rxWaveformUE1_clean = txWaveform * UE1_W; 
    rxWaveformUE2_clean = txWaveform * UE2_W;

    rxWaveformUE1 = awgn(rxWaveformUE1_clean, SNR_dB, 'measured');
    rxWaveformUE2 = awgn(rxWaveformUE2_clean, SNR_dB, 'measured');

    % -----------------------------------------------------------------
    % RX
    % -----------------------------------------------------------------

    % -----------------------------------------------------------------
    % Extract data for UE1
    % -----------------------------------------------------------------
    % OFDM Demodulation
    rxBits = rxPDSCHDecode(carrier, pdsch, rxWaveformUE1, txWaveform, TBS);

    numErrors = biterr(double(inputBits), double(rxBits));
    BER1 = numErrors / TBS;

    % -----------------------------------------------------------------
    % Extract Data for UE2
    % -----------------------------------------------------------------
    rxBits2 = rxPDSCHDecode(carrier, pdsch2, rxWaveformUE2, txWaveform, TBS2);

    numErrors2 = biterr(double(inputBits2), double(rxBits2));
    BER2 = numErrors2 / TBS2;
end

function rxBits = rxPDSCHDecode(carrier, pdsch, rxWaveform, txWaveform, TBS)
    pdschInd = nrPDSCHIndices(carrier, pdsch);

    dmrsSym = nrPDSCHDMRS(carrier, pdsch);
    dmrsInd = nrPDSCHDMRSIndices(carrier, pdsch);

    % LÝ THUYẾT: Kênh truyền ma trận không có độ trễ lan truyền. 
    % Buộc offset = 0 để tránh nhiễu tương quan làm trượt cửa sổ FFT.
    offset = 0; 

    rxWaveformSync = rxWaveform(1+offset:end, :);

    samplesNeeded = length(txWaveform); 

    if size(rxWaveformSync, 1) < samplesNeeded
        padding = samplesNeeded - size(rxWaveformSync, 1);
        rxWaveformSync = [rxWaveformSync; zeros(padding, size(rxWaveformSync, 2))];
    end

    rxGrid = nrOFDMDemodulate(carrier, rxWaveformSync);
    rxGrid = rxGrid(1:carrier.NSizeGrid*12, 1:carrier.SymbolsPerSlot, :);

    [Hest, nVar] = nrChannelEstimate(carrier, rxGrid, dmrsInd, dmrsSym, ...
    'CDMLengths', pdsch.DMRS.CDMLengths, ... 
    'AveragingWindow', [11 3]); % <--- SỬA DÒNG NÀY

    [pdschRx, pdschHest] = nrExtractResources(pdschInd, rxGrid, Hest);
    eqSymbols = nrEqualizeMMSE(pdschRx, pdschHest, nVar);

    % LÝ THUYẾT: Truyền phương sai nhiễu nVar thực tế từ kênh vào khối giải mã
    rxBits = PDSCHDecode(pdsch, carrier, eqSymbols, TBS, nVar);
end

% -----------------------------------------------------------------
% This function performs the full PDSCH decoding chain
% -----------------------------------------------------------------
function [out, hasError] = PDSCHDecode(pdsch, carrier, eqSymbols, TBS, nVar)

    % -----------------------------------------------------------------
    % DEMODULATION & DESCRAMBLING
    % -----------------------------------------------------------------
    demappedSym_Cell = nrLayerDemap(eqSymbols);
    sym_to_demod = demappedSym_Cell{1}; 

    % LÝ THUYẾT: Sử dụng trực tiếp nVar để tính LLR chuẩn xác
    rawLLR = nrSymbolDemodulate(sym_to_demod, pdsch.Modulation, nVar);

    if isempty(pdsch.NID)
        nid = carrier.NCellID; 
    else
        nid = pdsch.NID(1); 
    end
    
    c_seq_rx = nrPDSCHPRBS(nid, pdsch.RNTI, 0, length(rawLLR));
    descrambledBits = rawLLR .* (1 - 2*double(c_seq_rx));

    % -----------------------------------------------------------------
    % RATE RECOVERY
    % -----------------------------------------------------------------
    rv = 0; 
    raterecovered = nrRateRecoverLDPC(descrambledBits, TBS, pdsch.TargetCodeRate, ...
                                      rv, pdsch.Modulation, pdsch.NumLayers);

    % -----------------------------------------------------------------
    % DECODING CHAIN (LDPC & CRC)
    % -----------------------------------------------------------------
    crcEnc_dummy = zeros(TBS + 24, 1); 
    bgn_rx = baseGraphSelection(crcEnc_dummy, pdsch.TargetCodeRate);

    MAX_ITER = 25;
    [decBits, ~] = nrLDPCDecode(raterecovered, bgn_rx, MAX_ITER, ...
                        'Algorithm', 'Normalized min-sum', ...
                        'ScalingFactor', 0.75);

    [rxPart, ~] = nrCodeBlockDesegmentLDPC(decBits, bgn_rx, TBS + 24);
    [out, hasError] = nrCRCDecode(rxPart, '24A');
end

function [W_all, UE_Reported_Indices] = prepareData(config)
    % 1. Lấy số lượng UEs từ config (Sửa lỗi chưa khai báo biến)
    Num_UEs = config.Num_UEs; 
    
    nLayers = 2; % Rank = 4

    % --- ĐỒNG NHẤT TÊN STRUCT (CodeBookConfig) ---
    cfg = struct();
    cfg.CodeBookConfig.CodebookType = 'typeII-r16';
    cfg.CodeBookConfig.N1 = 2;
    cfg.CodeBookConfig.N2 = 1; 
    
    Num_Antennas = 2 * cfg.CodeBookConfig.N1 * cfg.CodeBookConfig.N2;

    % Bắt buộc paramCombination = 1 hoặc 2 khi cấu hình 4 Port
    cfg.CodeBookConfig.ParamCombination = 2; % L=2, Beta=1/2, pv=1/8 (cho 4 layer)
    cfg.CodeBookConfig.NumberOfPMISubbandsPerCQISubband = 1; % R = 1
    cfg.CodeBookConfig.TypeIIRIRestriction = []; 
    cfg.CodeBookConfig.SubbandAmplitude = true;

    % O1, O2 tương ứng cho N1=2, N2=1
    cfg.CodeBookConfig.O1 = 4;
    cfg.CodeBookConfig.O2 = 4;

    % Cấu hình Grid (Để ra N3 = 32)
    cfg.CSIReportConfig.SubbandSize = 4; 
    cfg.CarrierConfig.NStartGrid = 0;
    cfg.CarrierConfig.NSizeGrid = 128; 

    % --- 2. KHỞI TẠO TRƯỚC BỘ NHỚ CHO ĐẦU RA ---
    W_all = zeros(Num_Antennas, nLayers, Num_UEs);
    UE_Reported_Indices = cell(Num_UEs, 1);

    % --- 3. VÒNG LẶP LƯU DỮ LIỆU ---
    for u = 1:Num_UEs
        % Tạo random PMI
        PMI = randomTypeIIEnhancedPMI(cfg, nLayers);

        % Tạo Precoder matrix từ PMI
        W = generateEnhancedTypeIIPrecoder(cfg, nLayers, PMI.i1, PMI.i2);
        
        % Nếu W trả về là 3D (có chứa subband), lấy Wideband (hoặc subband đầu tiên)
        % Để phù hợp với mảng yêu cầu của Scheduler: [Num_Antennas x nLayers x Num_UEs]
        if ndims(W) == 3
            W = W(:, :, 1); % Lấy subband đầu tiên làm đại diện (có thể đổi thành mean(W, 3) tùy hệ thống)
        end

        % Lưu kết quả vào biến đầu ra
        W_all(:, :, u) = W;
        UE_Reported_Indices{u} = PMI;
    end
    
    % In ra kích thước thực tế để kiểm tra
    fprintf('W_all completed: [%d x %d x %d]\n\n', size(W_all, 1), size(W_all, 2), size(W_all, 3));
end

function [W_pool, pool_indices] = buildRepresentativePool(W_all, config)
    % --- 1. LẤY CẤU HÌNH ---
    numClusters    = getField(config, 'numClusters',    50);
    targetPoolSize = getField(config, 'targetPoolSize', 200);
    kmeansMaxIter  = getField(config, 'kmeansMaxIter',  100);
    minPerCluster  = getField(config, 'minPerCluster',  1);

    [Num_Antennas, ~, Num_UEs] = size(W_all);

    % Guard: Không thể có nhiều cụm hơn số UE
    numClusters = min(numClusters, Num_UEs);

    % --- 2. TỐI ƯU HÓA: TRÍCH XUẤT ĐẶC TRƯNG (VECTORIZATION) ---
    % Dùng pagemtimes để nhân ma trận 3D siêu tốc thay vì vòng lặp for
    % G_3D có kích thước [Num_Antennas x Num_Antennas x Num_UEs]
    G_3D = pagemtimes(W_all, 'none', W_all, 'ctranspose');
    
    % Dàn phẳng (Flatten) ma trận
    G_flat = reshape(G_3D, Num_Antennas^2, Num_UEs).'; % Kích thước: [Num_UEs x Num_Antennas^2]
    
    % FIX QUAN TRỌNG: Lấy cả phần thực và phần ảo để giữ thông tin hướng sóng
    W_features = [real(G_flat), imag(G_flat)]; 

    % --- 3. PHÂN CỤM (CLUSTERING) ---
    fprintf('Running K-means (%d clusters) on %d UEs...\n', numClusters, Num_UEs);
    [cluster_idx, ~] = kmeans(W_features, numClusters, ...
                              'Distance', 'sqeuclidean', ...
                              'MaxIter',  kmeansMaxIter, ...
                              'Replicates', 3); % Tránh local minima

    % --- 4. TỐI ƯU HÓA: LẤY MẪU TỶ LỆ (PROPORTIONAL SAMPLING) ---
    % Preallocate mảng kết quả
    pool_indices = zeros(targetPoolSize + numClusters, 1);
    ptr = 0;

    for c = 1:numClusters
        members   = find(cluster_idx == c);
        n_members = length(members);
        if n_members == 0, continue; end

        % Số mẫu tỷ lệ với kích thước cụm, tối thiểu minPerCluster
        n_pick = max(minPerCluster, round(targetPoolSize * n_members / Num_UEs));
        n_pick = min(n_pick, n_members);

        % Chọn ngẫu nhiên n_pick thành viên
        members = members(randperm(n_members));
        pool_indices(ptr+1 : ptr+n_pick) = members(1:n_pick);
        ptr = ptr + n_pick;
    end

    % Cắt bỏ phần thừa và lấy dữ liệu
    pool_indices = pool_indices(1:ptr);
    W_pool       = W_all(:, :, pool_indices);

    fprintf('Representative pool: %d UEs from %d clusters (target: %d).\n\n', ...
            length(pool_indices), numClusters, targetPoolSize);
end

function val = getField(s, fname, default)
    if isfield(s, fname)
        val = s.(fname);
    else
        val = default;
    end
end
