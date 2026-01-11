function W = generateTypeIIPrecoder(cfg, i1, i2)
% GENERATETYPEIIPRECODER Main driver for Type II (Basic) CSI Codebook generation.
%   Integrates input reconstruction, basis calculation, coefficient mapping,
%   and final linear combination to produce the Precoding Matrix W.
%
% INPUTS:
%   cfg : Configuration struct containing CodebookConfig.
%   i1  : Wideband information cell array {i11, i12, i13, i14}.
%   i2  : Subband/Phase information cell array {i21, i22}.
%
% OUTPUT:
%   W   : Precoding Matrix [nPorts x nLayers].

    % --- 1. Extract Configuration Variables ---
    N1 = cfg.CodebookConfig.N1;
    N2 = cfg.CodebookConfig.N2;
    O1 = cfg.CodebookConfig.O1;
    O2 = cfg.CodebookConfig.O2;
    L  = cfg.CodebookConfig.NumberOfBeams;
    sbAmplitude = cfg.CodebookConfig.SubbandAmplitude; 
    NPSK = cfg.CodebookConfig.PhaseAlphabetSize;
    nLayers = cfg.CodebookConfig.numLayers;

    % --- 2. Input Validation ---
    % Checks if i1 and i2 have the correct structure/dimensions.
    validateInputs(nLayers, sbAmplitude, i1, i2);

    % --- 3. Reconstruct Codebook Indices ---
    % Unpacks the reported indices. 
    % Note: i12 is specific to "Type II Basic" for orthogonal basis selection.
    [i11, i12, ~, i14, i21, i22] = computeInputs(L, i1, i2, sbAmplitude);

    % --- 4. Compute Orthogonal Basis Vectors (n1, n2) ---
    % Decodes the combinatorial coefficient i1,2 into basis vectors.
    [n1, n2] = computeN1N2(L, N1, N2, i12);

    % --- 5. Map Indices to Physical Amplitude Values ---
    % Converts indices k^(1), k^(2) into physical values p^(1), p^(2).
    [p1_li, p2_li] = mappingAmplitudesK1K2ToP1P2(i14, i22)

    % --- 6. Compute Phase Coefficients (Phi) ---
    % Converts indices c_li into complex phase values.
    phi = computePhi(i14, i21, L, NPSK);

    % --- 7. Construct Precoding Matrix W ---
    if nLayers == 1
        % Rank 1: W = W^(1)
        % [CORRECTION]: Used p1_li and p2_li instead of p1/p2
        W = computePrecodingMatrix(1, L, N1, N2, O1, O2, n1, n2, p1_li, p2_li, phi, i11);
        
    elseif nLayers == 2
        % Rank 2: W = 1/sqrt(2) * [W^(1), W^(2)]
        
        % Compute vector for Layer 1
        W_l1 = computePrecodingMatrix(1, L, N1, N2, O1, O2, n1, n2, p1_li, p2_li, phi, i11);

        % Compute vector for Layer 2
        W_l2 = computePrecodingMatrix(2, L, N1, N2, O1, O2, n1, n2, p1_li, p2_li, phi, i11);

        % Concatenate and Scale
        W = (1/sqrt(2)) * [W_l1, W_l2];
        
    else
        warning("Invalid nLayers parameters! Only Rank 1 and 2 are supported.");
        W = [];
    end
end

function validateInputs(nLayers, sbAmplitude, i1, i2)
% VALIDATEINPUTS Validates input structures for Type II Basic CSI Codebook.
%   Ensures the cell arrays i1 and i2 adhere to 3GPP TS 38.214 specifications
%   for "Type II Single Panel" (Basic) mode.
%
%   INPUTS:
%       nLayers     : Number of layers (Rank), v = 1 or 2.
%       sbAmplitude : Logical flag for 'subbandAmplitude'.
%       i1          : Cell array {i11, i12, i13, i14}.
%       i2          : Cell array {i21} or {i21, i22}.

    % 1. Validate i1 Structure (Wideband Information)
    % For Type II Basic, i1 must contain 4 elements:
    %   1. i1,1: Orthogonal basis set (q1, q2).
    %   2. i1,2: Orthogonal basis selector (n1, n2) - Specific to Type II Basic.
    %   3. i1,3: Strongest coefficient indicator.
    %   4. i1,4: Wideband amplitude.
    if length(i1) ~= 4
        warning("Structure i1 must contain 4 Cell elements: {i11, i12, i13, i14}.");
    else
        % For Rank 2 (v=2), reporting is required for both layers.
        % i1,3 and i1,4 must contain data for Layer 1 and Layer 2.
        if nLayers == 2
            % Check if i13 (index 3) has dimensions indicating 2 layers
            if size(i1{3}, 2) < 2 && size(i1{3}, 1) < 2
                warning("For Rank 2, i13 and i14 must contain data for both layers (matrix/vector format).");
            end
        end
    end

    % 2. Validate i2 Structure (Subband & Phase Information)
    if sbAmplitude
        % --- Case: subbandAmplitude = 'true' ---
        % i2 must contain 2 elements: {i2,1, i2,2}[cite: 117].
        %   1. i2,1: Wideband phase indicators.
        %   2. i2,2: Subband amplitude indicators.
        if length(i2) ~= 2
            warning("When Subband Amplitude is TRUE, i2 must contain 2 Cell elements: {i21, i22}.");
        end
        
        % For Rank 2, phase and subband amplitude are reported per layer.
        % Ensure the matrices have 2 rows (one for each layer).
        if nLayers == 2 && size(i2{1}, 1) < 2
             warning("For Rank 2, i21 and i22 must be matrices with 2 rows.");
        end
    else
        % --- Case: subbandAmplitude = 'false' ---
        % i2 contains only 1 element: {i2,1}.
        % i2,2 (Subband Amplitude) is NOT reported[cite: 278].
        if length(i2) ~= 1
            warning("When Subband Amplitude is FALSE, i2 must contain only 1 Cell element {i21}.");
        end
    end
end

% i11 = [2, 1]; i12 = [2]; i13 = [3, 1]; 
% i14 = [4, 6, 5, 0, 2, 3, 1 ; 3, 2, 4, 1, 5, 6, 0];
% i21 = [1, 3, 4, 2, 5, 7 ; 2, 0, 5, 1, 4, 6];
% i22 = [0, 1, 0, 1, 0 ; 1, 1, 0, 0, 1];
% i1 = {i11, i12, i13, i14};
% i2 = {i21, i22};
% L = 4;
function [i11, i12, i13, i14, i21, i22] = computeInputs(L, i1_cell, i2_cell, subbandAmplitude)
% COMPUTEINPUTS Reconstructs Type II CSI Codebook parameters.
%   Designed for Type II Basic (Linear Combination) which includes i1,2.
%
% INPUTS:
%   L: Number of beams.
%   i1_cell: Cell array {i11, i12, i13, i14}.
%   i2_cell: Cell array {i21} or {i21, i22}.
%   subbandAmplitude: Boolean (true/false).

    % 1. Input Processing & Defaults
    % Automatically infer subbandAmplitude if not provided
    if nargin < 4
        if length(i2_cell) >= 2
            subbandAmplitude = true;
        else
            subbandAmplitude = false;
        end
    end

    % 2. Extract Input Data
    % TYPE II BASIC Structure: {i1,1, i1,2, i1,3, i1,4}
    try
        i11 = i1_cell{1}; 
        i12 = i1_cell{2}; % Orthogonal basis selection (Specific to Type II Basic)
        i13 = i1_cell{3}; % Strongest coefficient indicator
        i14_reported = i1_cell{4}; % Reported wideband amplitudes
    catch
        error('Error extracting i1_cell. Ensure it has 4 elements {i11, i12, i13, i14} for Type II Basic.');
    end
    
    % i2_cell extraction
    if ~isempty(i2_cell)
        i21_reported = i2_cell{1}; 
    else
        error('Input i2_cell is missing data!');
    end

    % Only extract i2,2 if subbandAmplitude is TRUE and data exists
    i22_reported = [];
    if subbandAmplitude && length(i2_cell) >= 2
        i22_reported = i2_cell{2};
    end

    % 3. Initialization
    v = length(i13);              % Rank (Number of layers)
    num_ports = 2 * L;            % Total number of ports
    
    % Get K2 threshold from table (Table 5.2.2.2.3-4)
    K2 = mappingLToK2(L);

    % Pre-allocate output matrices
    i14 = zeros(v, num_ports);
    i21 = zeros(v, num_ports);
    
    % Initialize i22 to all ones.
    % This handles the default value for non-reported elements correctly.
    %: "When subbandAmplitude is set to 'false', k^(2)=1"
    i22 = ones(v, num_ports); 

    % 4. Layer-wise Reconstruction
    for l = 1:v
        % -- Step A: Strongest Coefficient (i1,3) --
        strong_idx = i13(l) + 1; 

        % -- Step B: i1,4 (Wideband Amplitude) --
        % The strongest coefficient always has amplitude index 7
        i14(l, strong_idx) = 7;
        
        rem_idx = setdiff(1:num_ports, strong_idx);
        
        % Robust assignment: Check dimensions to avoid index errors
        num_rem = length(rem_idx);
        if size(i14_reported, 2) >= num_rem
            i14(l, rem_idx) = i14_reported(l, 1:num_rem);
        else
            % Fallback for safety
            i14(l, rem_idx(1:size(i14_reported, 2))) = i14_reported(l, :);
        end

        % -- Step C: i2,1 (Wideband Phase) --
        i21(l, strong_idx) = 0; % Strongest coeff phase is 0
        
        non_zero_idx = find(i14(l, :) > 0);
        phase_pos = setdiff(non_zero_idx, strong_idx);
        
        if ~isempty(phase_pos) && ~isempty(i21_reported)
             num_phase = min(length(phase_pos), size(i21_reported, 2));
             i21(l, phase_pos(1:num_phase)) = i21_reported(l, 1:num_phase);
        end

        % Step C: Subband Amplitude Logic
        if subbandAmplitude && ~isempty(i22_reported)
            
            % 1. Strongest Beam luôn là 1 (Không nằm trong i22_reported)
            i22(l, strong_idx) = 1; 
            
            candidates = setdiff(non_zero_idx, strong_idx);
            
            if ~isempty(candidates)
                % --- BƯỚC 1: LỌC (SELECTION) ---
                % Mục đích: Tìm ra top (K2-1) thằng mạnh nhất để báo cáo.
                % Logic: Sort Amplitude Descending. Tie-break: Index Ascending.
                
                sort_mat = [i14(l, candidates)', -candidates']; 
                [~, order] = sortrows(sort_mat, 'descend');
                sorted_cand_by_strength = candidates(order); % Danh sách xếp theo độ mạnh

                M_l = length(non_zero_idx);
                num_sb = min(M_l, K2) - 1;
                
                if num_sb > 0
                    % Lấy danh sách index của những thằng được chọn
                    chosen_indices = sorted_cand_by_strength(1:num_sb);
                    
                    % --- BƯỚC 2: SẮP XẾP LẠI THEO INDEX (RE-ORDERING) --- (FIXED HERE)
                    % Bit stream i22_reported luôn map theo thứ tự index tăng dần của các port được chọn
                    target_indices = sort(chosen_indices, 'ascend');
                    
                    % --- BƯỚC 3: MAPPING ---
                    % Gán lần lượt bit báo cáo vào các index đã sắp xếp
                    len_fill = min(num_sb, size(i22_reported, 2));
                    i22(l, target_indices(1:len_fill)) = i22_reported(l, 1:len_fill);
                end
                
                % Các thằng còn lại (Yếu + Zero) giữ nguyên giá trị khởi tạo là 1.
            end
        end
    end
end

% i22l = [0, 1, 1, 0, 1, 1, 0, 1];
% Kli1 = [4, 6, 7, 5, 0, 2, 3, 1], Ml = 7, K2 = 6, Cli = [1, 3, 0, 2, 0, 0, 1, 2], Npsk = 8;
function phi = computePhi(i14, i21, L, NPsk)
% COMPUTEPHI Reconstructs the complex phase coefficients (phi).
%   Implements phase reconstruction logic for Type II CSI Codebook,
%   handling both Strong (high-res) and Weak (low-res) coefficients.
%
% INPUTS:
%   i14  : Wideband Amplitude Indices (0..7). Matrix [Layers x Ports].
%   i21  : Wideband Phase Indices. Matrix [Layers x Ports].
%   L    : Number of beams (used to determine K2 threshold).
%   NPsk : Phase alphabet size (e.g., 4 or 8).
%
% OUTPUT:
%   phi  : Reconstructed complex phase values.

    [v, n] = size(i14); 
    
    % Initialize phi to 1 (Phase 0 rad) for all elements.
    % This correctly handles zero-amplitude ports (where phase is irrelevant).
    phi = ones(v, n); 
    
    % Get K2 threshold from standard table (Table 5.2.2.2.3-4)
    K2 = mappingLToK2(L);

    for l = 1:v
        % 1. Identify Non-Zero Coefficients
        % Find ports where amplitude index > 0
        nonZeroLogic = (i14(l, :) > 0);
        Ml = sum(nonZeroLogic);
        
        % Skip if no non-zero elements
        if Ml == 0, continue; end
        
        % Extract indices and values for sorting
        indices = find(nonZeroLogic);
        vals = i14(l, indices);
        
        % 2. Determine Strongest Coefficients (Tie-breaking Rule)
        % Rule: Sort by Amplitude Descending.
        % Tie-breaker: If amplitudes are identical, prioritize smaller Index.
        % Implementation: Sorting [-indices] in 'descend' yields Ascending Index order.
        [~, sortOrder] = sortrows([vals', -indices'], 'descend');
        sortedIdx = indices(sortOrder);
        
        % 3. Partition into Strong and Weak Sets
        % The number of strong coefficients is min(Ml, K2)
        numStrong = min(Ml, K2); 
        
        % First 'numStrong' elements are Strongest
        strongIndices = sortedIdx(1:numStrong);
        
        % The remaining elements are Weakest
        weakIndices = sortedIdx(numStrong + 1:end);

        % 4. Assign Phase Values
        for i = 1:n
            if i14(l, i) == 0
                % Amplitude is 0, so Phase is 0 (Value = 1)
                phi(l, i) = 1; 
                
            elseif ismember(i, strongIndices)
                % Strongest Coefficients: Use higher resolution (NPsk)
                % Formula: exp(j * 2pi * c / N_PSK)
                phi(l, i) = exp(1j * 2 * pi * i21(l, i) / NPsk);
                
            elseif ismember(i, weakIndices)
                % Weakest Coefficients: Use fixed QPSK resolution (Divisor 4)
                % [Standard Ref: "c_l,i in {0,1,2,3}"]
                phi(l, i) = exp(1j * 2 * pi * i21(l, i) / 4);
            end
        end
    end
end

function [m1, m2] = computeM1M2(n1, n2, q1, q2, O1, O2)
% COMPUTEM1M2 Computes beam indices m1 and m2.
%   Ref: 3GPP TS 38.214 Table 5.2.2.2.3-5.
%
%   Formula:
%       m1^(i) = O1 * n1^(i) + q1  [cite: 295]
%       m2^(i) = O2 * n2^(i) + q2  [cite: 296]

    m1 = O1 * n1 + q1;
    m2 = O2 * n2 + q2;
end

function [n1, n2] = computeN1N2(L, N1, N2, i12)
% COMPUTEN1N2 Reconstructs n1 and n2 vectors from index i1,2.
%   Implements the combinatorial coefficient decoding logic.
%   Ref: 3GPP TS 38.214 Section 5.2.2.2.3.

    % --- 1. Handle Special Cases where i1,2 is not reported ---
    if N2 == 1
        % Case: (N1,N2)=(2,1) -> i1,2 not reported [cite: 148]
        if N1 == 2
            n1 = [0, 1]; n2 = [0, 0]; return;
        % Case: (N1,N2)=(4,1) and L=4 -> i1,2 not reported [cite: 149]
        elseif N1 == 4 && L == 4
            n1 = [0, 1, 2, 3]; n2 = [0, 0, 0, 0]; return;
        end
    end

    % Case: (N1,N2)=(2,2) and L=4 -> i1,2 not reported [cite: 150]
    if N1 == 2 && N2 == 2 && L == 4
        n1 = [0, 1, 0, 1]; n2 = [0, 0, 1, 1]; return;
    end

    % --- 2. Combinatorial Algorithm [cite: 129-134] ---
    s = 0; 
    n1 = zeros(1, L); 
    n2 = zeros(1, L);
    
    % Loop for i = 0 to L-1 [cite: 131]
    for i = 0:L-1
        % Determine range for x* 
        x_start_val = L-1-i;
        x_end_val = N1*N2-1-i;
        
        % Search for largest x* in descending order
        x_star_list = x_end_val:-1:x_start_val; 
        
        x_star = 0;
        for k = 1:length(x_star_list)
            current_x = x_star_list(k);
            % Check condition: i12 - s >= C(x*, L-i) 
            if checkConditionXStart(i12, s, current_x, L - i)
                x_star = current_x;
                break; % Found the largest x*, stop searching
            end
        end
        
        % Update s: s_i = s_{i-1} + C(x*, L-i) 
        e_i = getValFromCTable(x_star, L - i);
        s = s + e_i; 
        
        % Calculate n^(i) [cite: 134]
        n_i = N1*N2 - 1 - x_star;
        
        % Calculate n1^(i) and n2^(i) 
        n1(i+1) = mod(n_i, N1);
        n2(i+1) = (n_i - n1(i+1)) / N1;
    end
end

function isValid = checkConditionXStart(i12, s, x, y)
    val = getValFromCTable(x, y);
    % Check if remaining value is large enough for the combinatorial coefficient
    isValid = (i12 - s) >= val;
end

function val = getValFromCTable(x, y)
% GETVALFROMCTABLE Returns Combinatorial Coefficient C(x,y).
%   Ref: Table 5.2.2.2.3-1 

    % Hardcoded table C(x,y)
    % Rows correspond to x=0..15, Columns correspond to y=1..4
    C = [ ...
        0   0   0   0;    % x = 0
        1   0   0   0;    % x = 1
        2   1   0   0;    % x = 2
        3   3   1   0;    % x = 3
        4   6   4   1;    % x = 4
        5  10  10   5;    % x = 5
        6  15  20  15;    % x = 6
        7  21  35  35;    % x = 7
        8  28  56  70;    % x = 8
        9  36  84 126;    % x = 9
       10  45 120 210;    % x = 10
       11  55 165 330;    % x = 11
       12  66 220 495;    % x = 12
       13  78 286 715;    % x = 13
       14  91 364 1001;   % x = 14
       15 105 455 1365    % x = 15
    ];

    % Safety check for indices
    if x < 0 || y < 1 || y > 4 || x + 1 > size(C, 1)
        val = 0; 
    else
        % Map x to row index (MATLAB is 1-based)
        val = C(x + 1, y);
    end
end

function [p1_li, p2_li] = mappingAmplitudesK1K2ToP1P2(i14, i22) 
% MAPPINGAMPLITUDESK1K2TOP1P2 Maps indicator indices to physical amplitude values.
%   Implements mapping tables from 3GPP TS 38.214.
%
% INPUTS:
%   i14 : Wideband amplitude indices k^(1) (Range 0-7).
%   i22 : Subband amplitude indices k^(2) (Range 0-1).
%
% OUTPUTS:
%   p1_li : Physical wideband amplitudes p^(1).
%   p2_li : Physical subband amplitudes p^(2).
    [numRows, numCols] = size(i14);
    
    p1_li = zeros(numRows, numCols);
    p2_li = zeros(numRows, numCols);
    
    % Reference: Table 5.2.2.2.3-2 Mapping of k^(1) to p^(1) 
    % k=0 -> 0, k=1 -> sqrt(1/64), ..., k=7 -> 1
    p1_val_list = [0, sqrt(1/64), sqrt(1/32), sqrt(1/16), sqrt(1/8), sqrt(1/4), sqrt(1/2), 1];

    for l = 1:numRows
        for i = 1:numCols
            % --- Map Wideband Amplitude (p1) ---
            k1 = i14(l, i);
            if k1 >= 0 && k1 <= 7
                % MATLAB is 1-based, so we use (k1 + 1)
                p1_li(l, i) = p1_val_list(k1 + 1);
            else
                warning('Invalid i14 value at layer %d, port %d', l, i);
            end

            % --- Map Subband Amplitude (p2) ---
            % Reference: Table 5.2.2.2.3-3 Mapping of k^(2) to p^(2) 
            k2 = i22(l, i);
            if k2 == 0
                % k=0 maps to sqrt(1/2)
                p2_li(l, i) = sqrt(1/2); 
            elseif k2 == 1
                % k=1 maps to 1
                p2_li(l, i) = 1;
            else
                warning('Invalid i22 value at layer %d, port %d', l, i);
                p2_li(l, i) = 1; % Default fallback
            end
        end
    end
end

function K2 = mappingLToK2(L)
% MAPPINGLTOK2 Returns the number of strongest coefficients K2.
%   Reference: Table 5.2.2.2.3-4 [cite: 285]
%
% INPUT:
%   L : Number of beams.
%
% OUTPUT:
%   K2: Threshold for subband amplitude reporting.

    if L == 2 || L == 3
        % For L=2 or L=3, K^(2) = 4 [cite: 289, 291]
        K2 = 4;
    elseif L == 4 
        % For L=4, K^(2) = 6 [cite: 293]
        K2 = 6;
    else
        % It is recommended to use error() here to stop execution on invalid input
        warning("Invalid L parameters!");
    end
end

function v = computeBeam(l, m, N1, N2, O1, O2, phaseFactor)
% COMPUTEBEAM Generates the DFT beam vector v_lm.
%   Based on 3GPP TS 38.214 Section 5.2.2.2.3.
%   v_lm is constructed as the Kronecker product of u_n1 and u_n2.
%
% INPUTS:
%   l, m        : Beam indices (corresponds to m1 and m2 in the standard).
%   N1, N2      : Number of antenna ports in each dimension.
%   O1, O2      : Oversampling factors.
%   phaseFactor : Usually 2 for 2*pi in DFT exponent.

    % 1. Compute DFT vector for dimension 2 (Horizontal)
    % Ref: u_m in Eq for v_lm [cite: 311]
    if N2 == 1
        u_n2 = 1; % 1D array case
    else 
        n2 = (0:N2-1).';
        % Exp: j * 2pi * m * n2 / (O2 * N2)
        u_n2 = exp(1j * phaseFactor * pi * m * n2 / (O2 * N2));
    end
    
    % 2. Compute DFT vector for dimension 1 (Vertical)
    n1 = (0:N1-1).';
    % Exp: j * 2pi * l * n1 / (O1 * N1)
    u_n1 = exp(1j * phaseFactor * pi * l * n1 / (O1 * N1));
  
    % 3. Construct 2D Beam via Kronecker Product
    % v_lm = u_n1 (kron) u_n2 [cite: 311]
    % Note: This ordering assumes n2 is the fastest changing index in port mapping.
    v = kron(u_n1, u_n2);
    v = v(:); % Ensure column vector
end

function W = computePrecodingMatrix(l, L, N1, N2, O1, O2, n1, n2, p1, p2, phi, i11)
% COMPUTEPRECODINGMATRIX Generates the Precoding Vector W for a specific layer.
%   Implements Linear Combination (Type II Basic) codebook construction.
%   Ref: 3GPP TS 38.214 Table 5.2.2.2.3-5.
%
% INPUTS:
%   l           : Layer index (1-based).
%   L           : Number of beams.
%   n1, n2      : Orthogonal basis vectors [from computeN1N2].
%   i11         : Basis indices q1, q2.
%   p1, p2, phi : Reconstructed Wideband/Subband Amplitudes and Phase.

    % 1. Compute Physical Beam Indices (m1, m2)
    % m1 = O1*n1 + q1, m2 = O2*n2 + q2 [cite: 295, 296]
    q1 = i11(1);
    q2 = i11(2);
    [m1, m2] = computeM1M2(n1, n2, q1, q2, O1, O2);

    % 2. Calculate Normalization Factor
    % W must have unit power sum.
    % Power of one beam v_lm is (N1*N2).
    % Total Power = (N1*N2) * sum(Amplitude_Coefficients^2)
    p_comp = p1(l, :) .* p2(l, :); 
    sum_energy = sum(p_comp.^2); 
    norm_factor = sqrt(N1 * N2 * sum_energy); 

    % 3. Initialize Polarizations
    sum_first_matrix = zeros(N1 * N2, 1);  % Polarization +45
    sum_second_matrix = zeros(N1 * N2, 1); % Polarization -45

    % 4. Linear Combination Loop
    for i = 0:(L-1)
        idx = i + 1; 
        
        % Generate the DFT beam for the current index
        % m1(idx) corresponds to 'l' in computeBeam, m2(idx) to 'm'
        v_lm = computeBeam(m1(idx), m2(idx), N1, N2, O1, O2, 2);

        % --- Polarization 1 ---
        % Index range: 1 to L
        term1 = v_lm * p1(l, idx) * p2(l, idx) * phi(l, idx);
        sum_first_matrix = sum_first_matrix + term1;

        % --- Polarization 2 ---
        % Index range: L+1 to 2L
        term2 = v_lm * p1(l, idx + L) * p2(l, idx + L) * phi(l, idx + L);
        sum_second_matrix = sum_second_matrix + term2;
    end

    % 5. Concatenate and Normalize
    % W = [W_pol1; W_pol2] / Normalization
    W = (1 / norm_factor) * [sum_first_matrix sum_second_matrix];
end