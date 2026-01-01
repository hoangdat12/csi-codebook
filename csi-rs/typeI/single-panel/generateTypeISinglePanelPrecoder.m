function W = generateTypeISinglePanelPrecoder(cfg, nLayers, i1, i2)
    N1 = cfg.CodebookConfig.N1;
    N2 = cfg.CodebookConfig.N2;
    O1 = cfg.CodebookConfig.O1;
    O2 = cfg.CodebookConfig.O2;
    nPorts = cfg.CodebookConfig.nPorts;
    codebookMode = cfg.CodebookConfig.codebookMode;

%     validateInputs(nPorts, N1, N2, O1, O2);

    [i11, i12, i13, i2] = computeInputs(i1, i2, N2, nLayers);

    phiSet = [1, 1j, -1, -1j];

    [l, m, lp, mp, lpp, mpp, lppp, mppp, p, n] = getBeamIndices(codebookMode, nPorts, nLayers, i11, i12, i13, i2, N1, N2, O1, O2);

    phi_n = phiSet(n+1);
    theta_p = exp(1j * pi * p / 4);

    switch nLayers
        case 1
            v_lm = computeBeam(l, m, N1, N2, O1, O2, 2); % Standard 2*pi phase
            W = (1/sqrt(nPorts)) * [v_lm; ...
                                    phi_n * v_lm];
            
        case 2
            v_lm   = computeBeam(l, m, N1, N2, O1, O2, 2);
            v_lm_p = computeBeam(lp, mp, N1, N2, O1, O2, 2);
            W = (1/sqrt(2*nPorts)) * [v_lm,       v_lm_p; ...
                                      phi_n*v_lm, -phi_n*v_lm_p];
            
        case 3
            if nPorts < 16
                v_lm   = computeBeam(l, m, N1, N2, O1, O2, 2);
                v_lm_p = computeBeam(lp, mp, N1, N2, O1, O2, 2);
                
                W = (1/sqrt(3*nPorts)) * [v_lm,       v_lm_p,       v_lm; ...
                                          phi_n*v_lm, phi_n*v_lm_p, -phi_n*v_lm];
            else
                v_lm   = computeBeam(l, m, N1/2, N2, O1, O2, 4); 
                
                W = (1/sqrt(3*nPorts)) * [v_lm,                 v_lm,                   v_lm; ...
                                          theta_p*v_lm,         -theta_p*v_lm,          theta_p*v_lm; ...
                                          phi_n*v_lm,           phi_n*v_lm,             -phi_n*v_lm; ...
                                          phi_n*theta_p*v_lm,    -phi_n*theta_p*v_lm,    -phi_n*theta_p*v_lm];
            end

        case 4
            if nPorts < 16
                v_lm   = computeBeam(l, m, N1, N2, O1, O2, 2);
                v_lm_p = computeBeam(lp, mp, N1, N2, O1, O2, 2);

                W = (1/sqrt(4*nPorts)) * [v_lm,       v_lm_p,       v_lm        , v_lm_p; ...
                                          phi_n*v_lm, phi_n*v_lm_p, -phi_n*v_lm,  -phi_n*v_lm];
            else
                v_lm   = computeBeam(l, m, N1/2, N2, O1, O2, 4); 

                W = (1/sqrt(4*nPorts)) * [v_lm,                 v_lm,                   v_lm,                   v_lm; ...
                                          theta_p*v_lm,         -theta_p*v_lm,          theta_p*v_lm,           -theta_p*v_lm; ...
                                          phi_n*v_lm,           phi_n*v_lm,             -phi_n*v_lm,            -phi_n*v_lm; ...
                                          phi_n*theta_p*v_lm,    -phi_n*theta_p*v_lm,   -phi_n*theta_p*v_lm,    phi_n*theta_p*v_lm];
            end
        
        case 5
            v_lm   = computeBeam(l, m, N1, N2, O1, O2, 2);
            v_lm_p = computeBeam(lp, mp, N1, N2, O1, O2, 2);
            v_lm_pp = computeBeam(lpp, mpp, N1, N2, O1, O2, 2);

            W = (1/sqrt(5*nPorts)) * [v_lm,       v_lm,         v_lm_p,         v_lm_p,       v_lm_pp; ...
                                      phi_n*v_lm, -phi_n*v_lm,  v_lm_p,         -v_lm_p,      v_lm_pp];

        case 6
            v_lm   = computeBeam(l, m, N1, N2, O1, O2, 2);
            v_lm_p = computeBeam(lp, mp, N1, N2, O1, O2, 2);
            v_lm_pp = computeBeam(lpp, mpp, N1, N2, O1, O2, 2);

            W = (1/sqrt(6*nPorts)) * [v_lm,       v_lm,         v_lm_p,         v_lm_p,         v_lm_pp,      v_lm_pp; ...
                                      phi_n*v_lm, -phi_n*v_lm,  phi_n*v_lm_p,   -phi_n*v_lm_p,  v_lm_pp,      -v_lm_pp];
        case 7
            v_lm   = computeBeam(l, m, N1, N2, O1, O2, 2);
            v_lm_p = computeBeam(lp, mp, N1, N2, O1, O2, 2);
            v_lm_pp = computeBeam(lpp, mpp, N1, N2, O1, O2, 2);
            v_lm_ppp = computeBeam(lppp, mppp, N1, N2, O1, O2, 2);

            W = (1/sqrt(7*nPorts)) * [v_lm,       v_lm,         v_lm_p,         v_lm_pp,        v_lm_pp,      v_lm_ppp,     v_lm_ppp; ...
                                      phi_n*v_lm, -phi_n*v_lm,  phi_n*v_lm_p,   v_lm_pp,        -v_lm_pp,     v_lm_ppp,     -v_lm_ppp];
        case 8
            v_lm   = computeBeam(l, m, N1, N2, O1, O2, 2);
            v_lm_p = computeBeam(lp, mp, N1, N2, O1, O2, 2);
            v_lm_pp = computeBeam(lpp, mpp, N1, N2, O1, O2, 2);
            v_lm_ppp = computeBeam(lppp, mppp, N1, N2, O1, O2, 2);

            W = (1/sqrt(8*nPorts)) * [v_lm,       v_lm,         v_lm_p,         v_lm_pp,        v_lm_pp,      v_lm_ppp,     v_lm_ppp; ...
                                      phi_n*v_lm, -phi_n*v_lm,  phi_n*v_lm_p,   v_lm_pp,        -v_lm_pp,     v_lm_ppp,     -v_lm_ppp];
    end
end

%% --- HELPER FUNCTION ---

% function validateInputs(NPorts, N1, N2, O1, O2)
%     cfg = getValidCSIConfig();
% 
%     isValid = false;
% 
%     for k = 1:length(cfg)
%         if cfg(k).NPorts == NPorts && ...
%         cfg(k).N1 == N1 && cfg(k).N2 == N2 && ...
%         cfg(k).O1 == O1 && cfg(k).O2 == O2
%             isValid = true;
%             break;
%         end
%     end
% 
%     if ~isValid
%         error(['Invalid CSI configuration!\n', ...
%             'NPorts = %d, (N1,N2) = (%d,%d), (O1,O2) = (%d,%d)\n', ...
%             'Check 3GPP TS 38.211 Type-I codebook.'], ...
%             NPorts, N1, N2, O1, O2);
%     end
% end

function cfg = getValidCSIConfig()
    cfg = struct( ...
        'NPorts', { ...
            4, 8, 12, 12, 16, 16, ...
            24, 24, 24, ...
            32, 32, 32 }, ...
        'N1', { ...
            2, 2, 3, 6, 4, 8, ...
            4, 6, 12, ...
            4, 8, 16 }, ...
        'N2', { ...
            1, 2, 2, 1, 2, 1, ...
            3, 2, 1, ...
            4, 2, 1 }, ...
        'O1', { ...
            4, 4, 4, 4, 4, 4, ...
            4, 4, 4, ...
            4, 4, 4 }, ...
        'O2', { ...
            1, 4, 4, 1, 4, 1, ...
            4, 4, 1, ...
            4, 4, 1 } ...
    );
end

function [i11, i12, i13, i2] = computeInputs(i1, i2, N2, nLayers) 
    i11 = i1{1};
    i2 = i2;
    if N2 == 1
        i12 = 0;
    else
        i12 = i1{2};
    end

    if nLayers == 2 || nLayers == 3 || nLayers == 4
        i13 = i1{3};
    else
        i13 = 0;
    end
end

function [l, m, lp, mp, lpp, mpp, lppp, mppp, p, n] = getBeamIndices(codebookMode, nPorts, nLayers, i11, i12, i13, i2, N1, N2, O1, O2)
    [l, m, lp, mp, lpp, mpp, lppp, mppp, p] = deal(0);
    
    % --- Table 5.2.2.2.1-5: Supported configurations of (N1,N2) and (O1,O2) ---
    if nLayers == 1
        if codebookMode == 1
            l = i11; m = i12; n = i2;
        else % codebookMode == 2
            if N2 == 1
                n = mod(i2, 4);
                offset_l = floor(i2 / 4);
                l = 2 * i11 + offset_l;
                m = 0;
            else 
                % Case N2 > 1 
                offset_l = [0, 1, 0, 1]; 
                offset_m = [0, 0, 1, 1];
                group_idx = floor(i2 / 4) + 1;
                l = 2 * i11 + offset_l(group_idx);
                m = 2 * i12 + offset_m(group_idx);
                n = mod(i2, 4);
            end
        end

    % --- Table 5.2.2.2.1-6: Codebook for 2-layer CSI reporting ---
    elseif nLayers == 2
        [k1, k2] = getK1K2(nLayers, i13, N1, N2, O1, O2);

        if codebookMode == 1
            l = i11; m = i12; n = i2;
            lp = l + k1; mp = m + k2;

        elseif codebookMode == 2 
            if N2 == 1  
                n = mod(i2,2);
                offset_l = floor(i2 / 2);
                l = 2 * i11 + offset_l;
                lp = l + k1; % l' = l + k1
                m = 0;
                mp = 0;
            else % N2 > 1 
                n = mod(i2,2);
                offset_l = [0, 1, 0, 1];
                offset_m = [0, 0, 1, 1];
                group_idx = floor(i2 / 2) + 1;
                l  = 2 * i11 + offset_l(group_idx);
                m  = 2 * i12 + offset_m(group_idx);
                lp = l + k1;
                mp = m + k2;
            end
        end

    % --- Table 5.2.2.2.1-7: 3 Layers && Table 5.2.2.2.1-8: 4 Layers ---
    elseif (nLayers == 3) || (nLayers == 4)
        if nPorts < 16
            [k1, k2] = getK1K2(nLayers, i13, N1, N2, O1, O2);
            l = i11; m = i12; n = i2;
            lp = l + k1; mp = m + k2;
        else 
            l = i11; m = i12; p = i13; n = i2;
        end

    % --- Table 5.2.2.2.1-9: 5 Layers && Table 5.2.2.2.1-10: 6 Layers ---
    elseif nLayers == 5 || nLayers == 6
        if N2 > 1 
            l = i11; lp = i11 + O1; lpp = i11 + O1; 
            m = i12; mp = i12; mpp = i12 + O2;
            n = i2;
        elseif N2 == 1 && N1 > 2
            l = i11; lp = i11 + O1; lpp = i11 + 2*O1; 
            m = 0; mp = 0; mpp = 0;
            n = i2;
        else
            error('Invalid Parameters for Rank 5/6');
        end
    
    % --- Table 5.2.2.2.1-11: 7 Layers && Table 5.2.2.2.1-12: 8 Layers ---
    elseif nLayers == 7 || nLayers == 8
        if N2 == 1 % (image_7d3973.png)
            l = i11; lp = i11 + O1; lpp = i11 + 2*O1; lppp = i11 + 3*O1;
            m = 0;   mp = 0;        mpp = 0;          mppp = 0;
        else % N2 > 1
            l = i11; lp = i11 + O1; lpp = i11;        lppp = i11 + O1;
            m = i12; mp = i12;      mpp = i12 + O2;   mppp = i12 + O2;
        end
        n = i2;
    end   
end

function [k1, k2] = getK1K2(layers, i13, N1, N2, O1, O2)
    k1 = NaN; 
    k2 = NaN;

    if layers == 2
        % --- Bảng 5.2.2.2.1-3: 2-layer CSI reporting ---
        if (N1 > N2) && (N2 > 1)
            switch i13
                case 0, k1 = 0;    k2 = 0;
                case 1, k1 = O1;   k2 = 0;
                case 2, k1 = 0;    k2 = O2;
                case 3, k1 = 2*O1; k2 = 0;
            end
        elseif (N1 == N2) && (N1 > 1)
            switch i13
                case 0, k1 = 0;    k2 = 0;
                case 1, k1 = O1;   k2 = 0;
                case 2, k1 = 0;    k2 = O2;
                case 3, k1 = O1;   k2 = O2;
            end
        elseif (N1 == 2) && (N2 == 1)
            switch i13
                case 0, k1 = 0;    k2 = 0;
                case 1, k1 = O1;   k2 = 0;
            end
        elseif (N1 > 2) && (N2 == 1)
            switch i13
                case 0, k1 = 0;    k2 = 0;
                case 1, k1 = O1;   k2 = 0;
                case 2, k1 = 2*O1; k2 = 0;
                case 3, k1 = 3*O1; k2 = 0;
            end
        end

    elseif layers == 3 || layers == 4
        % --- Bảng 5.2.2.2.1-4: 3-layer and 4-layer CSI reporting ---
        if (N1 == 2) && (N2 == 1)
            if i13 == 0, k1 = O1; k2 = 0; end
            
        elseif (N1 == 4) && (N2 == 1)
            switch i13
                case 0, k1 = O1;   k2 = 0;
                case 1, k1 = 2*O1; k2 = 0;
                case 2, k1 = 3*O1; k2 = 0;
            end
            
        elseif (N1 == 6) && (N2 == 1)
            switch i13
                case 0, k1 = O1;   k2 = 0;
                case 1, k1 = 2*O1; k2 = 0;
                case 2, k1 = 3*O1; k2 = 0;
                case 3, k1 = 4*O1; k2 = 0;
            end
            
        elseif (N1 == 2) && (N2 == 2)
            switch i13
                case 0, k1 = O1;   k2 = 0;
                case 1, k1 = 0;    k2 = O2;
                case 2, k1 = O1;   k2 = O2;
            end
            
        elseif (N1 == 3) && (N2 == 2)
            switch i13
                case 0, k1 = O1;   k2 = 0;
                case 1, k1 = 0;    k2 = O2;
                case 2, k1 = O1;   k2 = O2;
                case 3, k1 = 2*O1; k2 = 0;
            end
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
end
