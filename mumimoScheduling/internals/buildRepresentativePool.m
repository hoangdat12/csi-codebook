function [W_pool, pool_indices, pool_pmi] = buildRepresentativePool(W_all, UE_Reported_Indices, config)
    % Parse config fields with defaults
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

    % Clamp numClusters to actual pool size to avoid K-means errors
    if numClusters > Num_UEs
        fprintf('Warning: numClusters (%d) exceeds number of matrices (%d). Clamping to %d.\n', ...
                numClusters, Num_UEs, Num_UEs);
        numClusters = Num_UEs;
    end

    % Flatten W_all to real-valued feature matrix for K-means:
    %   W_all [nAnt x nLayers x nUE] -> W_features [nUE x 2*nAnt*nLayers]
    W_flat     = reshape(W_all, Num_Antennas * NumLayers, Num_UEs).';
    W_features = [real(W_flat), imag(W_flat)];

    fprintf('Running K-means (%d clusters) on %d matrices...\n', numClusters, Num_UEs);

    % Cluster UEs by spatial signature using cosine distance
    [cluster_idx, ~] = kmeans(W_features, numClusters, ...
                              'Distance', 'cosine',    ...
                              'MaxIter',  kmeansMaxIter);

    % Draw a fixed quota of UEs from each cluster to form the representative pool
    ues_per_cluster = ceil(targetPoolSize / numClusters);
    pool_indices    = [];

    for c = 1:numClusters
        members      = find(cluster_idx == c);
        members      = members(randperm(length(members))); % random shuffle
        num_to_pick  = min(ues_per_cluster, length(members));
        pool_indices = [pool_indices; members(1:num_to_pick)];
    end

    W_pool   = W_all(:, :, pool_indices);
    pool_pmi = UE_Reported_Indices(pool_indices);

    fprintf('Representative pool built: %d matrices from %d clusters (target: %d).\n\n', ...
            length(pool_indices), numClusters, targetPoolSize);
end