function outBits = rateMatching(inBits, E, Rv, modulationType, nLayers, Nref)
    % If LBRM is enabled, Nref will be pass into the parameters list.
    if nargin < 6
        Nref = [];
    end

    % N = Length of bit in a codeword.
    % C = Number of codewords.
    [N, C] = size(inBits); 

    % Standard Lifting Sizes for Base Graph detection.
    ZcVec = [2:16 18:2:32 36:4:64 72:8:128 144:16:256 288:32:384];
    
    % Find the number of column in the LDPC for each codewords.
    if any(abs(N - (ZcVec .* 66)) < 1e-5)
        bgn = 1;
        N_columns = 66;
    else
        bgn = 2;
        N_columns = 50;
    end

    % Find exactly the Zc values.
    Zc = N / N_columns;

    % Calculate Ncb (Circular Buffer Length) 
    % If I_LBRM = 0, Ncb = N. Otherwise Ncb = min(N, Nref).
    if isempty(Nref)
        Ncb = N; 
    else
        Ncb = min(N, Nref); 
    end

    % Determine Modulation Order Qm
    switch modulationType
        case {'pi/2-BPSK', 'BPSK'}, Qm = 1;
        case 'QPSK',                Qm = 2;
        case '16QAM',               Qm = 4;
        case '64QAM',               Qm = 6;
        case '256QAM',              Qm = 8;
        case '1024QAM',             Qm = 10;
        otherwise, error('Unknown modulation type');
    end

    % Find the k0 values for each Rv.
    if bgn == 1
        % BG1 factors: 0, 17/66, 33/66, 56/66
        if Rv == 0, k0_val = 0;
        elseif Rv == 1, k0_val = floor(17 * Ncb / (66 * Zc)) * Zc;
        elseif Rv == 2, k0_val = floor(33 * Ncb / (66 * Zc)) * Zc;
        elseif Rv == 3, k0_val = floor(56 * Ncb / (66 * Zc)) * Zc;
        end
    else
        % BG2 factors: 0, 13/50, 25/50, 43/50
        if Rv == 0, k0_val = 0;
        elseif Rv == 1, k0_val = floor(13 * Ncb / (50 * Zc)) * Zc;
        elseif Rv == 2, k0_val = floor(25 * Ncb / (50 * Zc)) * Zc;
        elseif Rv == 3, k0_val = floor(43 * Ncb / (50 * Zc)) * Zc;
        end
    end

    k0 = k0_val;

    % ---------- Rate Matching logic ------------
    outBits = cell(C, 1);
    NL = nLayers;
    C_prime = C; 
    G = E;       

    for r = 0:C-1
        % --- Determine Er (Output sequence length) 
        % Logic: Distribute G bits evenly. First few blocks get floor, remainder goes to last.
        if r <= (C_prime - mod(G/(NL*Qm), C_prime) - 1)
            Er = NL * Qm * floor(G / (NL * Qm * C_prime));
        else
            Er = NL * Qm * ceil(G / (NL * Qm * C_prime));
        end

        if Er > 0
            % Get input d for this block
            d_block = inBits(:, r+1);
            
            e = zeros(Er, 1); % Sequence e_k
            k = 0;
            j = 0;
            
            % Bit Selection process
            while k < Er
                % Calculate circular index
                % Mathematical index is (k0 + j) mod Ncb. 
                % MATLAB is 1-based, so we add 1 for access.
                circIdx = mod(k0 + j, Ncb); 
                
                % Retrieve bit from buffer d
                % Note: d_block only has N bits. If Ncb < N (LBRM), we only access up to Ncb.
                val = d_block(circIdx + 1);
                
                % Check for <NULL> (Filler bits) 
                % Assuming filler bits are marked as -1
                if val ~= -1 
                    % e_k = d((k0+j) mod Ncb) 
                    e(k + 1) = val; 
                    k = k + 1;      
                end
                
                j = j + 1;          
            end
            
            % Bit Interleaving logic.
            
            f = zeros(Er, 1); % Output sequence f
            
            % Output length E is Er here.
            
            % Er / Qm = the total number is allocated
            for j_idx = 0 : (Er / Qm) - 1       % 
                % Number of bit in each symbols
                for i_idx = 0 : Qm - 1          % 
                    
                    % Calculate indices (0-based)
                    % idx_f = i + jQm
                    idx_f = i_idx + (j_idx * Qm);
                    idx_e = i_idx * (Er / Qm) + j_idx;
                    
                    % Assign (converting to MATLAB 1-based indexing)
                    f(idx_f + 1) = e(idx_e + 1);
                end
            end
            
            % Store result for this code block
            outBits{r+1} = f;
        end
    end
end