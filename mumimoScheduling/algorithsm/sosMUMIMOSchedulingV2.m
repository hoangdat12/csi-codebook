function [bestGroups, bestScore, validGroups, validScores] = sosMUMIMOSchedulingV2(W_all, groupSize, maxIter, threshold)
    NUE       = size(W_all, 3);
    popSize   = 30;
    numGroups = floor(NUE / groupSize);

    population = zeros(popSize, NUE);
    for p = 1:popSize
        population(p, :) = randperm(NUE);
    end

    disp('      [SOS] Computing distance matrix...');
    distMat = zeros(NUE, NUE);
    for i = 1:NUE-1
        for j = i+1:NUE
            distMat(i,j) = chordalDistance(W_all(:,:,i), W_all(:,:,j));
            distMat(j,i) = distMat(i,j);
        end
    end

    fitnessFunc = @(perm) computeScheduleFitnessOptimize(perm, distMat, groupSize, numGroups);

    fitness = zeros(popSize, 1);
    for p = 1:popSize
        fitness(p) = fitnessFunc(population(p,:));
    end

    [bestScore, bestIdx] = max(fitness);
    bestPerm             = population(bestIdx, :);

    no_improve_counter = 0;
    max_no_improve     = 15;

    disp('      [SOS] Starting evolutionary generations...');
    for iter = 1:maxIter

        % MUTUALISM
        for i = 1:popSize
            j = randi(popSize);
            while j == i, j = randi(popSize); end
            newOrgI = mutualismSwap(population(i,:), population(j,:));
            newOrgJ = mutualismSwap(population(j,:), population(i,:));
            fI = fitnessFunc(newOrgI);
            if fI > fitness(i), population(i,:) = newOrgI; fitness(i) = fI; end
            fJ = fitnessFunc(newOrgJ);
            if fJ > fitness(j), population(j,:) = newOrgJ; fitness(j) = fJ; end
        end

        % COMMENSALISM
        for i = 1:popSize
            j = randi(popSize);
            while j == i, j = randi(popSize); end
            newOrg = commensalismSwap(population(i,:), population(j,:));
            fNew   = fitnessFunc(newOrg);
            if fNew > fitness(i), population(i,:) = newOrg; fitness(i) = fNew; end
        end

        % PARASITISM
        for i = 1:popSize
            parasite = parasitePerturb(population(i,:));
            host     = randi(popSize);
            while host == i, host = randi(popSize); end
            fParasite = fitnessFunc(parasite);
            if fParasite > fitness(host)
                population(host,:) = parasite;
                fitness(host)      = fParasite;
            end
        end

        [curBest, curIdx] = max(fitness);
        if curBest > bestScore
            bestScore          = curBest;
            bestPerm           = population(curIdx,:);
            no_improve_counter = 0;
        else
            no_improve_counter = no_improve_counter + 1;
        end

        if no_improve_counter >= max_no_improve
            fprintf('      [SOS] Converged at iter %d (score: %.4f)\n', iter, bestScore);
            break;
        end
    end

    % ── Cắt hoán vị → 100 cặp, tính score từng cặp, lọc threshold ───────
    bestGroups  = cell(numGroups, 1);
    pairScores  = zeros(numGroups, 1);
    numPairs    = groupSize*(groupSize-1)/2;

    for g = 1:numGroups
        idx  = (g-1)*groupSize + 1 : g*groupSize;
        grp  = bestPerm(idx);
        bestGroups{g} = grp;

        d = 0;
        for a = 1:groupSize-1
            for b = a+1:groupSize
                d = d + distMat(grp(a), grp(b));
            end
        end
        pairScores(g) = d / numPairs;
    end

    % Lọc các cặp >= threshold
    validMask   = pairScores >= threshold;
    validGroups = bestGroups(validMask);
    validScores = pairScores(validMask);

    % Sắp xếp theo score giảm dần
    [validScores, si] = sort(validScores, 'descend');
    validGroups       = validGroups(si);

    fprintf('      [SOS] Total pairs: %d | Above threshold (%.3f): %d\n', ...
        numGroups, threshold, sum(validMask));
end


% =========================================================================
% FITNESS FUNCTION
% =========================================================================
function score = computeScheduleFitnessOptimize(perm, distMat, groupSize, numGroups)
    totalDist        = 0;
    numPairsPerGroup = groupSize*(groupSize-1)/2;
    for g = 1:numGroups
        idx      = (g-1)*groupSize + 1 : g*groupSize;
        ueIdx    = perm(idx);
        groupDist = 0;
        for a = 1:groupSize-1
            for b = a+1:groupSize
                groupDist = groupDist + distMat(ueIdx(a), ueIdx(b));
            end
        end
        totalDist = totalDist + groupDist / numPairsPerGroup;
    end
    score = totalDist / numGroups;
end


% =========================================================================
% MUTATION / CROSSOVER OPERATORS
% =========================================================================
function newPerm = mutualismSwap(permA, permB)
    n   = length(permA);
    pt1 = randi(n); pt2 = randi(n);
    while pt1 == pt2, pt2 = randi(n); end
    if pt1 > pt2, [pt1,pt2] = deal(pt2,pt1); end

    segment     = permB(pt1:pt2);
    isInSegment = false(1,n);
    isInSegment(segment) = true;
    remaining   = permA(~isInSegment(permA));
    insertPos   = randi(length(remaining)+1);
    newPerm     = [remaining(1:insertPos-1), segment, remaining(insertPos:end)];
    assert(length(newPerm)==n, 'Error: newPerm length mismatch!');
end

function newPerm = commensalismSwap(permA, ~)
    newPerm      = permA;
    pts          = randperm(length(permA), 2);
    temp         = newPerm(pts(1));
    newPerm(pts(1)) = newPerm(pts(2));
    newPerm(pts(2)) = temp;
end

function parasite = parasitePerturb(perm)
    parasite  = perm;
    n         = length(perm);
    pts       = sort(randperm(n,2));
    parasite(pts(1):pts(2)) = parasite(pts(1) + randperm(pts(2)-pts(1)+1) - 1);
end