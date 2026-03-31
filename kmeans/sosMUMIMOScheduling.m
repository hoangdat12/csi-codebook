% =========================================================================
% HÀM SOS ĐÃ TÍCH HỢP TỰ ĐỘNG CHỌN LỌC (USER SELECTION)
% =========================================================================
function [muMimoGroups, suMimoUEs, bestScore] = sosMUMIMOScheduling(W_all, groupSize, maxIter, threshold)
    % Cấp số UE và thiết lập thuật toán
    NUE = size(W_all, 3);
    popSize = 50; % Tăng lên 50 cho mạnh
    numGroups = floor(NUE / groupSize);
    
    % Khởi tạo quần thể
    population = zeros(popSize, NUE);
    for p = 1:popSize
        population(p, :) = randperm(NUE);
    end
    
    disp('      [SOS] Computing distance matrix using PMIPair...');
    distMat = zeros(NUE, NUE);
    for i = 1:NUE-1
        for j = i+1:NUE
            corr_mag = abs(PMIPair(W_all(:,:,i), W_all(:,:,j)));
            distMat(i, j) = 1 - corr_mag; % Điểm tối đa = 1 (Tương quan = 0)
            distMat(j, i) = distMat(i, j); 
        end
    end
    
    % Truyền thêm threshold vào hàm Fitness để phạt các cặp vi phạm
    fitnessFunc = @(perm) computeScheduleFitnessOptimize(perm, distMat, groupSize, numGroups, threshold);
    
    fitness = zeros(popSize, 1);
    for p = 1:popSize
        fitness(p) = fitnessFunc(population(p, :));
    end
    
    [bestScore, bestIdx] = max(fitness);
    bestPerm = population(bestIdx, :);
    
    no_improve_counter = 0;
    max_no_improve = 40; % Kiên nhẫn hơn
    
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
        
        % Check for convergence
        [curBest, curIdx] = max(fitness);
        if curBest > bestScore
            bestScore = curBest;
            bestPerm = population(curIdx, :);
            no_improve_counter = 0; 
        else
            no_improve_counter = no_improve_counter + 1;
        end
        
        if no_improve_counter >= max_no_improve
            fprintf('      [SOS] Tối ưu xong sớm tại vòng lặp %d\n', iter);
            break;
        end
    end
    
    % =========================================================================
    % TỰ ĐỘNG PHÂN LOẠI TRƯỚC KHI TRẢ KẾT QUẢ
    % =========================================================================
    muMimoGroups = {};
    suMimoUEs = [];
    
    for g = 1:numGroups
        idx = (g-1)*groupSize + 1 : g*groupSize;
        pair = bestPerm(idx);
        
        % Tính lại độ tương quan thực tế của cặp này
        corr_val = 1 - distMat(pair(1), pair(2)); 
        
        if corr_val <= threshold
            % Cặp ngon -> Nhét vào list MU-MIMO
            muMimoGroups{end+1} = pair;
        else
            % Cặp dở -> Xé lẻ ra nhét vào list SU-MIMO
            suMimoUEs = [suMimoUEs, pair];
        end
    end
end

% =========================================================================
% HÀM FITNESS MỚI (CÓ HÌNH PHẠT)
% =========================================================================
function score = computeScheduleFitnessOptimize(perm, distMat, groupSize, numGroups, threshold)
    totalDist = 0;
    
    for g = 1:numGroups
        idx = (g-1)*groupSize + 1 : g*groupSize;
        ueIdx = perm(idx);
        
        % Chỉ hỗ trợ groupSize = 2 cho tính năng tính phạt này
        u1 = ueIdx(1);
        u2 = ueIdx(2);
        
        % distMat lưu giá trị (1 - corr). Vậy corr = 1 - distMat.
        corr_val = 1 - distMat(u1, u2);
        
        if corr_val > threshold
            % HÌNH PHẠT: Nếu nhiễu vượt ngưỡng, cho nhóm này 0 điểm!
            % Ép thuật toán phải vỡ nhóm này ra tìm nhóm khác
            groupDist = 0; 
        else
            % Nếu ngoan, điểm giữ nguyên (càng gần 1 càng tốt)
            groupDist = distMat(u1, u2); 
        end
        
        totalDist = totalDist + groupDist;
    end
    % Trả về điểm trung bình
    score = totalDist / numGroups;
end

% =========================================================================
% MUTATION / CROSSOVER OPERATORS
% =========================================================================
function newPerm = mutualismSwap(permA, permB)
    n = length(permA);
    pts = sort(randperm(n, 2));
    segment = permB(pts(1):pts(2)); % Extract a segment from organism B
    
    remaining = permA(~ismember(permA, segment));  % Filter out duplicate elements in A
    
    maxInsert = length(remaining) + 1; 
    insertPos = randi(maxInsert);
    
    % Insert B's segment into a random position within the remaining parts of A
    newPerm = [remaining(1:insertPos-1), segment, remaining(insertPos:end)];
    
    assert(length(newPerm) == n, 'Error: newPerm length mismatch after Swap!');
end

function newPerm = commensalismSwap(permA, ~)
    newPerm = permA;
    pts = randperm(length(permA), 2);
    
    % Swap the positions of any two elements (Point Mutation Operator)
    temp = newPerm(pts(1));
    newPerm(pts(1)) = newPerm(pts(2));
    newPerm(pts(2)) = temp;
end

function parasite = parasitePerturb(perm)
    parasite = perm;
    n = length(perm);
    pts = sort(randperm(n, 2));
    
    % Randomly scramble a sub-segment within the organism (Array Mutation Operator)
    parasite(pts(1):pts(2)) = parasite(pts(1) + randperm(pts(2)-pts(1)+1) - 1);
end