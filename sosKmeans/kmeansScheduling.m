% =========================================================================
% SCRIPT: ĐÁNH GIÁ BER CHỈ SỬ DỤNG K-MEANS SCHEDULING (KHÔNG DÙNG SOS)
% Antenna: 32T32R | Evaluate Group Sizes: 2 to 12
% =========================================================================
clear; clc; close all;
setupPath();

% =========================================================================
% 1. Configuration for test — 32T32R
% =========================================================================
prepareDataConfig = struct();
prepareDataConfig.Num_UEs           = 60000;
prepareDataConfig.N1                = 8;   % 8x4 = 32 Tx ports
prepareDataConfig.N2                = 4;
prepareDataConfig.O1                = 4;
prepareDataConfig.O2                = 4;
prepareDataConfig.L                 = 2;
prepareDataConfig.NumLayers         = 1;
prepareDataConfig.subbandAmplitude  = true;
prepareDataConfig.PhaseAlphabetSize = 8;

% =========================================================================
% 2. Prepare precoder matrix W for all UEs
% =========================================================================
disp('--- Generating data for 60,000 UEs (32T32R) ---');
[W_all, UE_Reported_Indices] = prepareData(prepareDataConfig);

% =========================================================================
% 3. Pre-Processing: Build representative UE pool via K-Means clustering
% =========================================================================
poolConfig = struct();
poolConfig.numClusters    = 100;
poolConfig.targetPoolSize = 500;
poolConfig.kmeansMaxIter  = 100;

disp('--- Running K-Means to build Representative Pool ---');
[W_pool, pool_indices] = buildRepresentativePool(W_all, poolConfig);

% =========================================================================
% 4. PHY Layer Configuration — 32T32R
% =========================================================================
phyConfig = struct();
phyConfig.MCS               = 4;
phyConfig.SNR_dB            = 20;
phyConfig.PRBSet            = 0:272;
phyConfig.SubcarrierSpacing = 30;
phyConfig.NSizeGrid         = 273;

% =========================================================================
% 5. ĐÁNH GIÁ TỶ LỆ LỖI (BER) CHỈ DÙNG K-MEANS (Group Size: 2 -> 12)
% =========================================================================
groupSizes = 2:16;
numTestPoints = length(groupSizes);

BER_KMeansOnly_Avg = zeros(1, numTestPoints);
test_numClusters = 100; % Số lượng cụm dùng cho K-Means Only trên W_pool

disp('=== BẮT ĐẦU CHẠY MÔ PHỎNG PHY CHO K-MEANS ONLY ===');

for idx = 1:numTestPoints
    gs = groupSizes(idx);
    fprintf('\n======================================================\n');
    fprintf('--- Đang chạy mô phỏng cho Group Size = %d ---\n', gs);
    
    % Lập lịch bằng K-Means Only trực tiếp trên W_pool
    [bestGroups_KMeans, ~] = runKMeansOnlyScheduling(W_pool, gs, test_numClusters);
    
    % Tính toán BER cho nhóm được chọn
    BER_list_KM = simulateMuMimoGroup(W_pool, bestGroups_KMeans, phyConfig, gs);
    
    % Lưu trung bình BER
    BER_KMeansOnly_Avg(idx) = mean(BER_list_KM);
    
    fprintf('=> Trung bình BER cho Group Size %d: %.6f\n', gs, BER_KMeansOnly_Avg(idx));
end

% =========================================================================
% 6. VẼ ĐỒ THỊ TỶ LỆ LỖI (BER)
% =========================================================================
figure('Name', 'Đánh giá BER của K-Means Only', 'Position', [200, 200, 700, 500]);

semilogy(groupSizes, BER_KMeansOnly_Avg, '-or', 'LineWidth', 2, ...
    'MarkerSize', 8, 'MarkerFaceColor', 'r');
grid on; hold on;

title('Tỷ lệ lỗi (BER) khi chỉ dùng K-Means lập lịch', 'FontSize', 14);
xlabel('Kích thước nhóm (Group Size)', 'FontSize', 12);
ylabel('Trung bình Bit Error Rate (BER)', 'FontSize', 12);
set(gca, 'XTick', groupSizes);
set(gca, 'YMinorGrid', 'on');

xline(12, '--k', 'Giới hạn 12 DMRS Ports', 'LabelOrientation', 'horizontal', 'LabelHorizontalAlignment', 'left');


% =========================================================================
% LOCAL FUNCTIONS 
% =========================================================================

function [W_all, UE_Reported_Indices] = prepareData(config)

    % --- Read configuration fields (with default values) ---
    Num_UEs           = getField(config, 'Num_UEs',           20000);
    N1                = getField(config, 'N1',                4);
    N2                = getField(config, 'N2',                1);
    O1                = getField(config, 'O1',                4);
    O2                = getField(config, 'O2',                1);
    L                 = getField(config, 'L',                 2);
    NumLayers         = getField(config, 'NumLayers',         1);
    subbandAmplitude  = getField(config, 'subbandAmplitude',  true);
    PhaseAlphabetSize = getField(config, 'PhaseAlphabetSize', 8);

    % --- Generate random PMI indices for all UEs ---
    fprintf('Generating PMI configuration for %d UEs...\n', Num_UEs);
    UE_Reported_Indices = randomPMIConfig(Num_UEs, N1, N2, O1, O2, L, NumLayers, subbandAmplitude);

    % --- Build cfg struct for generateTypeIIPrecoder ---
    cfg = struct();
    cfg.CodebookConfig.N1                = N1;
    cfg.CodebookConfig.N2                = N2;
    cfg.CodebookConfig.O1                = O1;
    cfg.CodebookConfig.O2                = O2;
    cfg.CodebookConfig.NumberOfBeams     = L;
    cfg.CodebookConfig.PhaseAlphabetSize = PhaseAlphabetSize;
    cfg.CodebookConfig.SubbandAmplitude  = subbandAmplitude;
    cfg.CodebookConfig.numLayers         = NumLayers;

    % --- Compute precoder matrix W_all for all UEs ---
    Num_Antennas = 2 * N1 * N2;
    W_all = zeros(Num_Antennas, NumLayers, Num_UEs);

    fprintf('Computing precoder matrix W_all...\n');
    for u = 1:Num_UEs
        indices_ue = UE_Reported_Indices{u};
        W_all(:, :, u) = generateTypeIIPrecoder(cfg, indices_ue.i1, indices_ue.i2);
    end
    fprintf('W_all completed: [%d x %d x %d]\n\n', size(W_all));

end % end prepareData

function [W_pool, pool_indices] = buildRepresentativePool(W_all, config)

    % --- Read configuration fields ---
    numClusters    = getField(config, 'numClusters',    50);
    targetPoolSize = getField(config, 'targetPoolSize', 200);
    kmeansMaxIter  = getField(config, 'kmeansMaxIter',  100);

    [Num_Antennas, NumLayers, Num_UEs] = size(W_all);

    % --- Extract features: flatten precoder matrices and split into Real/Imag parts ---
    W_flat     = reshape(W_all, Num_Antennas * NumLayers, Num_UEs).';
    W_features = [real(W_flat), imag(W_flat)];

    % --- Run K-means with cosine distance to cluster UEs by beam direction similarity ---
    fprintf('Running K-means (%d clusters) on %d UEs...\n', numClusters, Num_UEs);
    [cluster_idx, ~] = kmeans(W_features, numClusters, ...
                            'Distance', 'cosine',    ...
                            'MaxIter',  kmeansMaxIter);

    % --- Uniformly sample UEs from each cluster ---
    ues_per_cluster = ceil(targetPoolSize / numClusters);

    pool_indices = [];
    for c = 1:numClusters
        members     = find(cluster_idx == c);
        members     = members(randperm(length(members)));       % Shuffle randomly
        num_to_pick = min(ues_per_cluster, length(members));
        pool_indices = [pool_indices; members(1:num_to_pick)]; 
    end

    W_pool = W_all(:, :, pool_indices);

    fprintf('Representative pool: %d UEs from %d clusters (target: %d).\n\n', ...
            length(pool_indices), numClusters, targetPoolSize);

end

function [bestGroups, bestScore] = runKMeansOnlyScheduling(W_matrix, groupSize, numClusters)
    % =========================================================================
    % RUNKMEANSONLYSCHEDULING: Lập lịch MU-MIMO chỉ sử dụng K-Means.
    % Thuật toán: Phân cụm UEs, sau đó tạo Group bằng cách bốc ngẫu nhiên 
    % các UEs từ các cụm KHÁC NHAU để đảm bảo tính trực giao không gian.
    % =========================================================================
    
    [Num_Antennas, NumLayers, NUE] = size(W_matrix);
    numGroups = floor(NUE / groupSize); % Số lượng nhóm cần tạo ra
    
    if numClusters < groupSize
        error('Lỗi: Số lượng cụm (numClusters = %d) phải lớn hơn hoặc bằng groupSize (%d) để đảm bảo trực giao!', numClusters, groupSize);
    end
    
    % 1. Tiền xử lý: Trải phẳng Precoder và Phân cụm (K-Means)
    disp('      [K-Means Only] Computing K-Means clusters...');
    W_flat = reshape(W_matrix, Num_Antennas * NumLayers, NUE).';
    W_features = [real(W_flat), imag(W_flat)];
    
    [cluster_idx, ~] = kmeans(W_features, numClusters, 'Distance', 'cosine', 'MaxIter', 100);
    
    % 2. Gom UEs vào các "thùng" (Bins) tương ứng với từng cụm
    cluster_ues = cell(numClusters, 1);
    for c = 1:numClusters
        members = find(cluster_idx == c);
        % Trộn ngẫu nhiên thứ tự UEs trong cụm để bốc cho khách quan
        cluster_ues{c} = members(randperm(length(members)));
    end
    
    % 3. Tiến hành ghép nhóm (Scheduling)
    disp('      [K-Means Only] Forming groups from distinct clusters...');
    bestGroups = cell(numGroups, 1);
    
    for g = 1:numGroups
        % Chọn ngẫu nhiên 'groupSize' cụm khác nhau hoàn toàn
        selected_clusters = randperm(numClusters, groupSize);
        
        current_group = zeros(1, groupSize);
        for i = 1:groupSize
            c = selected_clusters(i);
            
            % Xử lý ngoại lệ: Nếu cụm này đã bị bốc hết UEs, tìm cụm đang còn nhiều UEs nhất để bốc bù
            if isempty(cluster_ues{c})
                [~, max_c] = max(cellfun(@length, cluster_ues));
                c = max_c; 
            end
            
            % Bốc UE đầu tiên ra khỏi cụm và xóa nó khỏi danh sách chờ
            current_group(i) = cluster_ues{c}(1);
            cluster_ues{c}(1) = []; 
        end
        bestGroups{g} = current_group;
    end
    
    % 4. Chấm điểm (Fitness Score) dùng hàm khoảng cách giống hệt SOS để so sánh công bằng
    disp('      [K-Means Only] Calculating final score...');
    totalDist = 0;
    numPairsPerGroup = groupSize * (groupSize - 1) / 2;
    
    for g = 1:numGroups
        ueIdx = bestGroups{g};
        groupDist = 0;
        
        % Tính tổng khoảng cách chéo (Chordal Distance) giữa các UEs trong nhóm
        for a = 1:groupSize-1
            for b = a+1:groupSize
                % Gọi lại hàm chordalDistance bạn đã có sẵn
                dist = chordalDistance(W_matrix(:,:,ueIdx(a)), W_matrix(:,:,ueIdx(b)));
                groupDist = groupDist + dist;
            end
        end
        totalDist = totalDist + groupDist / numPairsPerGroup;
    end
    
    bestScore = totalDist / numGroups;
    fprintf('      [K-Means Only] Done! Score: %.4f\n', bestScore);
end

function BER_list = simulateMuMimoGroup(W_pool, bestGroups, config, groupSize)
    fprintf('--- Starting MU-MIMO simulation for group of %d UEs ---\n', groupSize);

    best_group = bestGroups{1};
    ue_idx     = best_group(1:groupSize);

    fprintf('Selected UEs: '); fprintf('%d ', ue_idx); fprintf('from Sub-pool.\n');

    W_list  = cell(groupSize, 1);
    for u = 1:groupSize
        W_list{u} = W_pool(:, :, ue_idx(u));
    end

    nLayers     = size(W_list{1}, 2);
    totalPorts  = groupSize * nLayers;  % Total number of required DMRS ports
    MCS         = config.MCS;

    pdsch = customPDSCHConfig();
    pdsch.NumLayers = nLayers;
    pdsch.PRBSet    = config.PRBSet;
    pdsch.DMRS.DMRSAdditionalPosition = 1;

    % =========================================================
    % Select DMRS Type and Length
    % Port reuse is allowed when total streams exceed 12
    % =========================================================
    if totalPorts <= 4
        pdsch.DMRS.DMRSConfigurationType = 1;
        pdsch.DMRS.DMRSLength            = 1;
    elseif totalPorts <= 8
        pdsch.DMRS.DMRSConfigurationType = 1;
        pdsch.DMRS.DMRSLength            = 2;
    else
        % Use Type 2, Length 2 to support up to 12 orthogonal ports
        pdsch.DMRS.DMRSConfigurationType = 2;
        pdsch.DMRS.DMRSLength            = 2;
        if totalPorts > 12
            fprintf('[Note] %d ports requested. DMRS Port Reuse will be applied (5G NR supports max 12 orthogonal ports).\n', totalPorts);
        end
    end

    carrier = nrCarrierConfig;
    carrier.SubcarrierSpacing = config.SubcarrierSpacing;
    carrier.NSizeGrid         = config.NSizeGrid;

    SNR_dB = config.SNR_dB;
    fprintf('Running MU-MIMO: SNR=%d dB, DMRSType=%d, DMRSLength=%d, TotalPorts=%d...\n', ...
        SNR_dB, pdsch.DMRS.DMRSConfigurationType, pdsch.DMRS.DMRSLength, totalPorts);

    BER_list = muMimo(carrier, pdsch, W_list, MCS, SNR_dB);

    fprintf('\n================ RESULTS ================\n');
    for u = 1:groupSize
        fprintf('BER UE %d (ID: %d): %.6f\n', u, ue_idx(u), BER_list(u));
    end
    disp('=========================================');
end

function BER_list = muMimo(carrier, basePDSCHConfig, UE_W_list, MCS, SNR_dB)

    numUE    = length(UE_W_list);
    nLayers  = size(UE_W_list{1}, 2);
    dmrsType = basePDSCHConfig.DMRS.DMRSConfigurationType;

    % Maximum ports per CDM group based on DMRS Type
    if dmrsType == 1
        portsPerSymbol = 4;   % Ports 0-3 (length=1), 0-7 (length=2)
    else
        portsPerSymbol = 6;   % Ports 0-5 (length=1), 0-11 (length=2)
    end
    
    maxPortIndex = portsPerSymbol * basePDSCHConfig.DMRS.DMRSLength - 1;

    pdsch_list     = cell(numUE, 1);
    inputBits_list = cell(numUE, 1);
    TBS_list       = zeros(numUE, 1);

    for u = 1:numUE
        pd = basePDSCHConfig;
        
        % Assign logical ports sequentially per UE
        logicalPortStart = (u-1) * nLayers;
        logicalPorts     = logicalPortStart : logicalPortStart + nLayers - 1;

        % --- APPLY DMRS PORT REUSE ---
        physicalPorts = mod(logicalPorts, maxPortIndex + 1);
        pd.DMRS.DMRSPortSet = physicalPorts;
        
        % Alternate NSCID to reduce inter-user interference under port reuse
        reuseFactor = floor(logicalPortStart / (maxPortIndex + 1));
        pd.DMRS.NSCID = mod(reuseFactor, 2);
        
        % Configure CDM groups to prevent PDSCH from overlapping DMRS
        if dmrsType == 1
            pd.DMRS.NumCDMGroupsWithoutData = 2; 
        else
            pd.DMRS.NumCDMGroupsWithoutData = 3; 
        end
        % -----------------------------

        pd = pd.setMCS(MCS);
        [~, pInfo] = nrPDSCHIndices(carrier, pd);
        TBS = nrTBS(pd.Modulation, pd.NumLayers, length(pd.PRBSet), pInfo.NREPerPRB, pd.TargetCodeRate);

        pdsch_list{u}     = pd;
        TBS_list(u)       = TBS;
        inputBits_list{u} = randi([0 1], TBS, 1);
    end

    % MMSE Precoding (getMMSEPrecoder takes 2 arguments as updated)
    H_composite = cell2mat(cellfun(@(w) w', UE_W_list(:), 'UniformOutput', false));
    W_total_T   = getMMSEPrecoder(H_composite, SNR_dB);

    W_list = cell(numUE, 1);
    for u = 1:numUE
        rowStart  = (u-1)*nLayers + 1;
        W_list{u} = W_total_T(rowStart : u*nLayers, :);
    end

    % Resource mapping and OFDM modulation
    numTxPorts = size(W_list{1}, 2); % Number of transmit antenna ports
    txGrid   = nrResourceGrid(carrier, numTxPorts);

    for u = 1:numUE
        [sym, ind]           = PDSCHEncode(pdsch_list{u}, carrier, inputBits_list{u});
        [antSym, antInd]     = nrPDSCHPrecode(carrier, sym, ind, W_list{u});
        dSym                 = nrPDSCHDMRS(carrier, pdsch_list{u});
        dInd                 = nrPDSCHDMRSIndices(carrier, pdsch_list{u});
        [dAntSym, dAntInd]   = nrPDSCHPrecode(carrier, dSym, dInd, W_list{u});

        txGrid(antInd)  = txGrid(antInd)  + antSym;
        txGrid(dAntInd) = txGrid(dAntInd) + dAntSym;
    end

    txWaveform = nrOFDMModulate(carrier, txGrid);

    % =====================================================================
    % CHANNEL MODEL + PHYSICAL AWGN NOISE
    % =====================================================================
    BER_list = zeros(numUE, 1);
    
    % Measure average transmit signal power across all antennas
    txPower = mean(var(txWaveform)); 
    
    % Compute noise variance N0 from SNR
    SNR_linear = 10^(SNR_dB / 10);
    noiseVar = txPower / SNR_linear;
    numSamples = size(txWaveform, 1);

    for u = 1:numUE
        % Received signal at UE u = transmitted signal passed through effective channel
        rx_signal = txWaveform * H_composite(u,:).';
        
        % Add independent AWGN noise
        noise = sqrt(noiseVar/2) * (randn(numSamples, 1) + 1i*randn(numSamples, 1));
        rxWaveform_noisy = rx_signal + noise;
        
        % Decode and compute BER
        rxBits      = rxPDSCHDecode(carrier, pdsch_list{u}, rxWaveform_noisy, txWaveform, TBS_list(u));
        BER_list(u) = biterr(double(inputBits_list{u}), double(rxBits)) / TBS_list(u);
    end
end

function val = getField(s, fname, default)
    if isfield(s, fname)
        val = s.(fname);
    else
        val = default;
    end
end
