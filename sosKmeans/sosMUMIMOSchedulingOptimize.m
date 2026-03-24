function [bestGroups, bestScore] = sosMUMIMOSchedulingOptimize(W_all, groupSize, maxIter)
    NUE = size(W_all, 3);
    
    popSize = 30; 
    numGroups = floor(NUE / groupSize);
    
    population = zeros(popSize, NUE);
    for p = 1:popSize
        population(p, :) = randperm(NUE);
    end
    
    disp('      [SOS] Computing distance matrix...');
    distMat = zeros(NUE, NUE);
    for i = 1:NUE-1
        for j = i+1:NUE
            distMat(i, j) = chordalDistance(W_all(:,:,i), W_all(:,:,j));
            distMat(j, i) = distMat(i, j); 
        end
    end
    
    fitnessFunc = @(perm) computeScheduleFitnessOptimize(perm, distMat, groupSize, numGroups);
    
    fitness = zeros(popSize, 1);
    for p = 1:popSize
        fitness(p) = fitnessFunc(population(p, :));
    end
    
    [bestScore, bestIdx] = max(fitness);
    bestPerm = population(bestIdx, :);
    
    no_improve_counter = 0;
    max_no_improve = 15; 
    
    disp('      [SOS] Starting evolutionary generations...');
    for iter = 1:maxIter        
        % ===== MUTUALISM PHASE =====
        for i = 1:popSize
            j = randi(popSize);
            while j == i, j = randi(popSize); end
            
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
            
            newOrg = commensalismSwap(population(i,:), population(j,:));
            fNew = fitnessFunc(newOrg);
            if fNew > fitness(i)
                population(i,:) = newOrg;
                fitness(i) = fNew;
            end
        end
        
        % ===== PARASITISM PHASE =====
        for i = 1:popSize
            parasite = parasitePerturb(population(i,:));
            host = randi(popSize);
            while host == i, host = randi(popSize); end
            
            fParasite = fitnessFunc(parasite);
            if fParasite > fitness(host)
                population(host,:) = parasite;
                fitness(host) = fParasite;
            end
        end
        
        [curBest, curIdx] = max(fitness);
        if curBest > bestScore
            bestScore = curBest;
            bestPerm = population(curIdx, :);
            no_improve_counter = 0; 
        else
            no_improve_counter = no_improve_counter + 1;
        end
        
        if no_improve_counter >= max_no_improve
            fprintf('      [SOS] Algorithm converged early at iteration %d (Score: %.4f)\n', iter, bestScore);
            break;
        end
    end
    
    bestGroups = cell(numGroups, 1);
    for g = 1:numGroups
        idx = (g-1)*groupSize + 1 : g*groupSize;
        bestGroups{g} = bestPerm(idx);
    end
end

% =========================================================================
% FITNESS FUNCTION 
% =========================================================================
function score = computeScheduleFitnessOptimize(perm, distMat, groupSize, numGroups)
    totalDist = 0;
    numPairsPerGroup = groupSize * (groupSize - 1) / 2; 
    
    for g = 1:numGroups
        idx = (g-1)*groupSize + 1 : g*groupSize;
        ueIdx = perm(idx);
        
        % [OPTIMIZED] Vectorization: Trích xuất ma trận con và tính tổng trực tiếp
        subMat = distMat(ueIdx, ueIdx);
        groupDist = sum(subMat, 'all') / 2;
        
        totalDist = totalDist + groupDist / numPairsPerGroup;
    end
    score = totalDist / numGroups;
end

% =========================================================================
% MUTATION / CROSSOVER OPERATORS
% =========================================================================
function newPerm = mutualismSwap(permA, permB)
    n = length(permA);
    pts = sort(randperm(n, 2));
    segment = permB(pts(1):pts(2)); 
    
    % [OPTIMIZED] Logical Indexing: Thay thế ismember để giảm độ phức tạp xuống O(N)
    mask = true(1, n);
    mask(segment) = false;
    remaining = permA(mask(permA)); 
    
    maxInsert = length(remaining) + 1; 
    insertPos = randi(maxInsert);
    
    newPerm = [remaining(1:insertPos-1), segment, remaining(insertPos:end)];
    
    assert(length(newPerm) == n, 'Error: newPerm length mismatch after Swap!');
end

function newPerm = commensalismSwap(permA, permB)
    newPerm = permA;
    
    % [OPTIMIZED] Alignment with SOS Theory: Cá thể A học hỏi trật tự từ cá thể B
    diffIdx = find(permA ~= permB);
    if length(diffIdx) >= 2
        % Trích xuất một gen từ B và ép buộc A phải đồng hóa vị trí đó
        idx1 = diffIdx(randi(length(diffIdx)));
        valFromB = permB(idx1);
        idx2 = find(newPerm == valFromB);
        
        % Giao hoán để bảo toàn tính toàn vẹn của hoán vị
        temp = newPerm(idx1);
        newPerm(idx1) = newPerm(idx2);
        newPerm(idx2) = temp;
    else
        pts = randperm(length(permA), 2);
        temp = newPerm(pts(1));
        newPerm(pts(1)) = newPerm(pts(2));
        newPerm(pts(2)) = temp;
    end
end

function parasite = parasitePerturb(perm)
    parasite = perm;
    n = length(perm);
    pts = sort(randperm(n, 2));
    
    parasite(pts(1):pts(2)) = parasite(pts(1) + randperm(pts(2)-pts(1)+1) - 1);
end