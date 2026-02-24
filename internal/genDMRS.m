function [dmrssymbols, dmrs_values] = genDMRS(carrier, pdsch, enabledR16)
% -----------------------------------------------------------
% GENDMRS: Generates DMRS complex symbols (Type 1 & Type 2)
% -----------------------------------------------------------
% Inputs:
%   carrier    : struct {NSlot, NCellID, SymbolsPerSlot, ...}
%   pdsch      : struct {DMRS, PRBSet, SymbolAllocation, ...}
%   enabledR16 : boolean flag for Rel-16 features
%
% Outputs:
%   dmrssymbols : [1 x N] Indices of symbols containing DMRS (0-based)
%   dmrs_values : [M x 1] Complex QPSK symbols for the DMRS sequence
% -----------------------------------------------------------

    % -----------------------------------------------------------
    % Determine DMRS positions in the time domain.
    % Returns sorted symbol indices (e.g., [2, 11]).
    % -----------------------------------------------------------
    [dmrssymbols, ~] = lookupDMRSTable(carrier, pdsch);
    
    if isempty(dmrssymbols)
        dmrs_values = [];
        return;
    end

    % -----------------------------------------------------------
    % Calculate c_init (scrambling seed) for each identified symbol.
    % c_init changes per OFDM symbol slot and symbol index 'l'.
    % -----------------------------------------------------------
    c_init_list = generateCInit(pdsch.DMRS, carrier, dmrssymbols, enabledR16);

    % -----------------------------------------------------------
    % Determine Frequency Domain Density.
    % + DMRS Type 1: 6 subcarriers/RB (Every other subcarrier).
    % + DMRS Type 2: 4 subcarriers/RB (2 groups of 2 adjacent SCs).
    % -----------------------------------------------------------
    if pdsch.DMRS.DMRSConfigurationType == 2
        N_DMRS_SC = 4;
    else
        N_DMRS_SC = 6; % Default Type 1
    end

    % -----------------------------------------------------------
    % Get Resource Block (RB) allocation.
    % PRBSet usually contains 0-based indices relative to the BWP.
    % -----------------------------------------------------------
    PRBSet = pdsch.PRBSet;
    
    % -----------------------------------------------------------
    % Calculate the absolute RB reference point for Sequence Generation.
    % The DMRS sequence is pseudo-random and anchored to a common reference
    % point (usually Point A or CRB 0) to ensure phase continuity across
    % multiple UEs (MU-MIMO).
    % -----------------------------------------------------------
    numRBs = length(PRBSet);
    startRB_in_BWP = PRBSet(1);
    
    rbrefpoint = 0; 
    
    if strcmpi(pdsch.DMRS.DMRSReferencePoint, 'CRB0')
        rbrefpoint = double(carrier.NStartGrid);
    end
    
    % The absolute RB index in the Common Grid
    absolute_startRB = rbrefpoint + startRB_in_BWP;

    % -----------------------------------------------------------
    % PREALLOCATION: Optimize memory usage
    % -----------------------------------------------------------
    
    % Total subcarriers containing DMRS in one OFDM symbol
    numSubcarriersPerSymbol = N_DMRS_SC * numRBs;
    
    % Total elements = (Number of Symbols) * (Subcarriers per Symbol)
    total_elements = length(dmrssymbols) * numSubcarriersPerSymbol;
    
    % Preallocate output as complex double
    dmrs_values = complex(zeros(total_elements, 1));
    
    for i = 1:length(dmrssymbols)
        % Retrieve pre-calculated c_init for this specific symbol
        c_init = c_init_list(i);
        
        % -----------------------------------------------------------
        % Calculate Sequence Length & Offset
        % The Gold Sequence generator runs theoretically from CRB 0.
        % We must generate bits covering the gap from CRB 0 to our Start RB,
        % then discard the "offset" bits.
        % -----------------------------------------------------------
        
        % 1. Offset Bits: "Virtual" bits from CRB 0 to StartRB.
        %    Each DMRS subcarrier uses 2 bits (QPSK).
        offset_bits = 2 * N_DMRS_SC * absolute_startRB;
        
        % 2. Needed Bits: The actual bits for the allocated bandwidth.
        needed_bits = 2 * N_DMRS_SC * numRBs;
        
        % 3. Total Bits: Sum to feed the generator.
        total_bits_to_gen = offset_bits + needed_bits;
        
        % -----------------------------------------------------------
        % Generate the Gold Sequence (Length-31)
        % -----------------------------------------------------------
        full_seq_bits = GoldSequence(c_init, total_bits_to_gen);
        
        % -----------------------------------------------------------
        % Slice and Format
        % -----------------------------------------------------------
        
        % Discard the offset bits (prefix)
        useful_bits = full_seq_bits(offset_bits + 1 : end);
        
        % -----------------------------------------------------------
        % QPSK Modulation
        % Formula: 1/sqrt(2) * [(1 - 2*b(2i)) + j*(1 - 2*b(2i+1))]
        % Maps: 0 -> +1, 1 -> -1
        % -----------------------------------------------------------
        
        % Reshape to [2 x NumREs]: Row 1 = Real Bits, Row 2 = Imag Bits
        bit_pairs = reshape(useful_bits, 2, []); 
        
        real_part = (1 - 2 * bit_pairs(1, :)) / sqrt(2);
        imag_part = (1 - 2 * bit_pairs(2, :)) / sqrt(2);
        
        % Create complex symbol vector
        complex_symbol_vector = complex(real_part, imag_part).';
        
        % -----------------------------------------------------------
        % Store in Output Array
        % -----------------------------------------------------------
        startIndex = (i - 1) * numSubcarriersPerSymbol + 1;
        endIndex = i * numSubcarriersPerSymbol;
        
        dmrs_values(startIndex:endIndex) = complex_symbol_vector;
    end
end

function c_init = generateCInit(dmrs, carrier, dmrssymbols, enabledR16)
% -----------------------------------------------------------
% GENERATECINIT: Calculates initialization seed for Gold Sequence
% Formula: c_init = (2^17 * (14*ns + l + 1) * (2*N_ID + 1) + 2*N_ID + n_SCID) mod 2^31
% -----------------------------------------------------------

    % Extract Basic Parameters
    symbperslot = carrier.SymbolsPerSlot;
    nslot = mod(double(carrier.NSlot), carrier.SlotsPerFrame);
    
    % -----------------------------------------------------------
    % Determine Scrambling ID (N_ID)
    % Uses either Cell ID or a specific configured list (NIDNSCID)
    % -----------------------------------------------------------
    if isempty(dmrs.NIDNSCID)
        N_ID = carrier.NCellID;
    else
        % Safe Indexing: Ensure we don't exceed the array bounds of NIDNSCID
        idx = min(dmrs.NSCID + 1, length(dmrs.NIDNSCID));
        N_ID = dmrs.NIDNSCID(idx);
    end

    % -----------------------------------------------------------
    % Determine n_SCID & Lambda (CDM Group Parameter)
    % -----------------------------------------------------------
    raw_nSCID = dmrs.NSCID;
    lambda = dmrs.CDMGroups(1); 
    
    % Special handling for Rel-16 w/ Lambda=1
    if enabledR16 && (lambda == 1)
        n_SCID = 1 - raw_nSCID;
    else
        n_SCID = raw_nSCID;
    end

    % -----------------------------------------------------------
    % Calculate c_init for each symbol
    % -----------------------------------------------------------
    c_init = zeros(1, length(dmrssymbols));

    for i = 1:length(dmrssymbols)
        l = dmrssymbols(i); 
        
        % Part A: Time Domain component (Slot + Symbol)
        A = (symbperslot * nslot) + l + 1;
        
        % Part B: ID component
        B = 2 * N_ID + 1;
        
        % Part Lambda: Additional term based on CDM Group
        Term_Lambda = 2^17 * floor(lambda / 2);

        % Part C: ID + n_SCID component
        C = 2 * N_ID + n_SCID;
        
        % Combine: (2^17 * A * B) + Term_Lambda + C
        val = (2^17 * A * B) + Term_Lambda + C;
        
        c_init(i) = mod(val, 2^31);
    end
end

function c = GoldSequence(c_init, N)
% -----------------------------------------------------------
% GOLDSEQUENCE: Generates length-31 Pseudo-Random Sequence
% Standard: 3GPP TS 38.211 Section 5.2.1
% -----------------------------------------------------------

    x1 = zeros(1, 31); 
    x2 = zeros(1, 31);
    x1(1) = 1;

    % -----------------------------------------------------------
    % Initialize x2 with c_init
    % Converted to binary array, LSB first
    % -----------------------------------------------------------
    for i = 1:31
        x2(i) = bitget(c_init, i);
    end

    % -----------------------------------------------------------
    % Define Output Length
    % We generate N + 1600 bits because the first 1600 (Nc) 
    % are discarded to avoid transient states.
    % -----------------------------------------------------------
    L = N + 1600;
    seq = zeros(L,1);

    % -----------------------------------------------------------
    % Sequence Generation Loop
    % Polynomials:
    %   x1: D^31 + D^3 + 1
    %   x2: D^31 + D^3 + D^2 + D + 1
    % -----------------------------------------------------------
    for n = 1:L
        % Output Calculation: c(n) = (x1(n+Nc) + x2(n+Nc)) mod 2
        seq(n) = xor(x1(1), x2(1));

        % Feedback Calculation
        new_x1 = xor(x1(1), x1(4));
        new_x2 = xor(xor(x2(4), x2(3)), xor(x2(2), x2(1)));

        % Shift Registers (Standard MATLAB implementation of LFSR)
        x1 = [x1(2:end), new_x1];
        x2 = [x2(2:end), new_x2];
    end

    % -----------------------------------------------------------
    % Final Output
    % Discard the initialization phase (Nc = 1600)
    % -----------------------------------------------------------
    c = logical(seq(1601:end));
end