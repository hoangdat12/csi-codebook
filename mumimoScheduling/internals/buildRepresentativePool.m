function [W_pool, pool_indices, pool_pmi] = buildRepresentativePool(W_all, UE_Reported_Indices, config)
    % 1. Xử lý cấu hình an toàn (Thay thế getField để code độc lập hơn)
    if isfield(config, 'numClusters'), numClusters = config.numClusters; 
    else 
        numClusters = 50; 
    end
    if isfield(config, 'targetPoolSize'), targetPoolSize = config.targetPoolSize; 
    else 
        targetPoolSize = 200; 
    end
    if isfield(config, 'kmeansMaxIter'), kmeansMaxIter = config.kmeansMaxIter; 
    else 
        kmeansMaxIter = 100; 
    end

    % 2. Lấy kích thước thực tế của W_all
    [Num_Antennas, NumLayers, Num_UEs] = size(W_all);

    % 3. Đảm bảo số lượng cluster không được vượt quá số lượng ma trận thực tế
    % (Nếu file của bạn chỉ có 16 ma trận mà numClusters = 50 thì K-means sẽ báo lỗi)
    if numClusters > Num_UEs
        fprintf('Cảnh báo: numClusters (%d) lớn hơn số lượng ma trận (%d). Tự động gán lại numClusters = %d.\n', numClusters, Num_UEs, Num_UEs);
        numClusters = Num_UEs;
    end

    % 4. Chuẩn bị dữ liệu cho K-means
    % W_all [4 x 4 x Num_UEs] -> Trải phẳng thành W_flat [Num_UEs x 16]
    W_flat = reshape(W_all, Num_Antennas * NumLayers, Num_UEs).';
    
    % Tách phần thực và phần ảo để làm features (kích thước [Num_UEs x 32])
    W_features = [real(W_flat), imag(W_flat)];

    fprintf('Running K-means (%d clusters) on %d matrices...\n', numClusters, Num_UEs);
    
    % 5. Chạy K-means
    [cluster_idx, ~] = kmeans(W_features, numClusters, ...
                            'Distance', 'cosine',    ...
                            'MaxIter',  kmeansMaxIter);

    % 6. Rút trích tập đại diện (Pool)
    ues_per_cluster = ceil(targetPoolSize / numClusters);
    pool_indices = [];
    
    for c = 1:numClusters
        members     = find(cluster_idx == c);
        members     = members(randperm(length(members))); % Xáo trộn ngẫu nhiên thứ tự
        num_to_pick = min(ues_per_cluster, length(members));
        pool_indices = [pool_indices; members(1:num_to_pick)];
    end

    % 7. Gán kết quả đầu ra
    W_pool   = W_all(:, :, pool_indices);
    pool_pmi = UE_Reported_Indices(pool_indices);   % <-- cell array PMI theo pool

    fprintf('Representative pool: %d matrices from %d clusters (target: %d).\n\n', ...
            length(pool_indices), numClusters, targetPoolSize);
end