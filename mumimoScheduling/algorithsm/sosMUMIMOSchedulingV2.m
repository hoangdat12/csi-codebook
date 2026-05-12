function [bestGroups, bestScore] = sosMUMIMOSchedulingV2(W_all, groupSize, maxIter)
    % Get number of UE in the Cell
    NUE = size(W_all, 3);
    
    % Size of each group
    popSize = 30; 

    % The total number of groups
    numGroups = floor(NUE / groupSize);
    
    % Initialize the population: Each organism is a random permutation of UE indices
    population = zeros(popSize, NUE);
    for p = 1:popSize
        population(p, :) = randperm(NUE);
    end
    
    % =========================================================================
    % KHÔNG TÍNH TOÁN TRƯỚC DISTMAT Ở ĐÂY NỮA
    % =========================================================================
    
    % Initialize the function handle for fitness evaluation
    % TRUYỀN TRỰC TIẾP W_all VÀO HÀM FITNESS
    fitnessFunc = @(perm) computeScheduleFitnessOnTheFly(perm, W_all, groupSize, numGroups);
    
    fitness = zeros(popSize, 1);
    for p = 1:popSize
        fitness(p) = fitnessFunc(population(p, :));
    end
    
    % Identify the initial best organism
    [bestScore, bestIdx] = max(fitness);
    bestPerm = population(bestIdx, :);
    
    no_improve_counter = 0;
    % Early stopping condition: No improvement after 15 iterations
    max_no_improve = 15; 
    
    disp('      [SOS No-Prebuild] Starting evolutionary generations...');
    for iter = 1:maxIter        
        % ===== MUTUALISM PHASE =====
        for i = 1:popSize
            j = randi(popSize);
            while j == i, j = randi(popSize); end
            
            % Crossover between organism i and j
            newOrgI = mutualismSwap(population(i,:), population(j,:));
            newOrgJ = mutualismSwap(population(j,:), population(i,:));
            
            % Update if the new organism has a higher score
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
            
            % Random mutation on organism i
            newOrg = commensalismSwap(population(i,:), population(j,:));
            fNew = fitnessFunc(newOrg);
            if fNew > fitness(i)
                population(i,:) = newOrg;
                fitness(i) = fNew;
            end
        end
        
        % ===== PARASITISM PHASE =====
        for i = 1:popSize
            % Perturb the internal order of a segment to create a strong mutation
            parasite = parasitePerturb(population(i,:));
            host = randi(popSize);
            while host == i, host = randi(popSize); end
            
            % Parasite replaces the host if it has a higher fitness score
            fParasite = fitnessFunc(parasite);
            if fParasite > fitness(host)
                population(host,:) = parasite;
                fitness(host) = fParasite;
            end
        end
        
        % Check for convergence and update the global best
        [curBest, curIdx] = max(fitness);
        if curBest > bestScore
            bestScore = curBest;
            bestPerm = population(curIdx, :);
            no_improve_counter = 0; 
        else
            no_improve_counter = no_improve_counter + 1;
        end
        
        if no_improve_counter >= max_no_improve
            fprintf('      [SOS No-Prebuild] Algorithm converged early at iteration %d (Score: %.4f)\n', iter, bestScore);
            break;
        end
    end
    
    % Extract the UE array into cell arrays based on group size
    bestGroups = cell(numGroups, 1);
    for g = 1:numGroups
        idx = (g-1)*groupSize + 1 : g*groupSize;
        bestGroups{g} = bestPerm(idx);
    end
end

% =========================================================================
% TÍNH TOÁN ON-THE-FLY FITNESS FUNCTION 
% =========================================================================
function score = computeScheduleFitnessOnTheFly(perm, W_all, groupSize, numGroups)
    totalDist = 0;
    numPairsPerGroup = groupSize * (groupSize - 1) / 2; % Combinations of 2 within the group size
    
    for g = 1:numGroups
        idx = (g-1)*groupSize + 1 : g*groupSize;
        ueIdx = perm(idx);
        groupDist = 0;
        
        % Iterate through all UE pairs in a group and accumulate the orthogonal distance
        for a = 1:groupSize-1
            for b = a+1:groupSize
                % THAY ĐỔI LỚN NHẤT: Gọi hàm chordalDistance trực tiếp tại đây
                % thay vì tra cứu O(1) từ ma trận distMat
                groupDist = groupDist + chordalDistance(W_all(:,:,ueIdx(a)), W_all(:,:,ueIdx(b)));
            end
        end
        
        totalDist = totalDist + groupDist / numPairsPerGroup;
    end
    % Return the average score across all scheduled groups
    score = totalDist / numGroups;
end

% =========================================================================
% MUTATION / CROSSOVER OPERATORS (Giữ nguyên)
% =========================================================================
function newPerm = mutualismSwap(permA, permB)
    n = length(permA);
    pt1 = randi(n); pt2 = randi(n);
    while pt1 == pt2, pt2 = randi(n); end
    if pt1 < pt2
        idx1 = pt1; idx2 = pt2;
    else
        idx1 = pt2; idx2 = pt1;
    end
    segment = permB(idx1:idx2); 
    isInSegment = false(1, n); 
    isInSegment(segment) = true; 
    remaining = permA(~isInSegment(permA));  
    maxInsert = length(remaining) + 1; 
    insertPos = randi(maxInsert);
    newPerm = [remaining(1:insertPos-1), segment, remaining(insertPos:end)];
end

function newPerm = commensalismSwap(permA, ~)
    newPerm = permA;
    pts = randperm(length(permA), 2);
    temp = newPerm(pts(1));
    newPerm(pts(1)) = newPerm(pts(2));
    newPerm(pts(2)) = temp;
end

function parasite = parasitePerturb(perm)
    parasite = perm;
    n = length(perm);
    pts = sort(randperm(n, 2));
    parasite(pts(1):pts(2)) = parasite(pts(1) + randperm(pts(2)-pts(1)+1) - 1);
end