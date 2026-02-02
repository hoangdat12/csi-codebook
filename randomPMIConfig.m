function UE_Reported_Indices = randomPMIConfig(Num_UEs, N1, N2, O1, O2, L, NumLayers, subbandAmplitude)
    % Example

    % Num_UEs            = 1;
    % nlayers_per_ue     = 2;
    % N1 = 4;   
    % N2 = 1;
    % O1 = 4;
    % O2 = 1;
    % L  = 2;
    % subbandAmplitude   = true;

    % UE_Reported_Indices = randomPMIConfig( ...
    %     Num_UEs, N1, N2, O1, O2, L, nlayers_per_ue, subbandAmplitude);

    % fprintf('\n================== CHECKING UE #1 DATA ==================\n');

    % indices_ue1 = UE_Reported_Indices{1};

    % i1_cell = indices_ue1.i1;

    % i11 = i1_cell{1};   % Rotation indices [q1, q2]
    % i12 = i1_cell{2};   % Orthogonal basis selector
    % i13 = i1_cell{3};   % Strongest beam index
    % i14 = i1_cell{4};   % Wideband amplitude (2L-1 elements)

    % i2_cell = indices_ue1.i2;

    % i21 = i2_cell{1};   % Subband phase matrix (strong + weak)
    % i22 = i2_cell{2};   % Subband amplitude matrix (strong only)

    % fprintf('--- PART 1: i1 (Wideband) -------------------------------\n');

    % disp('i11 (Rotation [q1, q2]):');
    % disp(i11);

    % disp('i12 (Orthogonal Basis Selector):');
    % disp(i12);

    % disp('i13 (Strongest Coefficient Index):');
    % disp(i13);

    % disp('i14 (Wideband Amplitude - 2L-1 elements):');
    % disp(i14);

    % fprintf('--- PART 2: i2 (Subband - Compressed) -------------------\n');

    % disp('i21 (Subband Phase Matrix - Mixed Strong/Weak):');
    % disp(i21);

    % disp('i22 (Subband Amplitude Matrix - Strong Group Only):');
    % disp(i22);

    % fprintf('=========================================================\n');

    if nargin < 8
        subbandAmplitude = true;
    end

    UE_Reported_Indices = cell(1, Num_UEs);

    if L == 2 || L == 3
        K2 = 4;
    else 
        K2 = 6;
    end
    NPSK = 8;
    Max_i12 = nchoosek(N1*N2, L) - 1;

    for u = 1:Num_UEs
        q1 = randi([0 O1-1]);
        q2 = (N2 > 1) * randi([0 O2-1]);
        i11 = [q1, q2];
        i12 = randi([0 Max_i12]);
        i13 = randi([0, 2*L-1], 1, NumLayers);
        
        i14 = zeros(NumLayers, 2*L - 1); 
        
        temp_i21 = cell(1, NumLayers); 
        temp_i22 = cell(1, NumLayers); 
        max_len_i21 = 0;
        max_len_i22 = 0;

        for lyr = 1:NumLayers
            raw_wb = randi([0, 7], 1, 2*L - 1); 
            raw_wb(raw_wb < 0) = 0; 
            i14(lyr, :) = raw_wb;
            
            short_wb = i14(lyr, :);
            strong_idx = i13(lyr) + 1;
            full_wb_temp = zeros(1, 2*L);
            full_wb_temp(strong_idx) = 7; 
            mask = true(1, 2*L); mask(strong_idx) = false;
            full_wb_temp(mask) = short_wb; 
            
            idx_candidates = find(full_wb_temp > 0);
            idx_candidates = idx_candidates(idx_candidates ~= strong_idx);
            
            if isempty(idx_candidates)
                temp_i21{lyr} = []; 
                temp_i22{lyr} = [];
                continue; 
            end
            
            vals = full_wb_temp(idx_candidates);
            [~, sort_order] = sort(vals, 'descend', 'ComparisonMethod', 'real');
            sorted_ind = idx_candidates(sort_order);
            
            if subbandAmplitude == false
                temp_i21{lyr} = randi([0, NPSK-1], 1, length(sorted_ind));
                temp_i22{lyr} = []; 
            else
                Ml = length(idx_candidates) + 1; 
                num_strong = min(Ml, K2) - 1;    
                
                idx_strong_group = sorted_ind(1 : min(length(sorted_ind), num_strong));
                idx_weak_group   = sorted_ind(num_strong+1 : end);
                
                ph_strong = randi([0, NPSK-1], 1, length(idx_strong_group));
                amp_strong = randi([0, 1], 1, length(idx_strong_group));
                
                ph_weak = randi([0, 3], 1, length(idx_weak_group));
                
                % GỘP VÀO VECTOR LAYER
                temp_i21{lyr} = [ph_strong, ph_weak]; 
                temp_i22{lyr} = amp_strong; 
            end
            
            max_len_i21 = max(max_len_i21, length(temp_i21{lyr}));
            max_len_i22 = max(max_len_i22, length(temp_i22{lyr}));
        end
        
        i21_matrix = zeros(NumLayers, max_len_i21);
        i22_matrix = zeros(NumLayers, max_len_i22);
        
        for lyr = 1:NumLayers
            if ~isempty(temp_i21{lyr})
                i21_matrix(lyr, 1:length(temp_i21{lyr})) = temp_i21{lyr};
            end
            if ~isempty(temp_i22{lyr})
                i22_matrix(lyr, 1:length(temp_i22{lyr})) = temp_i22{lyr};
            end
        end
        
        indices.i1 = {i11, i12, i13, i14};
        indices.i2 = {i21_matrix, i22_matrix};
        
        UE_Reported_Indices{u} = indices;
    end
end