function W = generateTypeIIPrecoder(cfg, i1, i2)
    % Get config variables
    N1 = cfg.CodebookConfig.N1;
    N2 = cfg.CodebookConfig.N2;
    O1 = cfg.CodebookConfig.O1;
    O2 = cfg.CodebookConfig.O2;
    L = cfg.CodebookConfig.NumberOfBeams;
    sbAmplitude = cfg.CodebookConfig.SubbandAmplitude; 
    NPSK = cfg.CodebookConfig.PhaseAlphabetSize;
    nLayers = cfg.CodebookConfig.numLayers;

    % Validate Input
    validateInputs(nLayers, sbAmplitude, i1, i2);

    % Get PMI variables
    [i11, i12, ~, i14, i21, i22] = computeInputs(L, i1, i2);

    % Compute values
    [n1, n2] = computeN1N2(L, N1, N2, i12);

    [p1_li, p2_li] = mappingAmplitudesK1K2ToP1P2(i14, i22);

    phi = computePhi(i14, i21, L, NPSK);

    if nLayers == 1
        W = computePrecodingMatrix(nLayers, L, N1, N2, O1, O2, n1, n2, p1, p2, phi, i11);
    elseif nLayers == 2
        W_l1 = computePrecodingMatrix(1, L, N1, N2, O1, O2, n1, n2, p1_li, p2_li, phi, i11);
        W_l2 = computePrecodingMatrix(2, L, N1, N2, O1, O2, n1, n2, p1_li, p2_li, phi, i11);

        W = (1/sqrt(2))* [W_l1 W_l2];
    else
        warning("Invalid nLayers parameters!");
    end
end

function validateInputs(nLayers, sbAmplitude, i1, i2)
    if  nLayers == 1
        if length(i1) ~= 4
            warning("Invalid i1 parameters!");
        end
        if sbAmplitude 
            if length(i2) ~= 2
                warning("Invalid i2 parameters!");
            end
        else 
            if length(i2) ~= 1
                warning("Invalid i2 parameters!");
            end
        end
    else
        if sbAmplitude 
            if length(i2) ~= 4
                warning("Invalid i2 parameters!");
            end
        else 
            if length(i2) ~= 2
                warning("Invalid i2 parameters!");
            end
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
function [i11, i12, i13, i14, i21, i22] = computeInputs(L, i1_cell, i2_cell)
    % Extract input
    i11 = i1_cell{1}; 
    i12 = i1_cell{2};
    i13 = i1_cell{3};            
    i14_reported = i1_cell{4};   
    i21_reported = i2_cell{1};   
    i22_reported = i2_cell{2};  

    v = length(i13);
    num_ports = 2 * L;
    
    K2 = mappingLToK2(L);

    i14 = zeros(v, num_ports);
    i21 = zeros(v, num_ports);
    i22 = ones(v, num_ports); 

    for l = 1:v
        strong_idx = i13(l) + 1; 

        i14(l, strong_idx) = 7;
        rem_idx = setdiff(1:num_ports, strong_idx);
        i14(l, rem_idx) = i14_reported(l, :);

        i21(l, strong_idx) = 0;
        non_zero_idx = find(i14(l, :) > 0);
        phase_pos = setdiff(non_zero_idx, strong_idx);
        if ~isempty(phase_pos)
            i21(l, phase_pos) = i21_reported(l, 1:length(phase_pos));
        end

        i22(l, strong_idx) = 1;
        
        candidates = setdiff(non_zero_idx, strong_idx);
        if ~isempty(candidates)
            sort_mat = [i14(l, candidates)', -candidates']; 
            [~, order] = sortrows(sort_mat, 'descend');
            sorted_cand = candidates(order);

            M_l = length(non_zero_idx);
            num_sb = min(M_l, K2) - 1;
            
            if num_sb > 0
                sb_pos = sorted_cand(1:num_sb);
                i22(l, sb_pos) = i22_reported(l, 1:num_sb);
            end
        end
    end
end

% i22l = [0, 1, 1, 0, 1, 1, 0, 1];
% Kli1 = [4, 6, 7, 5, 0, 2, 3, 1], Ml = 7, K2 = 6, Cli = [1, 3, 0, 2, 0, 0, 1, 2], Npsk = 8;
function phi = computePhi(i14, i21, L, NPsk)
    [v, n] = size(i14); 
    phi = ones(v, n); 
    
    K2 = mappingLToK2(L);

    for l = 1:v
        nonZeroLogic = (i14(l, :) > 0);
        Ml = sum(nonZeroLogic);
        
        if Ml == 0, continue; end
        
        indices = find(nonZeroLogic);
        vals = i14(l, indices);
        [~, sortOrder] = sortrows([vals', -indices'], 'descend');
        sortedIdx = indices(sortOrder);
        
        numStrong = min(Ml, K2); 
        strongIndices = sortedIdx(1:numStrong);
        
        weakIndices = sortedIdx(numStrong + 1:end);

        for i = 1:n
            if i14(l, i) == 0
                phi(l, i) = 1; 
            elseif ismember(i, strongIndices)
                phi(l, i) = exp(1j * 2 * pi * i21(l, i) / NPsk);
            elseif ismember(i, weakIndices)
                phi(l, i) = exp(1j * 2 * pi * i21(l, i) / 4);
            end
        end
    end
end

function [m1, m2] = computeM1M2(n1, n2, q1, q2, O1, O2)
    m1 = O1 * n1 + q1;
    m2 = O2 * n2 + q2;
end

function [n1, n2] = computeN1N2(L, N1, N2, i12)
    if N2 == 1
        if N1 == 2
            n1 = [0, 1]; n2 = [0, 0]; return;
        elseif N1 == 4 && L == 4
            n1 = [0, 1, 2, 3]; n2 = [0, 0, 0, 0]; return;
        end
    end

    if N1 == 2 && N2 == 2 && L == 4
        n1 = [0, 1, 0, 1]; n2 = [0, 0, 1, 1]; return;
    end

    s = 0; 
    n1 = zeros(1, L); 
    n2 = zeros(1, L);
    
    for i = 0:L-1
        x_start_val = L-1-i;
        x_end_val = N1*N2-1-i;
        x_star_list = x_end_val:-1:x_start_val; 
        
        x_star = 0;
        for k = 1:length(x_star_list)
            current_x = x_star_list(k);
            if checkConditionXStart(i12, s, current_x, L - i)
                x_star = current_x;
                break; 
            end
        end
        
        e_i = getValFromCTable(x_star, L - i);
        s = s + e_i; 
        
        n_i = N1*N2 - 1 - x_star;
        
        n1(i+1) = mod(n_i, N1);
        n2(i+1) = (n_i - n1(i+1)) / N1;
    end
end

function isValid = checkConditionXStart(i12, s, x, y)
    val = getValFromCTable(x, y);
    isValid = (i12 - s) >= val;
end

function val = getValFromCTable(x, y)
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

    if x < 0 || y < 1 || y > 4 || x + 1 > size(C, 1)
        val = 0; % Tránh lỗi index out of bounds
    else
        val = C(x + 1, y);
    end
end

function [p1_li, p2_li] = mappingAmplitudesK1K2ToP1P2(i14, i22) 
    [numRows, numCols] = size(i14);
    
    p1_li = zeros(numRows, numCols);
    p2_li = zeros(numRows, numCols);
    
    p1_val_list = [0, sqrt(1/64), sqrt(1/32), sqrt(1/16), sqrt(1/8), sqrt(1/4), sqrt(1/2), 1];

    for l = 1:numRows
        for i = 1:numCols
            k1 = i14(l, i);
            if k1 >= 0 && k1 <= 7
                p1_li(l, i) = p1_val_list(k1 + 1);
            else
                warning('Invalid i14 value at layer %d, port %d', l, i);
            end

            k2 = i22(l, i);
            if k2 == 0
                p2_li(l, i) = sqrt(1/2); 
            elseif k2 == 1
                p2_li(l, i) = 1;
            else
                warning('Invalid i22 value at layer %d, port %d', l, i);
                p2_li(l, i) = 1; 
            end
        end
    end
end

function K2 = mappingLToK2(L)
    if L == 2 || L == 3
        K2 = 4;
    elseif L == 4 
        K2 = 6;
    else
        warning("Invalid L parameters!");
    end
end

function v = computeBeam(l, m, N1, N2, O1, O2, phaseFactor)
    if N2 == 1
        u_n2 = 1;
    else 
        n2 = (0:N2-1).';
        u_n2 = exp(1j * phaseFactor * pi * m * n2 / (O2 * N2));
    end
    
    n1 = (0:N1-1).';
    u_n1 = exp(1j * phaseFactor * pi * l * n1 / (O1 * N1));
  
    v = kron(u_n1, u_n2);
    v = v(:);
end

function W = computePrecodingMatrix(l, L, N1, N2, O1, O2, n1, n2, p1, p2, phi, i11)
    q1 = i11(1);
    q2 = i11(2);
    [m1, m2] = computeM1M2(n1, n2, q1, q2, O1, O2);

    p_comp = p1(l, :) .* p2(l, :); 
    sum_energy = sum(p_comp.^2); 
    norm_factor = sqrt(N1 * N2 * sum_energy); % 

    sum_first_matrix = zeros(N1 * N2, 1);
    sum_second_matrix = zeros(N1 * N2, 1);

    for i = 0:(L-1)
        idx = i + 1; 
        
        v_lm = computeBeam(m1(idx), m2(idx), N1, N2, O1, O2, 2);

        term1 = v_lm * p1(l, idx) * p2(l, idx) * phi(l, idx);
        sum_first_matrix = sum_first_matrix + term1;

        term2 = v_lm * p1(l, idx + L) * p2(l, idx + L) * phi(l, idx + L);
        sum_second_matrix = sum_second_matrix + term2;
    end

    W = (1 / norm_factor) * [sum_first_matrix; sum_second_matrix];
end