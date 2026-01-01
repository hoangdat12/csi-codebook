function W = generateTypeIMultiPanelPrecoder(cfg, nLayers, n_g, i1, i2)
    N1 = cfg.CodebookConfig.N1;
    N2 = cfg.CodebookConfig.N2;
    O1 = cfg.CodebookConfig.O1;
    O2 = cfg.CodebookConfig.O2;
    nPorts = cfg.CodebookConfig.nPorts;
    codebookMode = cfg.CodebookConfig.codebookMode;

    [i11, i12, i13, i14, i2] = computeInputs(nLayers, i1, i2, N2);

    validateInputs(codebookMode, nLayers, n_g, N1, N2, O1, O2, i11, i12, i13, i14, i2, nPorts);

    [l, lp, m, mp, p, n] = getBeamIndices(nLayers, i11, i12, i13, i14, i2, N1, N2, O1, O2);

    switch nLayers
        case 1
            % Rank 1: Single layer precoding using base beam v_lm
            v_lm = computeBeam(l, m, N1, N2, O1, O2, 2);

            if codebookMode == 1
                W = calcWMatrixMultiPanel(p, n, n_g, 1, 1, v_lm, nPorts);
            elseif codebookMode == 2
                if n_g == 2
                    W = calcWMatrixMultiPanel(p, n, n_g, 1, 2, v_lm, nPorts);
                else 
                    warning('Invalid n_g for Codebook Mode 2. Returning zero matrix.');
                    W = zeros(nPorts, 1);
                end
            else 
                warning('Invalid Codebook Mode. Returning zero matrix.');
                W = zeros(nPorts, 1);
            end
        
        case 2
            % Rank 2: Two layers using base beam v_lm and shifted beam v_lm_p
            v_lm = computeBeam(l, m, N1, N2, O1, O2, 2);
            v_lm_p = computeBeam(lp, mp, N1, N2, O1, O2, 2);
            if codebookMode == 1
                w_idx1 = calcWMatrixMultiPanel(p, n, n_g, 1, 1, v_lm, nPorts);
                w_idx2 = calcWMatrixMultiPanel(p, n, n_g, 2, 1, v_lm_p, nPorts);
                W = (1/sqrt(2)) * [w_idx1, w_idx2]; % Normalization for 2 layers
            elseif codebookMode == 2
                if n_g == 2
                    w_idx1 = calcWMatrixMultiPanel(p, n, n_g, 1, 2, v_lm, nPorts);
                    w_idx2 = calcWMatrixMultiPanel(p, n, n_g, 2, 2, v_lm_p, nPorts);
                    W = (1/sqrt(2)) * [w_idx1, w_idx2];
                else 
                    warning('n_g must be 2 for Codebook Mode 2. Returning zero matrix.');
                    W = zeros(nPorts, 2);
                end
            else 
                warning('Invalid Codebook Mode. Returning zero matrix.');
                W = zeros(nPorts, 2);
            end

        case 3
            % Rank 3: Three layers using a combination of v_lm and v_lm_p
            v_lm = computeBeam(l, m, N1, N2, O1, O2, 2);
            v_lm_p = computeBeam(lp, mp, N1, N2, O1, O2, 2);
            if codebookMode == 1
                w_idx1 = calcWMatrixMultiPanel(p, n, n_g, 1, 1, v_lm, nPorts);
                w_idx2 = calcWMatrixMultiPanel(p, n, n_g, 1, 1, v_lm_p, nPorts);
                w_idx3 = calcWMatrixMultiPanel(p, n, n_g, 2, 1, v_lm, nPorts);
                W = (1/sqrt(3)) * [w_idx1, w_idx2, w_idx3]; % Normalization for 3 layers
            elseif codebookMode == 2
                if n_g == 2
                    w_idx1 = calcWMatrixMultiPanel(p, n, n_g, 1, 2, v_lm, nPorts);
                    w_idx2 = calcWMatrixMultiPanel(p, n, n_g, 1, 2, v_lm_p, nPorts);
                    w_idx3 = calcWMatrixMultiPanel(p, n, n_g, 2, 2, v_lm, nPorts);
                    W = (1/sqrt(3)) * [w_idx1, w_idx2, w_idx3];
                else 
                    warning('n_g must be 2 for Codebook Mode 2. Returning zero matrix.');
                    W = zeros(nPorts, 3);
                end
            else 
                warning('Invalid Codebook Mode. Returning zero matrix.');
                W = zeros(nPorts, 3);
            end

        case 4
            % Rank 4: Four layers using pairs of v_lm and v_lm_p
            v_lm = computeBeam(l, m, N1, N2, O1, O2, 2);
            v_lm_p = computeBeam(lp, mp, N1, N2, O1, O2, 2);
            if codebookMode == 1
                w_idx1 = calcWMatrixMultiPanel(p, n, n_g, 1, 1, v_lm, nPorts);
                w_idx2 = calcWMatrixMultiPanel(p, n, n_g, 1, 1, v_lm_p, nPorts);
                w_idx3 = calcWMatrixMultiPanel(p, n, n_g, 2, 1, v_lm, nPorts);
                w_idx4 = calcWMatrixMultiPanel(p, n, n_g, 2, 1, v_lm_p, nPorts);
                W = (1/sqrt(4)) * [w_idx1, w_idx2, w_idx3, w_idx4]; % Normalization for 4 layers
            elseif codebookMode == 2
                if n_g == 2
                    w_idx1 = calcWMatrixMultiPanel(p, n, n_g, 1, 2, v_lm, nPorts);
                    w_idx2 = calcWMatrixMultiPanel(p, n, n_g, 1, 2, v_lm_p, nPorts);
                    w_idx3 = calcWMatrixMultiPanel(p, n, n_g, 2, 2, v_lm, nPorts);
                    w_idx4 = calcWMatrixMultiPanel(p, n, n_g, 2, 2, v_lm_p, nPorts);
                    W = (1/sqrt(4)) * [w_idx1, w_idx2, w_idx3, w_idx4];
                else 
                    warning('n_g must be 2 for Codebook Mode 2. Returning zero matrix.');
                    W = zeros(nPorts, 4);
                end
            else 
                warning('Invalid Codebook Mode. Returning zero matrix.');
                W = zeros(nPorts, 4);
            end

        otherwise
            % Handle cases where nLayers is not 1, 2, 3, or 4
            warning('Unsupported number of layers (%d). Returning empty matrix.', nLayers);
            W = [];
    end
end

%% --- HELPER FUNCTIONS ---

function [i11, i12, i13, i14, i2] = computeInputs(nLayers, i1, i2, N2)
    i11 = i1{1};

    if N2 == 1
        i12 = 0;
    else 
        i12 = i1{2};
    end

    if nLayers == 1
        i13 = 0;
    else 
        i13 = i1{3};
    end

    i14 = i1{4};
end

function [l, lp, m, mp, p, n] = getBeamIndices(nLayers, i11, i12, i13, i14, i2, N1, N2, O1, O2)
    % Initialize default values to 0 to prevent "undefined variable" errors
    [l, lp, m, mp, p, n] = deal(0); 

    % Calculate beam offsets k1 and k2 based on 3GPP Table 5.2.2.2.2-2
    [k1, k2] = getK1K2(i13, N1, N2, O1, O2); 

    if nLayers == 1
        % For Rank 1, only the primary beam is used
        l = i11; 
        m = i12; 
        p = i14; 
        n = i2;
        % lp and mp remain 0 as default
    elseif ismember(nLayers, [2, 3, 4])
        % For higher ranks, calculate both base and shifted beams
        l = i11; 
        lp = l + k1; % Horizontal beam shift
        m = i12; 
        mp = m + k2; % Vertical beam shift
        p = i14; 
        n = i2; 
    else
        warning('Unsupported nLayers. Defaulting to 0.');
    end
end

function [k1, k2] = getK1K2(i13, N1, N2, O1, O2)
    % Default offset is zero
    k1 = 0;
    k2 = 0;

    % Mapping logic based on antenna port layout (N1, N2)
    if N1 == 2 && N2 == 1
        if i13 == 0
            k1 = O1; k2 = 0;
        end
        
    elseif N1 == 4 && N2 == 1
        switch i13
            case 0; k1 = O1;   k2 = 0;
            case 1; k1 = 2*O1; k2 = 0;
            case 2; k1 = 3*O1; k2 = 0;
        end
        
    elseif N1 == 8 && N2 == 1
        switch i13
            case 0; k1 = O1;   k2 = 0;
            case 1; k1 = 2*O1; k2 = 0;
            case 2; k1 = 3*O1; k2 = 0;
            case 3; k1 = 4*O1; k2 = 0;
        end
        
    elseif N1 == 2 && N2 == 2
        switch i13
            case 0; k1 = O1; k2 = 0;
            case 1; k1 = 0;  k2 = O2;
            case 2; k1 = O1; k2 = O2;
        end
        
    elseif N1 == 4 && N2 == 2
        switch i13
            case 0; k1 = O1;   k2 = 0;
            case 1; k1 = 0;    k2 = O2;
            case 2; k1 = O1;   k2 = O2;
            case 3; k1 = 2*O1; k2 = 0;
        end
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

function phi_n = computePhiN(n)
    phi_n = exp(1j*pi*n/2);
end

function phi_p = computePhiP(p)
    phi_p = exp(1j*pi*p/4);
end

function a_p = computeAP(p)
    a_p = exp(1j*pi/4)*exp(1j*pi*p/2);
end

function b_n = computeBN(n)
    b_n = exp(-1j*pi/4)*exp(1j*pi*n/2);
end

function W = calcWMatrixMultiPanel(p, n, Ng, idxRank, rank, vLm, nPorts)
    % Power normalization factor based on the total number of CSI-RS ports
    norm_factors = 1/(sqrt(nPorts)); 

    if Ng == 2
        if rank == 1
            % Based on W^{x, 2, 1} formulas
            phi_p1 = computePhiP(p(1)); 
            phi_n  = computePhiN(n); 
            
            if idxRank == 1
                W = norm_factors * [vLm; phi_n*vLm; phi_p1*vLm; phi_n*phi_p1*vLm];
            else
                % W^{2, 2, 1} uses -phi_n
                W = norm_factors * [vLm; -phi_n*vLm; phi_p1*vLm; -phi_n*phi_p1*vLm];
            end
            
        elseif rank == 2
            % Based on W^{x, 2, 2} formulas (utilizing a_p and b_n)
            phi_n0 = computePhiN(n(1)); 
            a_p1 = computeAP(p(1));
            a_p2 = computeAP(p(2));
            b_n1 = computeBN(n(2));
            b_n2 = computeBN(n(3));

            if idxRank == 1
                W = norm_factors * [vLm; phi_n0*vLm; a_p1*b_n1*vLm; a_p2*b_n2*vLm];
            else
                % W^{2, 2, 2} uses negative signs for certain polarization components
                W = norm_factors * [vLm; -phi_n0*vLm; a_p1*b_n1*vLm; -a_p2*b_n2*vLm];
            end
        end

    elseif Ng == 4
        % Based on W^{x, 4, 1} formulas
        phi_n = computePhiN(n); 
        phi_p1 = computePhiP(p(1));
        phi_p2 = computePhiP(p(2));
        phi_p3 = computePhiP(p(3));

        if idxRank == 1
            W = norm_factors * [vLm; ...
                                phi_n*vLm; ...
                                phi_p1*vLm; phi_n*phi_p1*vLm; ...
                                phi_p2*vLm; phi_n*phi_p2*vLm; ...
                                phi_p3*vLm; phi_n*phi_p3*vLm];
        else
            % Alternating signs for the second layer in multi-panel
            W = norm_factors * [vLm; ...
                                -phi_n*vLm; ...
                                phi_p1*vLm; -phi_n*phi_p1*vLm; ...
                                phi_p2*vLm; -phi_n*phi_p2*vLm; ...
                                phi_p3*vLm; -phi_n*phi_p3*vLm];
        end
    end
end

function validateInputs(codebookMode, nLayers, n_g, N1, N2, O1, O2, i11, i12, i13, i14, i2, nPorts)
    validConfig = false;
    switch nPorts
        case 8
            if isequal([n_g, N1, N2], [2, 2, 1]) && isequal([O1, O2], [4, 1]), validConfig = true; end
        case 16
            configs = [2,4,1; 4,2,1; 2,2,2];
            oversampling = [4,1; 4,1; 4,4];
            for k = 1:size(configs, 1)
                if isequal([n_g, N1, N2], configs(k,:)) && isequal([O1, O2], oversampling(k,:)), validConfig = true; break; end
            end
        case 32
            configs = [2,8,1; 4,4,1; 2,4,2; 4,2,2];
            oversampling = [4,1; 4,1; 4,4; 4,4];
            for k = 1:size(configs, 1)
                if isequal([n_g, N1, N2], configs(k,:)) && isequal([O1, O2], oversampling(k,:)), validConfig = true; break; end
            end
    end
    if ~validConfig
        error('Invalid combination of nPorts (%d), Ng (%d), N1 (%d), N2 (%d), O1 (%d), O2 (%d).', ...
            nPorts, n_g, N1, N2, O1, O2);
    end

    % 2. Validate codebookMode and Ng relationship
    if codebookMode == 2 && n_g ~= 2
        error('codebookMode 2 is only supported for Ng = 2 panels.');
    end
    if ~ismember(codebookMode, [1, 2])
        error('codebookMode must be 1 or 2.');
    end

    % 3. Validate nLayers (RI)
    if ~ismember(nLayers, [1, 2, 3, 4])
        error('nLayers (Rank) must be between 1 and 4.');
    end

    % 4. Validate i1,1 and i1,2 ranges
    if i11 < 0 || i11 >= N1*O1
        error('i11 must be in range [0, N1*O1 - 1] = [0, %d].', N1*O1 - 1);
    end
    if i12 < 0 || i12 >= N2*O2
        error('i12 must be in range [0, N2*O2 - 1] = [0, %d].', N2*O2 - 1);
    end

    % 5. Validate i1,3 for Rank 2, 3, 4
    if nLayers > 1
        % For nLayers=2, uses Table 5.2.2.2.1-3. For 3&4, uses Table 5.2.2.2.2-2
        % Check max value of i1,3 based on (N1, N2) from Table 5.2.2.2.2-2
        max_i13 = 0;
        if isequal([N1, N2], [2, 1]), max_i13 = 0;
        elseif isequal([N1, N2], [4, 1]), max_i13 = 2;
        elseif isequal([N1, N2], [8, 1]), max_i13 = 3;
        elseif isequal([N1, N2], [2, 2]), max_i13 = 2;
        elseif isequal([N1, N2], [4, 2]), max_i13 = 3;
        end
        if i13 < 0 || i13 > max_i13
            error('i13 is out of bounds for the current antenna configuration (N1=%d, N2=%d).', N1, N2);
        end
    end

    % 6. Validate i1,4 and i2 based on codebookMode
    if codebookMode == 1
        % i1,4 is a vector of size Ng-1
        if length(i14) ~= (n_g - 1)
            error('For codebookMode 1, i14 must be a vector of size Ng-1 = %d.', n_g - 1);
        end
        if any(i14 < 0 | i14 > 3)
            error('All elements of i14 must be in {0, 1, 2, 3}.');
        end
        % i2 is a single value 0 or 1
        if ~ismember(i2, [0, 1])
            error('For codebookMode 1, i2 must be 0 or 1.');
        end
    else % codebookMode == 2
        % i1,4 is a vector [i141, i142]
        if length(i14) ~= 2
            error('For codebookMode 2, i14 must be a vector [i141, i142].');
        end
        % i2 is a vector [i20, i21, i22]
        if length(i2) ~= 3
            error('For codebookMode 2, i2 must be a vector [i20, i21, i22].');
        end
    end
end