function [bestGroups, bestScore] = psoMUMIMOScheduling(W_all, groupSize, maxIter)
% This function use to Scheduling UE in the Cell using the PSO (Particle Swarm Optimization)
%

    NUE      = size(W_all, 3);
    numGroups = floor(NUE / groupSize);

    popSize = min(60, max(20, 3 * NUE));

    w_start = 0.9;   % Xác suất quán tính ban đầu
    w_end   = 0.4;   % Xác suất quán tính cuối
    c1      = 0.8;   % Hệ số học từ PBest
    c2      = 0.8;   % Hệ số học từ GBest

    max_swaps_component = ceil(NUE / 3);  % [FIX 5] giới hạn mỗi thành phần
    max_swaps_total     = ceil(NUE / 2);  % Giới hạn tổng

    max_no_improve = 15;

    disp('      [Discrete PSO] Precomputing pair indices...');
    groupPairIdx = precomputePairIndices(groupSize, numGroups);

    disp('      [Discrete PSO] Computing chordal distance matrix...');
    distMat = zeros(NUE, NUE);
    for i = 1:NUE-1
        for j = i+1:NUE
            distMat(i,j) = chordalDistance(W_all(:,:,i), W_all(:,:,j));
            distMat(j,i) = distMat(i,j);
        end
    end

    fitnessFunc = @(perm) computeFitnessPrecomputed(perm, distMat, groupPairIdx, groupSize, numGroups);

    X  = zeros(popSize, NUE);
    V  = cell(popSize, 1);
    for p = 1:popSize
        X(p,:) = randperm(NUE);
        V{p}   = zeros(0, 2);
    end

    PBest_X     = X;
    PBest_Score = zeros(popSize, 1);
    for p = 1:popSize
        PBest_Score(p) = fitnessFunc(X(p,:));
    end

    [bestScore, bestIdx] = max(PBest_Score);
    GBest_X = PBest_X(bestIdx, :);

    no_improve_counter = 0;

    disp('      [Discrete PSO] Starting swarm optimization...');
    for iter = 1:maxIter

        w = w_start - (w_start - w_end) * (iter / maxIter);

        for i = 1:popSize

            r1 = rand();
            r2 = rand();

            V_w = multiplySwapSequence(w, V{i});

            SS_pbest = getSwapSequence(PBest_X(i,:), X(i,:));
            V_pbest  = multiplySwapSequence(c1 * r1, SS_pbest);  % [FIX 1]

            SS_gbest = getSwapSequence(GBest_X, X(i,:));
            V_gbest  = multiplySwapSequence(c2 * r2, SS_gbest);  % [FIX 1]

            V_w     = truncateSwaps(V_w,     max_swaps_component);
            V_pbest = truncateSwaps(V_pbest, max_swaps_component);
            V_gbest = truncateSwaps(V_gbest, max_swaps_component);

            V_new = [V_w; V_pbest; V_gbest];

            if size(V_new, 1) > max_swaps_total
                shuffleIdx = randperm(size(V_new, 1));
                V_new = V_new(shuffleIdx, :);
                V{i} = V_new(1:max_swaps_total, :);
            else
                V{i} = V_new;
            end

            X(i,:) = applySwapSequence(X(i,:), V{i});

            % BƯỚC 4d: Đánh giá và cập nhật PBest
            currentScore = fitnessFunc(X(i,:));
            if currentScore > PBest_Score(i)
                PBest_Score(i) = currentScore;
                PBest_X(i,:)   = X(i,:);
            end
        end

        [curBestScore, curBestIdx] = max(PBest_Score);
        if curBestScore > bestScore
            bestScore = curBestScore;
            GBest_X   = PBest_X(curBestIdx, :);
            no_improve_counter = 0;
        else
            no_improve_counter = no_improve_counter + 1;
        end

        % Early stopping
        if no_improve_counter >= max_no_improve
            fprintf('      [Discrete PSO] Converged early at iter %d (Score: %.4f)\n', iter, bestScore);
            break;
        end
    end

    bestGroups = cell(numGroups, 1);
    for g = 1:numGroups
        idx = (g-1)*groupSize + 1 : g*groupSize;
        bestGroups{g} = GBest_X(idx);
    end
end


function SS = getSwapSequence(target, current)
    n    = length(current);
    SS   = zeros(n, 2);
    count = 0;
    temp  = current;
    for i = 1:n
        if temp(i) ~= target(i)
            count = count + 1;
            idx = find(temp == target(i), 1);
            SS(count,:) = [i, idx];
            % Thực hiện hoán đổi tại chỗ
            t       = temp(i);
            temp(i) = temp(idx);
            temp(idx) = t;
        end
    end
    SS = SS(1:count, :);
end

function X_new = applySwapSequence(X, SS)
    X_new = X;
    for k = 1:size(SS, 1)
        i = SS(k,1);  j = SS(k,2);
        t      = X_new(i);
        X_new(i) = X_new(j);
        X_new(j) = t;
    end
end

function SS_new = multiplySwapSequence(prob, SS)
    if isempty(SS) || prob <= 0
        SS_new = zeros(0, 2);
        return;
    end
    if prob >= 1
        SS_new = SS;
        return;
    end
    keepIdx = rand(size(SS,1), 1) <= prob;
    SS_new  = SS(keepIdx, :);
end

function SS_out = truncateSwaps(SS, maxN)
    if size(SS,1) > maxN
        SS_out = SS(1:maxN, :);
    else
        SS_out = SS;
    end
end

function groupPairIdx = precomputePairIndices(groupSize, numGroups)
    groupPairIdx = cell(numGroups, 1);
    for g = 1:numGroups
        localIdx = 1:groupSize;
        % Lấy tất cả cặp từ chỉ số cục bộ
        pairs = nchoosek(localIdx, 2);  % Chỉ gọi 1 lần lúc init!
        groupPairIdx{g} = pairs;
    end
end

function score = computeFitnessPrecomputed(perm, distMat, groupPairIdx, groupSize, numGroups)
    numPairsPerGroup = groupSize * (groupSize - 1) / 2;
    if numPairsPerGroup == 0
        score = 0;
        return;
    end

    totalDist = 0;
    for g = 1:numGroups
        % Lấy chỉ số UE thực tế trong nhóm g
        startIdx = (g-1)*groupSize + 1;
        ueIdx    = perm(startIdx : startIdx + groupSize - 1);

        % Map relative pairs → chỉ số UE thực
        pairs = groupPairIdx{g};         % [numPairs x 2], chỉ số 1..groupSize
        ueRow = ueIdx(pairs(:,1));       % UE hàng
        ueCol = ueIdx(pairs(:,2));       % UE cột

        % Dùng sub2ind lấy khoảng cách từ distMat
        linIdx    = sub2ind(size(distMat), ueRow, ueCol);
        groupDist = sum(distMat(linIdx));

        totalDist = totalDist + groupDist / numPairsPerGroup;
    end
    score = totalDist / numGroups;
end