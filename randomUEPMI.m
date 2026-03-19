% --- Script: Generate 20,000 PMI Configurations and Precoders ---
clear; clc;
setupPath();

Num_UEs = 20000;

% Cấu hình Antenna (8 CSI-RS ports)
N1 = 4; 
N2 = 1;
O1 = 4;
O2 = 1;
L  = 2; % Số lượng chùm tia (beams)
NumLayers = 2; % RI = 2
subbandAmplitude = true;

UE_Reported_Indices = randomPMIConfig(Num_UEs, N1, N2, O1, O2, L, NumLayers, subbandAmplitude);

cfg = struct();
cfg.CodebookConfig.N1 = N1;
cfg.CodebookConfig.N2 = N2;
cfg.CodebookConfig.O1 = O1;
cfg.CodebookConfig.O2 = O2;
cfg.CodebookConfig.NumberOfBeams = L;     % L
cfg.CodebookConfig.PhaseAlphabetSize = 8; % NPSK
cfg.CodebookConfig.SubbandAmplitude = subbandAmplitude;
cfg.CodebookConfig.numLayers = NumLayers; % nLayers

% Cấp phát sẵn bộ nhớ cho W_all: kích thước [Số Ăng-ten, Số Layer, Số UE]
Num_Antennas = 2 * N1 * N2; 
W_all = zeros(Num_Antennas, NumLayers, Num_UEs);

for u = 1:Num_UEs
    % Lấy dữ liệu của UE thứ u
    indices_ue = UE_Reported_Indices{u};
    
    % Hàm randomPMIConfig đã trả về i1 và i2 dưới dạng cell array đúng chuẩn
    % i1 = {i11, i12, i13, i14}
    % i2 = {i21, i22}
    i1 = indices_ue.i1;
    i2 = indices_ue.i2;
    
    % Gọi hàm tạo W (đảm bảo hàm generateTypeIIPrecoder đã có sẵn)
    W_ue = generateTypeIIPrecoder(cfg, i1, i2);
    
    % Lưu ma trận W của UE này vào mảng tổng
    W_all(:, :, u) = W_ue;
end


function [bestGroups, bestScore] = sosMUMIMOScheduling(W_all, groupSize, maxIter)
% -----------------------------------------------------------------
% SOS-based MU-MIMO Scheduling
% Tối ưu hóa chọn tập UE maximize orthogonality
% INPUT:
%   W_all     : [Nant x nLayers x NUE]
%   groupSize : số UE phục vụ đồng thời (thường = 2 hoặc 4)
%   maxIter   : số vòng lặp SOS
% -----------------------------------------------------------------

    NUE = size(W_all, 3);
    popSize = 50; % số cá thể trong quần thể
    
    % --- Khởi tạo quần thể ---
    % Mỗi cá thể = 1 bộ lịch: NUE/groupSize nhóm
    numGroups = floor(NUE / groupSize);
    
    % Population: [popSize x NUE] - mỗi hàng là 1 permutation của UE indices
    population = zeros(popSize, NUE);
    for p = 1:popSize
        population(p, :) = randperm(NUE);
    end
    
    % Hàm fitness: tính tổng chordal distance trung bình các nhóm
    fitnessFunc = @(perm) computeScheduleFitness(perm, W_all, groupSize, numGroups);
    
    % Tính fitness ban đầu
    fitness = zeros(popSize, 1);
    for p = 1:popSize
        fitness(p) = fitnessFunc(population(p, :));
    end
    
    bestScore = max(fitness);
    [~, bestIdx] = max(fitness);
    bestPerm = population(bestIdx, :);
    
    fprintf('SOS bắt đầu | Fitness ban đầu: %.4f\n', bestScore);
    
    % --- Vòng lặp SOS ---
    for iter = 1:maxIter
        
        % ===== MUTUALISM PHASE =====
        for i = 1:popSize
            % Chọn ngẫu nhiên 1 organism j ≠ i
            j = randi(popSize);
            while j == i, j = randi(popSize); end
            
            % Mutual vector = "trung bình" của 2 permutation (dùng crossover)
            % Swap một số vị trí ngẫu nhiên
            newOrgI = mutualismSwap(population(i,:), population(j,:));
            newOrgJ = mutualismSwap(population(j,:), population(i,:));
            
            % Cập nhật nếu tốt hơn
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
            
            % Organism i học từ j bằng cách swap ngẫu nhiên
            newOrg = commensalismSwap(population(i,:), population(j,:));
            fNew = fitnessFunc(newOrg);
            if fNew > fitness(i)
                population(i,:) = newOrg;
                fitness(i) = fNew;
            end
        end
        
        % ===== PARASITISM PHASE =====
        for i = 1:popSize
            % Tạo "parasite" từ organism i bằng random perturbation
            parasite = parasitePerturb(population(i,:));
            
            % Chọn host ngẫu nhiên
            host = randi(popSize);
            while host == i, host = randi(popSize); end
            
            fParasite = fitnessFunc(parasite);
            if fParasite > fitness(host)
                population(host,:) = parasite;
                fitness(host) = fParasite;
            end
        end
        
        % Cập nhật best
        [curBest, curIdx] = max(fitness);
        if curBest > bestScore
            bestScore = curBest;
            bestPerm = population(curIdx, :);
        end
        
        if mod(iter, 10) == 0
            fprintf('Iter %d/%d | Best fitness: %.4f\n', iter, maxIter, bestScore);
        end
    end
    
    % --- Giải mã kết quả ---
    bestGroups = cell(numGroups, 1);
    for g = 1:numGroups
        idx = (g-1)*groupSize + 1 : g*groupSize;
        bestGroups{g} = bestPerm(idx);
    end
    
    fprintf('SOS hoàn thành | Best score: %.4f\n', bestScore);
end

% -----------------------------------------------------------------
% Helper functions
% -----------------------------------------------------------------
function score = computeScheduleFitness(perm, W_all, groupSize, numGroups)
    totalDist = 0;
    for g = 1:numGroups
        idx = (g-1)*groupSize + 1 : g*groupSize;
        ueIdx = perm(idx);
        % Tính pairwise chordal distance trong nhóm
        groupDist = 0; cnt = 0;
        for a = 1:groupSize
            for b = a+1:groupSize
                Wa = W_all(:,:,ueIdx(a));
                Wb = W_all(:,:,ueIdx(b));
                groupDist = groupDist + chordalDistance(Wa, Wb);
                cnt = cnt + 1;
            end
        end
        totalDist = totalDist + groupDist / cnt;
    end
    score = totalDist / numGroups;
end

function newPerm = mutualismSwap(permA, permB)
    n = length(permA);
    newPerm = permA;
    % Lấy một đoạn từ permB và chèn vào newPerm (order crossover)
    pts = sort(randperm(n, 2));
    segment = permB(pts(1):pts(2));
    newPerm(ismember(newPerm, segment)) = [];
    insertPos = pts(1);
    newPerm = [newPerm(1:insertPos-1), segment, newPerm(insertPos:end)];
end

function newPerm = commensalismSwap(permA, ~)
    newPerm = permA;
    % Đảo ngẫu nhiên 2 vị trí
    pts = randperm(length(permA), 2);
    newPerm(pts(1)) = permA(pts(2));
    newPerm(pts(2)) = permA(pts(1));
end

function parasite = parasitePerturb(perm)
    parasite = perm;
    % Scramble một đoạn ngẫu nhiên
    n = length(perm);
    pts = sort(randperm(n, 2));
    parasite(pts(1):pts(2)) = parasite(pts(1) + randperm(pts(2)-pts(1)+1) - 1);
end

function orthogonalityScore = chordalDistance(PMI_m, PMI_n)
    % -----------------------------------------------------------------
    % INPUT VALIDATION
    % -----------------------------------------------------------------
    if size(PMI_m, 1) ~= size(PMI_n, 1)
        error('Input matrices must have the same number of rows (Antennas).');
    end

    % -----------------------------------------------------------------
    % CHORDAL DISTANCE CALCULATION (Chuẩn cho MU-MIMO)
    % -----------------------------------------------------------------
    % 1. Tính ma trận tương quan chéo (R = W1' * W2)
    R = PMI_m' * PMI_n;
    
    % 2. Tính bình phương chuẩn Frobenius của R
    normR2 = norm(R, 'fro')^2;
    
    % 3. Chuẩn hóa bằng năng lượng của từng PMI
    normM2 = norm(PMI_m, 'fro')^2;
    normN2 = norm(PMI_n, 'fro')^2;
    
    correlation = normR2 / (normM2 * normN2);
    
    orthogonalityScore = 1 - correlation;
end