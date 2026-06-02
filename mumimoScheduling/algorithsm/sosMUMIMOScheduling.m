function [bestGroups, bestScore] = sosMUMIMOScheduling(W_all, groupSize, maxIter)
    NUE = size(W_all, 3);
    popSize = 30;

    % ---- Mỗi organism là 1 tổ hợp K UE (không cần permutation toàn bộ NUE) ----
    population = zeros(popSize, groupSize);
    for p = 1:popSize
        population(p, :) = randperm(NUE, groupSize);   % chọn K UE ngẫu nhiên
    end

    % Precompute distance matrix
    disp('      [SOS] Computing distance matrix...');
    distMat = zeros(NUE, NUE);
    for i = 1:NUE-1
        for j = i+1:NUE
            distMat(i,j) = chordalDistance(W_all(:,:,i), W_all(:,:,j));
            distMat(j,i) = distMat(i,j);
        end
    end

    % Fitness: avg chordal distance của 1 nhóm K UE
    fitnessFunc = @(grp) computeGroupFitness(grp, distMat, groupSize);

    fitness = zeros(popSize, 1);
    for p = 1:popSize
        fitness(p) = fitnessFunc(population(p,:));
    end

    [bestScore, bestIdx] = max(fitness);
    bestGroup = population(bestIdx, :);

    % Early stopping
    no_improve_counter = 0;
    max_no_improve = 15;

    disp('      [SOS] Starting evolutionary generations...');
    for iter = 1:maxIter

        % ===== MUTUALISM PHASE =====
        for i = 1:popSize
            j = randi(popSize);
            while j == i, j = randi(popSize); end
            
            % Hoan doi 1 UE
            newOrgI = mutualismSwap(population(i,:), population(j,:));
            newOrgJ = mutualismSwap(population(j,:), population(i,:));

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

        % ===== COMMENSALISM PHASE =====
        for i = 1:popSize
            j = randi(popSize);
            while j == i, j = randi(popSize); end

            newOrg = commensalismSwap(population(i,:), NUE);
            fNew = fitnessFunc(newOrg);
            if fNew > fitness(i)
                population(i,:) = newOrg;
                fitness(i) = fNew;
            end
        end

        % ===== PARASITISM PHASE =====
        for i = 1:popSize
            parasite = parasitePerturb(population(i,:), NUE);
            host = randi(popSize);
            while host == i, host = randi(popSize); end

            fParasite = fitnessFunc(parasite);
            if fParasite > fitness(host)
                population(host,:) = parasite;
                fitness(host) = fParasite;
            end
        end

        % Update global best
        [curBest, curIdx] = max(fitness);
        if curBest > bestScore
            bestScore = curBest;
            bestGroup = population(curIdx,:);
            no_improve_counter = 0;
        else
            no_improve_counter = no_improve_counter + 1;
        end

        if no_improve_counter >= max_no_improve
            fprintf('      [SOS] Converged at iteration %d (Score: %.4f)\n', iter, bestScore);
            break;
        end
    end

    bestGroups = {bestGroup};   % cell{1} để giữ interface giống cũ
end

% =========================================================================
% FITNESS — chỉ tính 1 nhóm
% =========================================================================
function score = computeGroupFitness(grp, distMat, groupSize)
    numPairs = groupSize * (groupSize - 1) / 2;
    groupDist = 0;
    for a = 1:groupSize-1
        for b = a+1:groupSize
            groupDist = groupDist + distMat(grp(a), grp(b));
        end
    end
    score = groupDist / numPairs;
end

% =========================================================================
% MUTATION / CROSSOVER — thao tác trên tổ hợp K phần tử
% =========================================================================
function newOrg = mutualismSwap(orgA, orgB)
    % Lấy 1 UE ngẫu nhiên từ orgB, thay thế 1 UE trong orgA nếu chưa có
    newOrg = orgA;
    candidate = orgB(randi(length(orgB)));
    if ~ismember(candidate, newOrg)
        replacePos = randi(length(newOrg));
        newOrg(replacePos) = candidate;
    end
end

function newOrg = commensalismSwap(org, NUE)
    % Thay thế 1 UE ngẫu nhiên bằng 1 UE mới chưa có trong nhóm
    newOrg = org;
    allUE = 1:NUE;
    outside = allUE(~ismember(allUE, org));
    if isempty(outside), return; end
    newUE = outside(randi(length(outside)));
    replacePos = randi(length(newOrg));
    newOrg(replacePos) = newUE;
end

function parasite = parasitePerturb(org, NUE)
    % Thay thế ngẫu nhiên nhiều UE trong nhóm bằng UE mới
    parasite = org;
    K = length(org);
    numReplace = randi(max(1, floor(K/2)));   % thay 1 đến K/2 UE
    replacePos = randperm(K, numReplace);
    allUE = 1:NUE;
    outside = allUE(~ismember(allUE, org));
    if length(outside) < numReplace, return; end
    newUEs = outside(randperm(length(outside), numReplace));
    parasite(replacePos) = newUEs;
end