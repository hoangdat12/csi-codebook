% =========================================================================
% simulateRandomMUMIMOScheduling.m
%
% Script để lập lịch người dùng MU-MIMO 
% Tải codebook PMI Type I của 3GPP, xây dựng tập hợp UE đại diện thông qua
% K-Means Clustering, chạy tìm kiếm nhóm trực giao SOS, và đánh giá
% độ phức tạp thời gian cũng như độ chính xác của các thuật toán lập lịch
% qua các kích thước nhóm (numberOfUeToGroup = 2, 3, 4, 5) tại mức SNR cố định là 20 dB.
% =========================================================================

% =========================================================================
% KỊCH BẢN MÔ PHỎNG LẬP LỊCH NGƯỜI DÙNG MU-MIMO
% (MU-MIMO USER SCHEDULING SIMULATION SCRIPT)
% =========================================================================
%
% LUỒNG THỰC THI CHÍNH (EXECUTION FLOW):
%
% 1. Sinh dữ liệu không gian kênh truyền (generatePrecodingMatrix):
%    - Đọc cấu hình Codebook PMI Type I của 3GPP (VD: 4 Layers, 32 Ports) từ file text.
%    - Khởi tạo kênh truyền ngẫu nhiên (Rayleigh fading) cho một lượng lớn người dùng (VD: 1000 UE).
%    - Quét tìm Ma trận tạo búp sóng (Precoding Matrix) tối ưu cho từng UE dựa trên 
%      chuẩn Frobenius để tối đa hóa tín hiệu nhận. Kết quả thu được là tập không gian W_all.
%
% 2. Thu gọn và Giảm chiều dữ liệu (kmeansClustering):
%    - Áp dụng thuật toán học máy K-Means với khoảng cách Cosine lên tập W_all.
%    - Lựa chọn ra một tập các Precoding Matrix đại diện (Representative Pool - W_pool).
%    - Mục đích: Giảm triệt để không gian tìm kiếm cho thuật toán lập lịch mà vẫn bao 
%      phủ đầy đủ các hướng búp sóng (beam directions) chính trong hệ thống.
%
% 3. Lập lịch và Quét kích thước nhóm (MU-MIMO Grouping & Sweep):
%    - Duyệt qua các kích thước nhóm MU-MIMO khác nhau (K = 2, 3, 4, 5).
%    - Chạy song song 2 thuật toán để so sánh hiệu năng ghép nhóm (dựa trên việc 
%      tối đa hóa khoảng cách Chordal/độ trực giao giữa các UE trong cùng 1 nhóm):
%        + Thuật toán SOS (Symbiotic Organisms Search)
%        + Thuật toán Brute-Force (Duyệt cạn kết hợp Lookup Table)
%
% 4. Đánh giá và Trực quan hóa (plotResults):
%    - Figure 1: Biểu đồ so sánh Độ phức tạp thời gian (Execution Time) theo thang đo Log.
%    - Figure 2: Biểu đồ đánh giá Độ chính xác (Accuracy %) của thuật toán SOS so với 
%      nghiệm tối ưu tuyệt đối của Brute-Force trên từng kích thước nhóm.
%
% =========================================================================
clear; clc; close all;
setupPath();

% ----------------------------------------------------------------------------
% Các tham số cấu hình
% ----------------------------------------------------------------------------
nLayers      = 4;
numberOfUE   = 1000;
FIXED_SNR_dB = 20;

config.CodeBookConfig.N1   = 4;
config.CodeBookConfig.N2   = 4;
config.CodeBookConfig.cbMode = 1;
config.FileName = "Layer4_Port32_N1_4_N2-4_c1.txt";

% ----------------------------------------------------------------------------
% Tải codebook PMI và tạo ra Precoding Matrix Wall
% W_all: [nPort x nLayers x numberOfUE]
% ----------------------------------------------------------------------------
[W_all, UE_Reported_Indices, totalPMI] = generatePrecodingMatrix(config, nLayers, numberOfUE);

% ----------------------------------------------------------------------------
% Cấu hình cố định cho script này
% ----------------------------------------------------------------------------
baseConfig = struct( ...
    'desc',                      'MU-MIMO Group Size Sweep', ...
    'NLAYERS',                   nLayers, ...
    'MCS',                       27, ...
    'SUBCARRIER_SPACING',        30, ...
    'NSIZE_GRID',                273, ...
    'CYCLIC_PREFIX',             "normal", ...
    'NSLOT',                     0, ...
    'NFRAME',                    0, ...
    'NCELL_ID',                  20, ...
    'DMRS_CONFIGURATION_TYPE',   1, ...
    'DMRS_TYPEA_POSITION',       2, ...
    'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
    'DMRS_LENGTH',               2, ...
    'DMRS_ADDITIONAL_POSITION',  1, ...
    'PDSCH_MAPPING_TYPE',        'A', ...
    'PDSCH_RNTI',                20000, ...
    'PDSCH_PRBSET',              0:272, ...
    'PDSCH_START_SYMBOL',        0, ...
    'FILE_NAME',                 '2UE_Combine_PDSCH_Waveform_4P2V');

% =========================================================================
% Dùng K-means để thu gọn tập W_all rút gọn không gian tìm kiếm
% =========================================================================
poolConfig.numClusters    = min(totalPMI, 100);
poolConfig.targetPoolSize = 200;
poolConfig.kmeansMaxIter  = 100;

disp('--- Running K-Means to build Representative Pool ---');
[W_pool, pool_indices, pool_pmi] = kmeansClustering(W_all, UE_Reported_Indices, poolConfig);

% =========================================================================
% K = 2, 3, 4, 5
% =========================================================================
groupSizes  = [2, 3, 4, 5];
maxIter     = 50;
numMethods  = 2;
methodNames = {'SOS', 'BF Lookup'};

% Pre-allocate result matrices [numMethods x numGroupSizes]
allTimes    = zeros(numMethods, length(groupSizes));
allScores   = zeros(numMethods, length(groupSizes));
allAccuracy = nan(numMethods, length(groupSizes));   % NaN by default
bfTimeout   = false(1, length(groupSizes));          % timeout flag per group size

fprintf('\n========================================================\n');
fprintf('  GROUP SIZE SWEEP  (Fixed SNR = %d dB)\n', FIXED_SNR_dB);
fprintf('========================================================\n');

for gIdx = 1:length(groupSizes)
    K = groupSizes(gIdx);
    fprintf('\n--- Group Size K = %d ---\n', K);

    % Timeout: 180s only for K=5
    if K == 5
        maxTimeLimit = 180;
    else
        maxTimeLimit = Inf;
    end

    % ---- SOS ----
    t = tic;
    [g1, s1] = sosMUMIMOScheduling(W_pool, K, maxIter);
    allTimes(1, gIdx)  = toc(t);
    allScores(1, gIdx) = s1;

    % ---- Brute-Force + Lookup Table ----
    t = tic;
    [g2, s2, timedOut] = bruteForceMUMIMOSchedulingWithLookup(W_pool, K, maxTimeLimit);
    allTimes(2, gIdx)  = toc(t);
    allScores(2, gIdx) = s2;
    bfTimeout(gIdx)    = timedOut;

    % Accuracy: only valid when BF completed fully
    if ~timedOut
        allAccuracy(:, gIdx) = (allScores(:, gIdx) / allScores(2, gIdx)) * 100;
        fprintf('  %-20s | Time: %.4f s | Score: %.4f | Acc: %.2f%%\n', ...
            methodNames{1}, allTimes(1,gIdx), allScores(1,gIdx), allAccuracy(1,gIdx));
        fprintf('  %-20s | Time: %.4f s | Score: %.4f | Acc: 100%% (reference)\n', ...
            methodNames{2}, allTimes(2,gIdx), allScores(2,gIdx));
    else
        fprintf('  %-20s | Time: %.4f s | Score: %.4f | Acc: N/A (BF timeout)\n', ...
            methodNames{1}, allTimes(1,gIdx), allScores(1,gIdx));
        fprintf('  %-20s | Time: %.4f s | Score: %.4f | TIMEOUT\n', ...
            methodNames{2}, allTimes(2,gIdx), allScores(2,gIdx));
    end
end

plotResults(groupSizes, allTimes, allAccuracy, bfTimeout, methodNames, FIXED_SNR_dB);


%% Helper Function
function [W_all, UE_Reported_Indices, totalPMI, PMI_list, H_list] = generatePrecodingMatrix(config, nLayers, numberOfUE)
% =========================================================================
% MỤC ĐÍCH:
%   1. Đọc tập hợp các ma trận tạo búp sóng (precoding matrix pool) từ file text
%      được định nghĩa trước dựa trên cấu hình Codebook.
%   2. Mô phỏng kênh truyền vô tuyến (Rayleigh fading) cho một số lượng người
%      dùng (UE) nhất định.
%   3. Tìm ma trận precoding (PMI) tối ưu cho từng UE dựa trên tiêu chí tối đa 
%      hóa năng lượng tín hiệu nhận (chuẩn Frobenius).
%
% ĐẦU VÀO:
%   config     : Struct chứa cấu hình hệ thống (N1, N2, cbMode, FileName,...)
%   nLayers    : Số lượng lớp không gian (spatial layers) ví dụ: 4
%   numberOfUE : Số lượng người dùng (UE) cần mô phỏng
%
% ĐẦU RA:
%   W_all               : Ma trận 3D chứa các precoding matrix tốt nhất cho tất cả UE 
%                         Kích thước: [nPort x nLayers x numberOfUE]
%   UE_Reported_Indices : Thông tin/chỉ số Codebook mà UE "báo cáo" về trạm phát
%   totalPMI            : Tổng số ma trận precoding đọc được từ file
%   PMI_list            : Danh sách chỉ số PMI tốt nhất của từng UE (0-indexed)
%   H_list              : Ma trận kênh truyền Rayleigh đã sinh cho từng UE
%                         Kích thước: [nLayers x nPort x numberOfUE]
% =========================================================================

    SNR_dB = 20; 
    
    % -------------------------------------------------------------------------
    % Trích xuất cấu hình Codebook và xác định tên file
    % -------------------------------------------------------------------------
    N1     = config.CodeBookConfig.N1;
    N2     = config.CodeBookConfig.N2;
    cbMode = config.CodeBookConfig.cbMode;
    % Tổng số port anten
    nPort  = 2 * N1 * N2; 
    
    % Tạo tên file dựa trên các thông số cấu hình hệ thống
    filename = sprintf(config.FileName, nPort, nLayers, cbMode, N1, N2);

    fprintf('Loading precoding matrix pool from file: %s...\n', filename);

    % Mở file để đọc dữ liệu
    fid = fopen(filename, 'r');
    if fid == -1
        error('Cannot open file: %s', filename);
    end

    W_pool      = []; % Biến lưu trữ toàn bộ các ma trận precoding từ file
    pool_info   = {}; % Biến lưu dòng thông tin (index/header) của từng ma trận
    pmi_in_file = 0;  % Biến đếm số lượng ma trận đã đọc

    % -------------------------------------------------------------------------
    % Đọc dữ liệu Codebook (Precoding matrices) từ file text
    % -------------------------------------------------------------------------
    while ~feof(fid)
        % Đọc dòng chứa thông tin của ma trận (ví dụ: các chỉ số PMI)
        info_line = fgetl(fid);
        if ~ischar(info_line), break; end
        if isempty(strtrim(info_line)), continue; end % Bỏ qua dòng trống

        pmi_in_file = pmi_in_file + 1;
        pool_info{pmi_in_file} = info_line;

        % Khởi tạo ma trận tạm để chứa dữ liệu của 1 PMI
        W_temp = zeros(nPort, nLayers);
        
        % Đọc từng hàng của ma trận
        for row = 1:nPort
            row_data = fgetl(fid);
            W_temp(row, :) = str2num(row_data); % Chuyển chuỗi thành mảng số
        end
        % Lưu ma trận tạm vào pool lớn ở chiều thứ 3
        W_pool(:, :, pmi_in_file) = W_temp;
    end
    fclose(fid);

    fprintf('Successfully loaded %d precoding matrices from file.\n', pmi_in_file);
    totalPMI = pmi_in_file; % Lưu lại tổng số PMI có sẵn trong Codebook

    % -------------------------------------------------------------------------
    % Sinh kênh truyền mô phỏng và tìm kiếm PMI tối ưu cho mỗi UE
    % -------------------------------------------------------------------------
    fprintf('Generating %d Rayleigh H [%d x %d], SNR = %d dB...\n', ...
        numberOfUE, nLayers, nPort, SNR_dB);

    H_list            = zeros(nLayers, nPort, numberOfUE);
    PMI_list          = zeros(numberOfUE, 1);       % Lưu index PMI (bắt đầu từ 0 cho hệ thống)
    best_idx_list     = zeros(numberOfUE, 1);       % Lưu index PMI (bắt đầu từ 1 để dùng trong MATLAB)

    for k = 1:numberOfUE
        % Sinh ma trận kênh truyền H_k theo phân bố Rayleigh fading (biến phức chuẩn hóa)
        H_k = (randn(nLayers, nPort) + 1j*randn(nLayers, nPort)) / sqrt(2);
        H_list(:, :, k) = H_k;

        % Thuật toán brute-force để tìm PMI tốt nhất trong W_pool
        best_val = -inf;
        best_idx = 1;
        for i = 1:totalPMI
            % Tính bình phương chuẩn Frobenius của tích H_k và W_i
            val = norm(H_k * W_pool(:, :, i), 'fro')^2;
            
            % Cập nhật nếu tìm thấy giá trị lớn hơn
            if val > best_val
                best_val = val;
                best_idx = i;
            end
        end

        % Lưu lại chỉ số PMI tối ưu vừa tìm được cho UE thứ k
        PMI_list(k)      = best_idx - 1;   % 0-indexed (thường dùng trong bản tin báo cáo của 3GPP)
        best_idx_list(k) = best_idx;       % 1-indexed (để trích xuất mảng trong MATLAB)
    end

    fprintf('PMI search done. Extracting W and info...\n');

    % -------------------------------------------------------------------------
    % Trích xuất hàng loạt (Vectorized extraction) kết quả đầu ra
    % -------------------------------------------------------------------------
    % Trích xuất trực tiếp các ma trận W tốt nhất từ W_pool dựa vào danh sách best_idx
    W_all               = W_pool(:, :, best_idx_list);
    
    % Trích xuất thông tin text tương ứng của các PMI đó
    UE_Reported_Indices = pool_info(best_idx_list);

    fprintf('Done. W_all: [%d x %d x %d]\n\n', size(W_all,1), size(W_all,2), size(W_all,3));
end

%% K-means Clustering
function [W_pool, pool_indices, pool_pmi] = kmeansClustering(W_all, UE_Reported_Indices, config)
% =========================================================================
% MỤC ĐÍCH:
%   Phân cụm tập hợp các ma trận precoder W của tất cả UE bằng thuật toán
%   K-means, sau đó chọn ra một tập con đại diện (representative pool) để
%   giảm không gian tìm kiếm PMI mà vẫn bao phủ tốt các đặc trưng kênh.
%
% ĐẦU VÀO:
%   W_all              - Ma trận precoder của tất cả UE
%                        Kích thước: [nAntennas x nLayers x nUEs]
%   UE_Reported_Indices - PMI index mà mỗi UE báo cáo
%                        Kích thước: [1 x nUEs] hoặc [nUEs x 1]
%   config             - Struct chứa các tham số cấu hình:
%       .numClusters    : Số cụm K-means (mặc định: 50)
%       .targetPoolSize : Kích thước pool đại diện mong muốn (mặc định: 200)
%       .kmeansMaxIter  : Số vòng lặp tối đa của K-means (mặc định: 100)
%
% ĐẦU RA:
%   W_pool       - Pool các precoder đại diện sau clustering
%                  Kích thước: [nAntennas x nLayers x poolSize]
%   pool_indices - Chỉ số UE được chọn vào pool (index trong W_all)
%   pool_pmi     - PMI index tương ứng của các UE trong pool
% =========================================================================

    % --- Đọc tham số cấu hình, dùng giá trị mặc định nếu không có ---
    if isfield(config, 'numClusters'),    numClusters    = config.numClusters;
    else,                                 numClusters    = 50;
    end
    if isfield(config, 'targetPoolSize'), targetPoolSize = config.targetPoolSize;
    else,                                 targetPoolSize = 200;
    end
    if isfield(config, 'kmeansMaxIter'),  kmeansMaxIter  = config.kmeansMaxIter;
    else,                                 kmeansMaxIter  = 100;
    end

    [Num_Antennas, NumLayers, Num_UEs] = size(W_all);

    if numClusters > Num_UEs
        fprintf('Warning: numClusters (%d) exceeds number of matrices (%d). Clamping to %d.\n', ...
                numClusters, Num_UEs, Num_UEs);
        numClusters = Num_UEs;
    end

    % --- Chuyển W phức sang vector thực để đưa vào K-means ---
    % K-means chỉ làm việc với số thực, nên cần tách real và imag:
    %
    %   W_all     : [nAnt x nLayers x nUE]  (phức)
    %      ↓ reshape
    %   W_flat    : [nUE x nAnt*nLayers]    (phức)
    %      ↓ tách real/imag
    %   W_features: [nUE x 2*nAnt*nLayers]  (thực) ← input cho K-means
    %
    W_flat     = reshape(W_all, Num_Antennas * NumLayers, Num_UEs).';
    W_features = [real(W_flat), imag(W_flat)];

    fprintf('Running K-means (%d clusters) on %d matrices...\n', numClusters, Num_UEs);

    % --- Chạy K-means với khoảng cách cosine ---
    % Dùng 'cosine' distance thay vì 'euclidean' vì precoder W có thể
    % khác nhau về pha tuyệt đối nhưng hướng beam vẫn như nhau.
    % Cosine distance đo góc giữa các vector → phù hợp hơn cho beamforming.
    [cluster_idx, ~] = kmeans(W_features, numClusters, ...
                              'Distance', 'cosine',    ...
                              'MaxIter',  kmeansMaxIter);
    % cluster_idx(i) = nhãn cụm của UE thứ i, thuộc [1..numClusters]

    % --- Chọn đại diện từ mỗi cụm để tạo pool ---
    ues_per_cluster = ceil(targetPoolSize / numClusters);
    
    pool_indices = [];  % khởi tạo danh sách index UE được chọn

    for c = 1:numClusters
        members     = find(cluster_idx == c);       % danh sách UE thuộc cụm c
        members     = members(randperm(length(members))); % xáo trộn ngẫu nhiên
        num_to_pick = min(ues_per_cluster, length(members)); % không vượt quá số UE trong cụm
        pool_indices = [pool_indices; members(1:num_to_pick)]; % thêm vào pool
    end

    % --- Lấy W và PMI tương ứng của các UE trong pool ---
    W_pool   = W_all(:, :, pool_indices);        % precoder của pool [nAnt x nLayers x poolSize]
    pool_pmi = UE_Reported_Indices(pool_indices); % PMI index của pool

    fprintf('Representative pool built: %d matrices from %d clusters (target: %d).\n\n', ...
            length(pool_indices), numClusters, targetPoolSize);
end

%% Brute-Force
function [bestGroups, bestScore, timedOut] = bruteForceMUMIMOSchedulingWithLookup(W_all, groupSize, maxTimeLimit)
% =========================================================================
% MỤC ĐÍCH:
%   Thực hiện ghép nhóm người dùng MU-MIMO bằng phương pháp Brute-Force. 
%
% ĐẦU VÀO:
%   W_all        - Ma trận precoder của tất cả UE trong pool
%                  Kích thước: [nPorts x nLayers x nUEs]
%   groupSize    - Số lượng UE cần chọn để ghép thành 1 nhóm MU-MIMO
%   maxTimeLimit - (Tùy chọn) Thời gian chạy tối đa tính bằng giây.
%                  Giúp tránh treo máy khi không gian tìm kiếm (tổ hợp chập)
%                  quá lớn. Mặc định: Inf (không giới hạn thời gian).
%
% ĐẦU RA:
%   bestGroups   - Mảng cell chứa danh sách index của các UE trong nhóm tốt nhất
%   bestScore    - Điểm số của nhóm tốt nhất (khoảng cách trung bình giữa các UE)
%   timedOut     - Cờ logic (true/false) báo hiệu thuật toán có bị ngắt giữa
%                  chừng do vượt quá maxTimeLimit hay không.
% =========================================================================

    if nargin < 3
        maxTimeLimit = Inf;
    end

    timedOut = false;
    NUE      = size(W_all, 3);

    % Xây dựng ma trận khoảng cách (Lookup Table) ---
    fprintf('      [BF Lookup] Computing %dx%d distance matrix...\n', NUE, NUE);
    distMat = zeros(NUE, NUE);
    for i = 1:NUE-1
        for j = i+1:NUE
            d = chordalDistance(W_all(:,:,i), W_all(:,:,j));
            distMat(i,j) = d;
            distMat(j,i) = d; % Ma trận đối xứng: khoảng cách i->j bằng j->i
        end
    end

    if isinf(maxTimeLimit)
        fprintf('      [BF Lookup] Evaluating all C(%d,%d) combinations...\n', NUE, groupSize);
    else
        fprintf('      [BF Lookup] Evaluating combinations (Timeout: %d s)...\n', maxTimeLimit);
    end

    bestScore        = -1;
    bestGroup        = [];
    % Số lượng cặp UE có thể tạo ra trong 1 nhóm để tính khoảng cách trung bình
    numPairsPerGroup = groupSize * (groupSize - 1) / 2;

    % Khởi tạo tổ hợp đầu tiên (ví dụ: [1, 2, 3, 4] nếu groupSize = 4)
    group    = 1:groupSize;
    % Giới hạn giá trị lớn nhất (index lớn nhất) cho từng vị trí trong mảng tổ hợp
    idxLimit = (NUE - groupSize + 1):NUE;

    tBF       = tic;
    iterCount = 0;

    while true
        iterCount = iterCount + 1;

        % Timeout
        if mod(iterCount, 500000) == 0 && toc(tBF) > maxTimeLimit
            fprintf('      [BF Lookup] TIMEOUT after %.1f s (%.0f combinations checked).\n', ...
                toc(tBF), iterCount);
            timedOut = true;
            break;
        end

        % --- Đánh giá nhóm hiện tại ---
        groupDist = 0;
        for a = 1:groupSize-1
            for b = a+1:groupSize
                groupDist = groupDist + distMat(group(a), group(b));
            end
        end
        avgDist = groupDist / numPairsPerGroup; 

        if avgDist > bestScore
            bestScore = avgDist;
            bestGroup = group;
        end

        ptr = groupSize;
        
        % Lùi con trỏ về trước nếu phần tử tại đó đã đạt giá trị giới hạn tối đa
        while ptr > 0 && group(ptr) == idxLimit(ptr)
            ptr = ptr - 1;
        end

        % Nếu con trỏ lùi về 0 nghĩa là đã duyệt qua hết mọi tổ hợp có thể
        if ptr == 0
            break; 
        end

        % Tăng phần tử tại con trỏ lên 1
        group(ptr) = group(ptr) + 1;
        
        % Đặt lại các phần tử phía sau nó thành một chuỗi giá trị liên tiếp
        for j = ptr+1:groupSize
            group(j) = group(j-1) + 1;
        end
    end

    % --- Hoàn tất và xuất kết quả ---
    if ~timedOut
        fprintf('      [BF Lookup] Done. Best score: %.4f\n', bestScore);
    end

    bestGroups = {bestGroup};
end

%% SOS algorithsm
function [bestGroups, bestScore] = sosMUMIMOScheduling(W_all, groupSize, maxIter)
% =========================================================================
% MỤC ĐÍCH:
%   Sử dụng thuật toán tiến hóa SOS để tìm ra một nhóm người dùng (UE) 
%   có độ trực giao (khoảng cách Chordal) lớn nhất, giúp tối ưu hóa hiệu 
%   suất MU-MIMO mà không cần duyệt toàn bộ (brute-force).
%
% ĐẦU VÀO:
%   W_all     : Ma trận precoder của toàn bộ UE trong pool
%   groupSize : Kích thước nhóm MU-MIMO cần ghép (K)
%   maxIter   : Số thế hệ (vòng lặp) tiến hóa tối đa
%
% ĐẦU RA:
%   bestGroups: Mảng cell chứa danh sách index của nhóm UE tốt nhất tìm được
%   bestScore : Điểm số (khoảng cách trung bình) của nhóm tốt nhất đó
% =========================================================================

    NUE = size(W_all, 3); % Tổng số lượng UE trong pool
    popSize = 30;         % Kích thước quần thể (số lượng sinh vật/nhóm giải pháp)

    % -------------------------------------------------------------------------
    % BƯỚC 1: Khởi tạo quần thể ban đầu
    % Mỗi "sinh vật" (organism) là một mảng chứa K index UE ngẫu nhiên
    % -------------------------------------------------------------------------
    population = zeros(popSize, groupSize);
    for p = 1:popSize
        population(p, :) = randperm(NUE, groupSize);   % Chọn K UE ngẫu nhiên không trùng lặp
    end

    % -------------------------------------------------------------------------
    % BƯỚC 2: Tính toán trước Ma trận khoảng cách (Lookup Table)
    % Tính khoảng cách Chordal giữa mọi cặp UE để tăng tốc độ tính fitness
    % -------------------------------------------------------------------------
    disp('      [SOS] Computing distance matrix...');
    distMat = zeros(NUE, NUE);
    for i = 1:NUE-1
        for j = i+1:NUE
            distMat(i,j) = chordalDistance(W_all(:,:,i), W_all(:,:,j));
            distMat(j,i) = distMat(i,j); % Ma trận đối xứng
        end
    end

    % Hàm ẩn (anonymous function) để tính fitness của 1 nhóm
    fitnessFunc = @(grp) computeGroupFitness(grp, distMat, groupSize);

    % Tính điểm fitness cho quần thể ban đầu
    fitness = zeros(popSize, 1);
    for p = 1:popSize
        fitness(p) = fitnessFunc(population(p,:));
    end

    % Tìm cá thể xuất sắc nhất khởi đầu
    [bestScore, bestIdx] = max(fitness);
    bestGroup = population(bestIdx, :);

    no_improve_counter = 0;
    max_no_improve = 15; % Điều kiện dừng sớm: 15 vòng không cải thiện thì dừng

    disp('      [SOS] Starting evolutionary generations...');
    % -------------------------------------------------------------------------
    % BƯỚC 3: Bắt đầu vòng lặp tiến hóa (Evolutionary loop)
    % -------------------------------------------------------------------------
    for iter = 1:maxIter

        % ===== PHA 1: TƯƠNG HỖ (MUTUALISM) =====
        % Cả 2 sinh vật tương tác và mang lại lợi ích cho nhau.
        for i = 1:popSize
            j = randi(popSize);
            while j == i, j = randi(popSize); end % Chọn đối tác ngẫu nhiên khác i

            % Trao đổi chéo một phần tử giữa 2 sinh vật
            newOrgI = mutualismSwap(population(i,:), population(j,:));
            newOrgJ = mutualismSwap(population(j,:), population(i,:));

            % Chỉ giữ lại phiên bản mới nếu nó tốt hơn phiên bản cũ (thích nghi tốt hơn)
            fI = fitnessFunc(newOrgI);
            if fI > fitness(i)
                population(i,:) = newOrgI;
                fitness(i) = fI;
            end

            fJ = fitnessFunc(newOrgJ);
            if fJ > fitness(j)
                population(j,:) = newOrgJ;
                fitness(j) = fJ;
            end
        end

        % ===== PHA 2: HỘI SINH (COMMENSALISM) =====
        % Sinh vật i hưởng lợi từ tương tác, sinh vật j không bị ảnh hưởng.
        for i = 1:popSize
            j = randi(popSize);
            while j == i, j = randi(popSize); end

            % Sinh vật i biến đổi bằng cách hút một UE mới từ bên ngoài vào nhóm
            newOrg = commensalismSwap(population(i,:), NUE);
            fNew = fitnessFunc(newOrg);
            
            % Cập nhật nếu tốt hơn
            if fNew > fitness(i)
                population(i,:) = newOrg;
                fitness(i) = fNew;
            end
        end

        % ===== PHA 3: KÝ SINH (PARASITISM) =====
        % Sinh vật i tạo ra một "ký sinh trùng" để tấn công sinh vật host (j).
        for i = 1:popSize
            % Tạo ra bản sao đột biến (ký sinh trùng) từ sinh vật i
            parasite = parasitePerturb(population(i,:), NUE);
            
            % Chọn ngẫu nhiên một vật chủ (host)
            host = randi(popSize);
            while host == i, host = randi(popSize); end

            fParasite = fitnessFunc(parasite);
            
            % Nếu ký sinh trùng mạnh hơn vật chủ, nó sẽ tiêu diệt và thay thế vật chủ
            if fParasite > fitness(host)
                population(host,:) = parasite;
                fitness(host) = fParasite;
            end
        end

        % ---------------------------------------------------------------------
        % BƯỚC 4: Cập nhật cá thể tốt nhất toàn cục và kiểm tra hội tụ
        % ---------------------------------------------------------------------
        [curBest, curIdx] = max(fitness);
        if curBest > bestScore
            bestScore = curBest;
            bestGroup = population(curIdx,:);
            no_improve_counter = 0; % Reset bộ đếm nếu có sự cải thiện
        else
            no_improve_counter = no_improve_counter + 1;
        end

        % Dừng sớm nếu thuật toán đã bão hòa (không tìm được nhóm tốt hơn)
        if no_improve_counter >= max_no_improve
            fprintf('      [SOS] Converged at iteration %d (Score: %.4f)\n', iter, bestScore);
            break;
        end
    end

    bestGroups = {bestGroup};   % Đưa vào cell{1} để giữ interface giống chuẩn cũ
end

% =========================================================================
% HÀM PHỤ TRỢ TÍNH FITNESS (Chỉ tính cho 1 nhóm K người dùng)
% =========================================================================
function score = computeGroupFitness(grp, distMat, groupSize)
    numPairs = groupSize * (groupSize - 1) / 2; % Số lượng tổ hợp cặp 2 trong nhóm K
    groupDist = 0;
    
    % Cộng dồn khoảng cách của tất cả các cặp UE trong nhóm
    for a = 1:groupSize-1
        for b = a+1:groupSize
            groupDist = groupDist + distMat(grp(a), grp(b));
        end
    end
    
    % Fitness chính là khoảng cách trung bình
    score = groupDist / numPairs;
end

% =========================================================================
% CÁC HÀM PHỤ TRỢ CHO QUÁ TRÌNH TIẾN HÓA (MUTATION / CROSSOVER)
% Áp dụng các toán tử logic trên tập hợp (tổ hợp K phần tử)
% =========================================================================

function newOrg = mutualismSwap(orgA, orgB)
    % MÔ PHỎNG TƯƠNG HỖ:
    % Lấy 1 UE ngẫu nhiên từ tổ hợp của orgB, dùng nó để thay thế 1 UE 
    % ngẫu nhiên trong orgA (với điều kiện orgA chưa có UE đó).
    newOrg = orgA;
    candidate = orgB(randi(length(orgB)));
    if ~ismember(candidate, newOrg)
        replacePos = randi(length(newOrg));
        newOrg(replacePos) = candidate;
    end
end

function newOrg = commensalismSwap(org, NUE)
    % MÔ PHỎNG HỘI SINH:
    % Khám phá vùng không gian mới bằng cách lấy ngẫu nhiên 1 UE hoàn toàn mới 
    % (nằm ngoài nhóm hiện tại) để thay thế cho 1 UE trong nhóm.
    newOrg = org;
    allUE = 1:NUE;
    outside = allUE(~ismember(allUE, org)); % Lọc ra các UE không nằm trong nhóm
    if isempty(outside), return; end
    
    newUE = outside(randi(length(outside))); % Chọn 1 UE bên ngoài
    replacePos = randi(length(newOrg));      % Chọn vị trí bị thay thế
    newOrg(replacePos) = newUE;
end

function parasite = parasitePerturb(org, NUE)
    % MÔ PHỎNG KÝ SINH (Đột biến mạnh):
    % Xáo trộn tổ hợp bằng cách thay thế ngẫu nhiên MỘT LƯỢNG LỚN UE 
    % (từ 1 cho đến tối đa một nửa số lượng UE trong nhóm) bằng các UE mới.
    parasite = org;
    K = length(org);
    numReplace = randi(max(1, floor(K/2)));   % Số lượng UE sẽ bị thay thế (1 đến K/2)
    replacePos = randperm(K, numReplace);     % Chọn các vị trí sẽ bị thay thế
    
    allUE = 1:NUE;
    outside = allUE(~ismember(allUE, org));
    if length(outside) < numReplace, return; end
    
    % Lấy ngẫu nhiên 'numReplace' UE mới từ bên ngoài và điền vào vị trí thay thế
    newUEs = outside(randperm(length(outside), numReplace));
    parasite(replacePos) = newUEs;
end

function plotResults(groupSizes, allTimes, allAccuracy, bfTimeout, methodNames, FIXED_SNR_dB)
% =========================================================================
% MỤC ĐÍCH:
%   Vẽ 2 đồ thị đánh giá hiệu năng MU-MIMO scheduling:
%     - Figure 1: Thời gian thực thi vs kích thước nhóm (log scale)
%     - Figure 2: Độ chính xác so với Brute-Force vs kích thước nhóm
%
% ĐẦU VÀO:
%   groupSizes   - Vector kích thước nhóm, ví dụ [2 3 4 5]
%   allTimes     - Ma trận thời gian [numMethods x numGroupSizes] (giây)
%   allScores    - Ma trận điểm số   [numMethods x numGroupSizes]
%   allAccuracy  - Ma trận độ chính xác [numMethods x numGroupSizes] (%)
%                  NaN tại các điểm BF timeout
%   bfTimeout    - Vector logical [1 x numGroupSizes], true = BF bị timeout
%   methodNames  - Cell array tên các phương pháp, ví dụ {'SOS','BF Lookup'}
%   FIXED_SNR_dB - Giá trị SNR cố định dùng trong sweep (để hiển thị tiêu đề)
% =========================================================================

    numMethods = size(allTimes, 1);

    % Màu sắc và marker cho từng phương pháp
    colors  = [0.12 0.47 0.71;   % xanh dương – SOS
               0.60 0.60 0.60];  % xám        – BF Lookup
    markers = {'o-', 'd-'};

    % =====================================================================
    % FIGURE 1 — Thời gian thực thi vs kích thước nhóm (log scale)
    % =====================================================================
    figure('Name', sprintf('Figure 1: Time Complexity vs Group Size (SNR=%ddB)', FIXED_SNR_dB), ...
           'Color', 'w', 'Position', [100, 100, 700, 480]);

    for m = 1:numMethods
        semilogy(groupSizes, allTimes(m,:), markers{m}, ...
            'LineWidth', 2, 'MarkerSize', 8, ...
            'Color', colors(m,:), 'MarkerFaceColor', colors(m,:));
        hold on;
    end

    % Đánh dấu điểm BF timeout bằng vòng tròn đỏ
    for gIdx = 1:length(groupSizes)
        if bfTimeout(gIdx)
            semilogy(groupSizes(gIdx), allTimes(2, gIdx), 'ro', ...
                'MarkerSize', 12, 'LineWidth', 2);
            text(groupSizes(gIdx), allTimes(2, gIdx) * 1.5, ...
                 'Timeout', 'FontSize', 8, 'Color', 'r', ...
                 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
        end
    end

    % Chú thích thời gian tại mỗi điểm dữ liệu
    for m = 1:numMethods
        for gIdx = 1:length(groupSizes)
            text(groupSizes(gIdx), allTimes(m, gIdx) * 1.15, ...
                 sprintf('%.3fs', allTimes(m, gIdx)), ...
                 'FontSize', 7.5, 'HorizontalAlignment', 'center', 'Color', colors(m,:));
        end
    end

    grid on;
    set(gca, 'YMinorGrid', 'on', 'FontSize', 11, ...
        'XColor', 'k', 'YColor', 'k', 'Color', 'w', ...
        'GridColor', [0.5 0.5 0.5], 'MinorGridColor', [0.7 0.7 0.7]);
    xticks(groupSizes);
    xticklabels(arrayfun(@(k) sprintf('K=%d', k), groupSizes, 'UniformOutput', false));
    xlabel('Number of UEs per Group (K)', 'FontWeight', 'bold', 'FontSize', 12, 'Color', 'k');
    ylabel('Execution Time (s) — Log Scale',  'FontWeight', 'bold', 'FontSize', 12, 'Color', 'k');
    title('Time Complexity vs MU-MIMO Group Size', 'FontSize', 13, 'FontWeight', 'bold', 'Color', 'k');
    lg1 = legend(methodNames, 'Location', 'northwest', 'FontSize', 10);
    set(lg1, 'TextColor', 'k', 'Color', 'w', 'EdgeColor', [0.5 0.5 0.5]);

    % =====================================================================
    % FIGURE 2 — Độ chính xác so với Brute-Force vs kích thước nhóm
    % =====================================================================
    figure('Name', sprintf('Figure 2: Scheduling Accuracy vs Group Size (SNR=%ddB)', FIXED_SNR_dB), ...
           'Color', 'w', 'Position', [820, 100, 700, 480]);

    % Chỉ vẽ các điểm có accuracy hợp lệ (không phải NaN)
    validIdx = ~isnan(allAccuracy(1,:));
    if any(validIdx)
        plot(groupSizes(validIdx), allAccuracy(1, validIdx), markers{1}, ...
            'LineWidth', 2, 'MarkerSize', 8, ...
            'Color', colors(1,:), 'MarkerFaceColor', colors(1,:));
        hold on;
    end

    % Đường tham chiếu Brute-Force 100%
    yline(100, '--k', 'Brute-Force (100%)', ...
          'LabelHorizontalAlignment', 'left', 'FontSize', 10, 'LineWidth', 1.5);
    hold on;

    % Chú thích giá trị accuracy tại các điểm hợp lệ
    for gIdx = 1:length(groupSizes)
        if ~isnan(allAccuracy(1, gIdx))
            text(groupSizes(gIdx), allAccuracy(1, gIdx) + 0.2, ...
                 sprintf('%.1f%%', allAccuracy(1, gIdx)), ...
                 'FontSize', 8, 'HorizontalAlignment', 'center', 'Color', colors(1,:));
        end
    end

    % Đánh dấu điểm BF timeout bằng dấu X đỏ
    for gIdx = 1:length(groupSizes)
        if bfTimeout(gIdx)
            plot(groupSizes(gIdx), 98.5, 'rx', 'MarkerSize', 14, 'LineWidth', 2.5);
            text(groupSizes(gIdx), 98.0, sprintf('N/A\n(BF Timeout)'), ...
                 'FontSize', 8, 'HorizontalAlignment', 'center', ...
                 'Color', 'r', 'FontWeight', 'bold');
        end
    end

    grid on;
    set(gca, 'FontSize', 11, ...
        'XColor', 'k', 'YColor', 'k', 'GridColor', [0.5 0.5 0.5], 'Color', 'w');
    xticks(groupSizes);
    xticklabels(arrayfun(@(k) sprintf('K=%d', k), groupSizes, 'UniformOutput', false));
    ylim([97, 102]);
    xlabel('Number of UEs per Group (K)',   'FontWeight', 'bold', 'FontSize', 12, 'Color', 'k');
    ylabel('Accuracy vs Brute-Force (%)',   'FontWeight', 'bold', 'FontSize', 12, 'Color', 'k');
    title('Scheduling Accuracy vs MU-MIMO Group Size', 'FontSize', 13, 'FontWeight', 'bold', 'Color', 'k');
    lg2 = legend([methodNames(1), {'Brute-Force'}], 'Location', 'southwest', 'FontSize', 10);
    set(lg2, 'TextColor', 'k', 'Color', 'w', 'EdgeColor', [0.5 0.5 0.5]);

    fprintf('\n[DONE] Both figures generated.\n');
end