function [bestGroups, bestScore] = psoMUMIMOScheduling(W_all, groupSize, maxIter)
    NUE = size(W_all, 3);
    popSize = 30; 
    numGroups = floor(NUE / groupSize);
    
    % === THAM SỐ PSO RỜI RẠC (Xác suất giữ lại Swap Sequence) ===
    w_start = 0.9;  % Xác suất quán tính ban đầu
    w_end   = 0.4;  % Xác suất quán tính lúc sau
    c1      = 0.8;  % Xác suất học từ bản thân (PBest)
    c2      = 0.8;  % Xác suất học từ bầy đàn (GBest)
    
    % 1. Tính toán ma trận khoảng cách
    disp('      [Discrete PSO] Computing distance matrix...');
    distMat = zeros(NUE, NUE);
    for i = 1:NUE-1
        for j = i+1:NUE
            distMat(i, j) = chordalDistance(W_all(:,:,i), W_all(:,:,j));
            distMat(j, i) = distMat(i, j); 
        end
    end
    
    fitnessFunc = @(perm) computeScheduleFitnessOptimize(perm, distMat, groupSize, numGroups);
    
    % 2. KHỞI TẠO QUẦN THỂ (Không gian rời rạc thực sự)
    X = zeros(popSize, NUE);
    V = cell(popSize, 1); % Vận tốc giờ là mảng cell chứa các lệnh đổi chỗ
    for p = 1:popSize
        X(p, :) = randperm(NUE);
        V{p} = zeros(0, 2); % Ban đầu đứng im, không có lệnh đổi chỗ nào
    end
    
    PBest_X = X;
    PBest_Score = zeros(popSize, 1);
    for p = 1:popSize
        PBest_Score(p) = fitnessFunc(X(p, :));
    end
    
    [bestScore, bestIdx] = max(PBest_Score);
    GBest_X = PBest_X(bestIdx, :);
    
    no_improve_counter = 0;
    max_no_improve = 15; 
    
    disp('      [Discrete PSO] Starting swarm movements...');
    for iter = 1:maxIter        
        w = w_start - (w_start - w_end) * (iter / maxIter);
        
        for i = 1:popSize
            % BƯỚC 1: Tính các thành phần Swap Sequence (Vận tốc)
            % Vận tốc quán tính
            V_w = multiplySwapSequence(w, V{i});
            
            % Kinh nghiệm bản thân (PBest - X)
            SS_pbest = getSwapSequence(PBest_X(i,:), X(i,:));
            V_pbest = multiplySwapSequence(c1, SS_pbest);
            
            % Kinh nghiệm bầy đàn (GBest - X)
            SS_gbest = getSwapSequence(GBest_X, X(i,:));
            V_gbest = multiplySwapSequence(c2, SS_gbest);
            
            % BƯỚC 2: Cộng gộp vận tốc (V = V_w + V_pbest + V_gbest)
            V_new = [V_w; V_pbest; V_gbest];
            
            % [Tối ưu] Đơn giản hóa danh sách vận tốc để không bị dài vô hạn
            V{i} = simplifySwapSequence(NUE, V_new);
            
            % BƯỚC 3: Cập nhật vị trí (X = X + V)
            X(i,:) = applySwapSequence(X(i,:), V{i});
            
            % BƯỚC 4: Đánh giá và cập nhật
            currentScore = fitnessFunc(X(i,:));
            if currentScore > PBest_Score(i)
                PBest_Score(i) = currentScore;
                PBest_X(i,:) = X(i,:);
            end
        end
        
        % Cập nhật GBest
        [curBestScore, curBestIdx] = max(PBest_Score);
        if curBestScore > bestScore
            bestScore = curBestScore;
            GBest_X = PBest_X(curBestIdx, :);
            no_improve_counter = 0;
        else
            no_improve_counter = no_improve_counter + 1;
        end
        
        if no_improve_counter >= max_no_improve
            fprintf('      [Discrete PSO] Algorithm converged early at iter %d (Score: %.4f)\n', iter, bestScore);
            break;
        end
    end
    
    % Phân xuất các nhóm tốt nhất
    bestGroups = cell(numGroups, 1);
    for g = 1:numGroups
        idx = (g-1)*groupSize + 1 : g*groupSize;
        bestGroups{g} = GBest_X(idx);
    end
end

% =========================================================================
% TOÁN TỬ PSO CHO KHÔNG GIAN RỜI RẠC (SWAP SEQUENCE)
% =========================================================================

% Tìm danh sách hoán đổi để biến mảng current thành target (Phép trừ X2 - X1)
function SS = getSwapSequence(target, current)
    SS = zeros(0, 2);
    temp = current;
    n = length(temp);
    for i = 1:n
        if temp(i) ~= target(i)
            idx = find(temp == target(i), 1);
            SS(end+1, :) = [i, idx];
            % Thực hiện hoán đổi trên temp để theo dõi
            t = temp(i);
            temp(i) = temp(idx);
            temp(idx) = t;
        end
    end
end

% Thực thi chuỗi hoán đổi lên mảng (Phép cộng X + V)
function X_new = applySwapSequence(X, SS)
    X_new = X;
    for k = 1:size(SS, 1)
        i = SS(k, 1); j = SS(k, 2);
        t = X_new(i); 
        X_new(i) = X_new(j); 
        X_new(j) = t;
    end
end

% Giữ lại ngẫu nhiên các lệnh hoán đổi dựa trên xác suất (Phép nhân c * V)
function SS_new = multiplySwapSequence(prob, SS)
    SS_new = zeros(0, 2);
    for k = 1:size(SS, 1)
        if rand() <= prob
            SS_new(end+1, :) = SS(k, :);
        end
    end
end

% Tối ưu hóa chuỗi vận tốc (Gộp các lệnh đổi chỗ thừa để V không bị phình to)
function SS_optimized = simplifySwapSequence(N, SS)
    if isempty(SS)
        SS_optimized = SS;
        return;
    end
    base = 1:N;
    target = applySwapSequence(base, SS);
    % Tìm chuỗi ngắn nhất biến base thành target
    SS_optimized = getSwapSequence(target, base);
end

% =========================================================================
% TỐI ƯU HÓA VECTOR CHỨC NĂNG FITNESS
% =========================================================================
function score = computeScheduleFitnessOptimize(perm, distMat, groupSize, numGroups)
    totalDist = 0;
    numPairsPerGroup = groupSize * (groupSize - 1) / 2; 
    for g = 1:numGroups
        idx = (g-1)*groupSize + 1 : g*groupSize;
        ueIdx = perm(idx);
        if groupSize > 1
            pairs = nchoosek(ueIdx, 2); 
            linearIndices = sub2ind(size(distMat), pairs(:,1), pairs(:,2));
            groupDist = sum(distMat(linearIndices));
        else
            groupDist = 0;
        end
        totalDist = totalDist + groupDist / numPairsPerGroup;
    end
    score = totalDist / numGroups;
end