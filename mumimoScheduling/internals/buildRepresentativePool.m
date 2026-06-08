function [W_pool, pool_indices, pool_pmi] = buildRepresentativePool(W_all, UE_Reported_Indices, config)

    numClusters    = getField(config, 'numClusters',    50);
    targetPoolSize = getField(config, 'targetPoolSize', 200);
    kmeansMaxIter  = getField(config, 'kmeansMaxIter',  100);

    [Nt, ~, N] = size(W_all);
    numClusters = min(numClusters, N);

    % Feature: flatten projection matrix P = Q*Q'
    P_features = zeros(N, Nt^2);
    for k = 1:N
        Q = orth(W_all(:,:,k));
        P = real(Q * Q');
        P_features(k,:) = P(:).';
    end

    % K-Means trên P_features
    [labels, ~] = kmeans(P_features, numClusters, ...
        'Distance',   'sqeuclidean', ...
        'MaxIter',    kmeansMaxIter,  ...
        'Replicates', 3);

    % Lấy đại diện gần centroid nhất (thay vì random)
    ues_per_cluster = ceil(targetPoolSize / numClusters);
    pool_indices    = [];

    for c = 1:numClusters
        members = find(labels == c);
        if isempty(members), continue; end

        % Centroid của cụm c trong feature space
        centroid = mean(P_features(members, :), 1);

        % Khoảng cách Euclidean đến centroid
        diffs = P_features(members, :) - centroid;
        d2    = sum(diffs.^2, 2);
        [~, ord] = sort(d2, 'ascend');

        num_to_pick  = min(ues_per_cluster, length(members));
        pool_indices = [pool_indices; members(ord(1:num_to_pick))];
    end

    W_pool   = W_all(:, :, pool_indices);
    pool_pmi = UE_Reported_Indices(pool_indices);
end

function v = getField(s, f, default)
    if isfield(s, f), v = s.(f); else, v = default; end
end