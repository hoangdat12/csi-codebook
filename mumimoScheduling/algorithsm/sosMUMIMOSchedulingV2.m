function [bestGroups, bestScore] = sosMUMIMOSchedulingV2(W_all, groupSize, maxIter)
    % =========================================================================
    % SOS MU-MIMO SCHEDULING (SUPER FAST VERSION - RANDOM KEY)
    % Bản tối ưu hóa: Tránh cấp phát lại bộ nhớ, dùng hoán vị mảng liên tục.
    % =========================================================================
    
    % Lấy số lượng UE trong Cell
    NUE = size(W_all, 3);
    
    % Kích thước quần thể (Số lượng sinh vật)
    popSize = 30; 

    % Tổng số nhóm MU-MIMO có thể tạo ra
    numGroups = floor(NUE / groupSize);
    
    % =========================================================================
    % BƯỚC 1: TÍNH TOÁN TRƯỚC MA TRẬN KHOẢNG CÁCH (LOOKUP TABLE ONLINE)
    % =========================================================================
    disp('      [SOS-Fast] Computing symmetric distance matrix...');
    distMat = zeros(NUE, NUE);
    for i = 1:NUE-1
        for j = i+1:NUE
            % Sử dụng hàm chordalDistance có sẵn trong thư mục của bro
            distMat(i, j) = chordalDistance(W_all(:,:,i), W_all(:,:,j));
            distMat(j, i) = distMat(i, j); 
        end
    end
    
    % =========================================================================
    % BƯỚC 2: KHỞI TẠO QUẦN THỂ LIÊN TỤC (RANDOM KEY)
    % Thay vì dùng mảng thứ tự [1, 2, 3], ta dùng số thập phân [0.2, 0.9, 0.1]
    % =========================================================================
    population = rand(popSize, NUE);
    fitness = zeros(popSize, 1);
    perms = zeros(popSize, NUE); % Mảng lưu trữ hoán vị thực tế (Discrete)
    
    % Tính Fitness ban đầu cho toàn bộ quần thể
    for p = 1:popSize
        [fitness(p), perms(p,:)] = fastFitness(population(p,:), distMat, groupSize, numGroups);
    end
    
    % Tìm cá thể tốt nhất ban đầu
    [bestScore, bestIdx] = max(fitness);
    bestPop = population(bestIdx, :);
    bestPerm = perms(bestIdx, :);
    
    no_improve_counter = 0;
    max_no_improve = 15; % Dừng sớm nếu sau 15 thế hệ không có tiến triển
    
    disp('      [SOS-Fast] Starting Matrix-based evolutionary generations...');
    
    % =========================================================================
    % BƯỚC 3: VÒNG LẶP TIẾN HÓA (CHỈ DÙNG TOÁN HỌC MA TRẬN, KHÔNG VÒNG LẶP FOR)
    % =========================================================================
    for iter = 1:maxIter        
        for i = 1:popSize
            
            % -----------------------------------------------------------------
            % GIAI ĐOẠN 1: MUTUALISM (CỘNG SINH)
            % -----------------------------------------------------------------
            j = randi(popSize); 
            while j == i, j = randi(popSize); end
            
            % Vector trung bình (Mutual Vector)
            MV = (population(i,:) + population(j,:)) / 2;
            BF1 = randi([1, 2]); 
            BF2 = randi([1, 2]);
            
            % Cập nhật bằng phép toán ma trận siêu tốc (Vectorized)
            newOrgI = population(i,:) + rand(1, NUE) .* (bestPop - BF1 * MV);
            newOrgJ = population(j,:) + rand(1, NUE) .* (bestPop - BF2 * MV);
            
            % Ép các giá trị về lại khoảng [0,1] (Kỹ thuật bọc vòng - Wrap around)
            newOrgI = mod(newOrgI, 1);
            newOrgJ = mod(newOrgJ, 1);
            
            % Đánh giá I
            [fI, pI] = fastFitness(newOrgI, distMat, groupSize, numGroups);
            if fI > fitness(i)
                population(i,:) = newOrgI; fitness(i) = fI; perms(i,:) = pI;
            end
            
            % Đánh giá J
            [fJ, pJ] = fastFitness(newOrgJ, distMat, groupSize, numGroups);
            if fJ > fitness(j)
                population(j,:) = newOrgJ; fitness(j) = fJ; perms(j,:) = pJ;
            end
            
            % -----------------------------------------------------------------
            % GIAI ĐOẠN 2: COMMENSALISM (HỘI SINH)
            % -----------------------------------------------------------------
            j = randi(popSize); 
            while j == i, j = randi(popSize); end
            
            % Toán tử hội sinh
            newOrgI = population(i,:) + (rand(1, NUE)*2 - 1) .* (bestPop - population(j,:));
            newOrgI = mod(newOrgI, 1);
            
            [fNew, pNew] = fastFitness(newOrgI, distMat, groupSize, numGroups);
            if fNew > fitness(i)
                population(i,:) = newOrgI; fitness(i) = fNew; perms(i,:) = pNew;
            end
            
            % -----------------------------------------------------------------
            % GIAI ĐOẠN 3: PARASITISM (KÝ SINH)
            % -----------------------------------------------------------------
            host = randi(popSize); 
            while host == i, host = randi(popSize); end
            
            % Ký sinh trùng: Lấy bản sao của I, đột biến ngẫu nhiên một số "Gen"
            parasite = population(i,:);
            modify_idx = rand(1, NUE) > 0.8; % Chọn ngẫu nhiên 20% lượng UE để hoán đổi
            parasite(modify_idx) = rand(1, sum(modify_idx));
            
            [fParasite, pParasite] = fastFitness(parasite, distMat, groupSize, numGroups);
            if fParasite > fitness(host)
                population(host,:) = parasite; fitness(host) = fParasite; perms(host,:) = pParasite;
            end
        end
        
        % ---------------------------------------------------------------------
        % KIỂM TRA ĐIỀU KIỆN DỪNG SỚM (EARLY STOPPING)
        % ---------------------------------------------------------------------
        [curBest, curIdx] = max(fitness);
        if curBest > bestScore
            bestScore = curBest;
            bestPop = population(curIdx, :);
            bestPerm = perms(curIdx, :);
            no_improve_counter = 0; 
        else
            no_improve_counter = no_improve_counter + 1;
        end
        
        if no_improve_counter >= max_no_improve
            fprintf('      [SOS-Fast] Converged early at iter %d (Score: %.4f)\n', iter, bestScore);
            break;
        end
    end
    
    % =========================================================================
    % BƯỚC 4: XUẤT KẾT QUẢ ĐÚNG ĐỊNH DẠNG CŨ CỦA BẠN (CELL ARRAY)
    % =========================================================================
    bestGroups = cell(numGroups, 1);
    for g = 1:numGroups
        idx = (g-1)*groupSize + 1 : g*groupSize;
        bestGroups{g} = bestPerm(idx);
    end
end

% =========================================================================
% LOCAL FUNCTION: VECTORIZED FITNESS CALCULATION
% =========================================================================
function [score, perm] = fastFitness(continuousOrg, distMat, groupSize, numGroups)
    % BÍ KÍP RANDOM KEY: Lệnh sort chuyển mảng thập phân thành mảng hoán vị
    [~, perm] = sort(continuousOrg);
    
    if groupSize == 2
        % Dành cho ghép cặp MU-MIMO tiêu chuẩn: Vectorize 100%
        ue1 = perm(1:2:end);
        ue2 = perm(2:2:end);
        
        % Dò Lookup Table 1 lần cho toàn bộ 500 cặp bằng lệnh sub2ind
        linear_idx = sub2ind(size(distMat), ue1, ue2);
        
        % Điểm trung bình của tất cả các nhóm
        score = sum(distMat(linear_idx)) / numGroups;
    else
        % Dành cho MU-MIMO > 2 UE (Fallback an toàn)
        totalDist = 0;
        numPairs = groupSize * (groupSize - 1) / 2;
        for g = 1:numGroups
            idx = (g-1)*groupSize + 1 : g*groupSize;
            ueIdx = perm(idx);
            for a = 1:groupSize-1
                for b = a+1:groupSize
                    totalDist = totalDist + distMat(ueIdx(a), ueIdx(b));
                end
            end
        end
        score = totalDist / (numGroups * numPairs);
    end
end