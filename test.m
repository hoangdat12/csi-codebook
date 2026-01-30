clear; clc; close all;

setupPath();

% --- CẤU HÌNH HỆ THỐNG ---
Num_UEs = 100; 
nlayers_per_ue = 2; 
Max_Total_Layers = 4; 
Target_Num_Users = 2;

THREAD_HOLD = exp(-15);

% Cấu hình 8 Ăng-ten (N1=4, N2=1 -> 2*4*1 = 8 ports)
gNB_Params.NumAntennas = 8;
N1 = 4; 
N2 = 1; 
O1 = 4; 
O2 = 1;
L = 2; 

pdsch_cfg = customPDSCHConfig(); 
cfg_base = struct('N1',N1, 'N2',N2, 'O1',O1, 'O2',O2, 'NumberOfBeams',L, ...
                  'PhaseAlphabetSize',8, 'SubbandAmplitude',true, 'numLayers',nlayers_per_ue);
pdsch_cfg.CodebookConfig = cfg_base;

All_UE_Feedback = cell(1, Num_UEs);

% Tính giới hạn Max cho i12 (Combinatorial Coefficient)
% Với N1=4, N2=1, L=2 => nchoosek(4,2) - 1 = 5
Max_i12 = nchoosek(N1*N2, L) - 1; 

for u = 1:Num_UEs
    % i11 (q1) chạy từ 0 đến N1*O1 - 1 (0 đến 15)
    rand_i11 = [randi([0 (N1*O1 - 1)]), 0]; 
    
    % i12 chạy từ 0 đến Max_i12 (0 đến 5)
    rand_i12 = randi([0 Max_i12]); 
    
    pdsch_cfg.Indices.i1 = {rand_i11, rand_i12, [0, 1], [4 6 5 0; 3 2 4 1]}; 
    pdsch_cfg.Indices.i2 = {[1 0 1 1; 0 1 0 1], [0 1 0 1; 1 0 1 0]};           
    
    W = generateTypeIIPrecoder(pdsch_cfg, pdsch_cfg.Indices.i1, pdsch_cfg.Indices.i2);
        
    All_UE_Feedback{u} = W;
end

% --- GỌI HÀM TÌM CẶP ---
[best_pair, all_pair, min_corr, best_Cmn] = FindBestPair(All_UE_Feedback, THREAD_HOLD);

disp(best_Cmn);

if ~isempty(all_pair)
    results_table = struct2table(all_pair);
    disp('UE Candidate:');
    disp(results_table);
else
    disp('Empty List!.');
end

fprintf('Best UE Selected: %d and %d\n', best_pair(1), best_pair(2));

% Tính toán số lượng
total_possible_pairs = nchoosek(Num_UEs, 2); % Tổng số cặp có thể có
num_valid_pairs = length(all_pair);          % Số cặp hợp lệ (nhỏ hơn THREAD_HOLD)
num_invalid_pairs = total_possible_pairs - num_valid_pairs; % Số cặp không hợp lệ

fprintf('Numer of UE Pair Invalid: %d\n', num_invalid_pairs);
fprintf('Numer of UE Pair Valid: %d\n', num_valid_pairs);





% --- CẤU HÌNH TEST ---
testNumUes = 1;
% Lưu ý: Sử dụng hàm sinh dữ liệu nén (Compressed)
randomPMIs = randomPMIConfig(testNumUes, N1, N2, O1, O2, L, nlayers_per_ue);

% --- VÒNG LẶP IN KẾT QUẢ ---
for u = 1:testNumUes
    fprintf('\n================ UE #%d REPORTED INDICES (COMPRESSED) ================\n', u);
    
    % Lấy struct dữ liệu của UE u
    indices = randomPMIs{u};
    
    % ============================================================
    % PHẦN 1: WIDEBAND INFO (i1)
    % ============================================================
    fprintf('--- i1 (Wideband Info) ---\n');
    
    % i1_1: Rotation
    fprintf('i1,1 (Rotation)       : [%d, %d]\n', indices.i1_1(1), indices.i1_1(2));
    
    % i1_2: Beam Selection
    fprintf('i1,2 (Beam Selector)  : %d\n', indices.i1_2);
    
    % i1_3: Strongest Beam Index
    fprintf('i1,3 (Strongest IDX)  : ');
    disp(indices.i1_3);
    
    % i1_4: Wideband Amplitude (Chỉ 2L-1 phần tử)
    fprintf('i1,4 (WB Amp - %d cols): \n', size(indices.i1_4, 2));
    % In từng dòng cho dễ nhìn
    for lyr = 1:size(indices.i1_4, 1)
        fprintf('  Layer %d: %s\n', lyr, num2str(indices.i1_4(lyr, :)));
    end
    
    % ============================================================
    % PHẦN 2: SUBBAND INFO (i2) - DẠNG DANH SÁCH
    % ============================================================
    fprintf('\n--- i2 (Subband Info - Variable Length List) ---\n');
    
    for lyr = 1:nlayers_per_ue
        fprintf('>> Layer %d:\n', lyr);
        
        % 1. Nhóm Strong (Phase + Amp)
        strong_ph = indices.i2_strong_phase{lyr};
        strong_amp = indices.i2_strong_amp{lyr};
        
        if isempty(strong_ph)
            fprintf('   [Strong Group]: (None)\n');
        else
            fprintf('   [Strong Group] (%d items):\n', length(strong_ph));
            fprintf('      Phase (3-bit): %s\n', num2str(strong_ph));
            fprintf('      Amp   (1-bit): %s\n', num2str(strong_amp));
        end
        
        % 2. Nhóm Weak (Chỉ Phase)
        weak_ph = indices.i2_weak_phase{lyr};
        
        if isempty(weak_ph)
            fprintf('   [Weak Group]  : (None)\n');
        else
            fprintf('   [Weak Group]   (%d items):\n', length(weak_ph));
            fprintf('      Phase (2-bit): %s\n', num2str(weak_ph));
        end
        fprintf('   ------------------------------------\n');
    end
end




%% Helper

function [best_pair, all_candidate_pairs, min_corr, best_Cmn] = FindBestPair(All_UE_Feedback, THREAD_HOLD)
    num_ues = length(All_UE_Feedback);
    min_corr = inf; 
    best_pair = [0, 0];
    best_Cmn = 0;
    all_candidate_pairs = []; 

    count = 1;
    for m = 1:num_ues
        for n = m+1:num_ues
            W1 = All_UE_Feedback{m};
            W2 = All_UE_Feedback{n};
            
            c_complex = PMIPair(W1, W2);
            current_corr = abs(c_complex);
            
            % 1. Lưu lại tất cả các cặp thỏa mãn ngưỡng (Threshold)
            if current_corr < THREAD_HOLD
                all_candidate_pairs(count).indices = [m, n];
                all_candidate_pairs(count).correlation = current_corr;
                count = count + 1;
            end
            
            if current_corr < min_corr
                min_corr = current_corr;
                best_pair = [m, n];
                best_Cmn = c_complex;
            end
        end
    end
end


function UE_Reported_Indices = randomPMIConfig(Num_UEs, N1, N2, O1, O2, L, NumLayers)
    % Hàm sinh PMI Indices dạng NÉN (Compressed) giống như UE gửi lên.
    % Output dùng để test thuật toán Reconstruction tại gNB.
    
    UE_Reported_Indices = cell(1, Num_UEs);

    % --- Config ---
    if L == 2 || L == 3
        K2 = 4;
    else % L = 4
        K2 = 6;
    end
    NPSK = 8; % 3 bits phase
    Max_i12 = nchoosek(N1*N2, L) - 1; 

    for u = 1:Num_UEs
        % Cấu trúc lưu trữ cho 1 UE
        ue_data.i1_1 = []; % Rotation
        ue_data.i1_2 = []; % Beam Select
        ue_data.i1_3 = []; % Strongest Beam Index
        ue_data.i1_4 = []; % WB Amp (2L-1 phần tử)
        
        % i2 lưu dạng Cell vì độ dài mỗi layer khác nhau
        ue_data.i2_strong_phase = cell(1, NumLayers);
        ue_data.i2_strong_amp   = cell(1, NumLayers);
        ue_data.i2_weak_phase   = cell(1, NumLayers);
        
        % --- SINH i1 ---
        q1 = randi([0 O1-1]);
        q2 = (N2 > 1) * randi([0 O2-1]);
        ue_data.i1_1 = [q1, q2];
        ue_data.i1_2 = randi([0 Max_i12]);
        
        % i1_3: Chỉ thị beam mạnh nhất (Index thực 0..2L-1)
        ue_data.i1_3 = randi([0, 2*L-1], 1, NumLayers);
        
        % i1_4: Sinh 2L-1 giá trị biên độ WB
        i14_matrix = zeros(NumLayers, 2*L - 1);
        
        for lyr = 1:NumLayers
            % Random biên độ cho 2L-1 beam còn lại (0..7)
            % UE không gửi biên độ của beam mạnh nhất (mặc định là 7)
            % UE chỉ gửi 2L-1 giá trị này.
            i14_matrix(lyr, :) = randi([0, 7], 1, 2*L - 1);
            
            % --- SINH i2 (Dựa trên logic nén) ---
            % Để sinh đúng i2, ta cần mô phỏng quá trình "sort" mà UE đã làm
            % 1. Tái tạo danh sách biên độ đầy đủ để biết vị trí index thực
            
            short_wb = i14_matrix(lyr, :);
            strong_idx = ue_data.i1_3(lyr) + 1; % 1-based
            
            % Map 2L-1 giá trị vào vị trí thực tế (trừ vị trí strongest)
            full_wb_temp = zeros(1, 2*L);
            full_wb_temp(strong_idx) = 7; % Giả định biên độ strongest = 7 để sort đúng
            
            mask = true(1, 2*L);
            mask(strong_idx) = false;
            full_wb_temp(mask) = short_wb; % Điền 2L-1 giá trị vào chỗ trống
            
            % 2. Tìm các beam cần báo cáo (WB > 0, trừ Strongest)
            idx_candidates = find(full_wb_temp > 0);
            idx_candidates = idx_candidates(idx_candidates ~= strong_idx);
            
            if isempty(idx_candidates)
                % Không có gì để báo cáo
                ue_data.i2_strong_phase{lyr} = [];
                ue_data.i2_strong_amp{lyr}   = [];
                ue_data.i2_weak_phase{lyr}   = [];
                continue;
            end
            
            % 3. Sắp xếp để phân loại Mạnh/Yếu (UE làm bước này)
            vals = full_wb_temp(idx_candidates);
            % Sort giảm dần biên độ, nếu bằng nhau thì index nhỏ đứng trước
            [~, sort_order] = sort(vals, 'descend', 'ComparisonMethod', 'real');
            sorted_ind = idx_candidates(sort_order);
            
            % 4. Chia nhóm
            Ml = length(idx_candidates) + 1; % +1 vì tính cả strongest beam vào Ml
            num_strong = min(Ml, K2) - 1;    % Trừ 1 vì strongest beam không báo cáo i2
            
            idx_strong_group = sorted_ind(1 : min(length(sorted_ind), num_strong));
            idx_weak_group   = sorted_ind(num_strong+1 : end);
            
            % 5. Sinh dữ liệu nén (Đây là cái UE gửi đi)
            % Nhóm Mạnh: Full phase (3 bit), Amp (1 bit)
            ue_data.i2_strong_phase{lyr} = randi([0, NPSK-1], 1, length(idx_strong_group));
            ue_data.i2_strong_amp{lyr}   = randi([0, 1],      1, length(idx_strong_group));
            
            % Nhóm Yếu: Phase nén (2 bit)
            ue_data.i2_weak_phase{lyr}   = randi([0, 3],      1, length(idx_weak_group));
            
            % Lưu ý: UE KHÔNG gửi index (vị trí). 
            % gNB phải tự tìm lại index bằng cách sort lại i1_4 y hệt như UE đã làm.
        end
        ue_data.i1_4 = i14_matrix;
        
        UE_Reported_Indices{u} = ue_data;
    end
end