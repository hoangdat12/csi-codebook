clear; clc; close all;

setupPath();

% --- CẤU HÌNH HỆ THỐNG ---
Num_UEs = 100; 
nlayers_per_ue = 2; 
Max_Total_Layers = 4; 
Target_Num_Users = 2;

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
[Selected_UE_IDs, min_correlation, best_Cmn] = FindBestPair(All_UE_Feedback);

disp(best_Cmn);

fprintf('Cặp UE được chọn: %d và %d\n', Selected_UE_IDs(1), Selected_UE_IDs(2));
fprintf('Giá trị tương quan thấp nhất (Abs): %.4f\n', min_correlation);

% -----------------------------------------------------------
%                   KHU VỰC CÁC HÀM (FUNCTIONS)
% -----------------------------------------------------------

function [best_pair, min_corr, best_Cmn] = FindBestPair(All_UE_Feedback)
    num_ues = length(All_UE_Feedback);
    min_corr = inf; 
    best_pair = [0, 0];
    
    for m = 1:num_ues
        for n = m+1:num_ues
            W1 = All_UE_Feedback{m};
            W2 = All_UE_Feedback{n};
             
            c_complex = PMIPair(W1, W2);
             
            current_corr = abs(c_complex);
             
            if current_corr < min_corr
                min_corr = current_corr;
                best_pair = [m, n];

                best_Cmn = c_complex;
            end
        end
    end
end

function C_mn = PMIPair(PMI_m, PMI_n)
    if any(size(PMI_m) ~= size(PMI_n))
        error('Invalid size!');
    end

    [numRows, numCols] = size(PMI_m);
    C_mn = 0;
    
    for i = 1:numRows
        for j = 1:numCols
            C_mn = C_mn + PMI_m(i,j) * conj(PMI_n(i,j));
        end
    end
end