function [throughput_UE_Mbps, throughput_Cell_Mbps] = calculateThroughput(pdsch, SCS, K)
    % Compute TBS (bits/slot) per 3GPP TS 38.214
    TBS = manualCalculateTBS(pdsch);

    % Number of slots per second based on numerology (mu):
    %   mu=0 -> 15 kHz  -> 1000 slots/s
    %   mu=1 -> 30 kHz  -> 2000 slots/s
    %   mu=2 -> 60 kHz  -> 4000 slots/s
    slots_per_second = 1000 * (2^SCS);

    % Symbol efficiency: accounts for PDSCH not occupying all 14 symbols/slot
    numPdschSymbols  = pdsch.SymbolAllocation(2);
    symbolEfficiency = numPdschSymbols / 14;

    % Single-UE throughput (Mbps)
    throughput_UE_Mbps = TBS * slots_per_second * symbolEfficiency * 1e-6;

    % Cell throughput for K UEs multiplexed via MU-MIMO (Mbps)
    throughput_Cell_Mbps = K * throughput_UE_Mbps;
end

function TBS = manualCalculateTBS(pdsch)
    % -------------------------------------------------------------------------
    % Step 1: DMRS REs occupied per PRB per OFDM symbol
    % -------------------------------------------------------------------------
    if pdsch.DMRS.DMRSConfigurationType == 1
        rePerSymbolPerCDM = 6;  % Type 1: 6 REs per CDM group per symbol
    else
        rePerSymbolPerCDM = 4;  % Type 2: 4 REs per CDM group per symbol
    end
    rePerSymbol = rePerSymbolPerCDM * pdsch.DMRS.NumCDMGroupsWithoutData;

    % -------------------------------------------------------------------------
    % Step 2: Total number of OFDM symbols carrying DMRS in one slot
    %   = DMRSLength x (1 front-loaded cluster + additional clusters)
    % -------------------------------------------------------------------------
    numDmrsClusters = 1 + pdsch.DMRS.DMRSAdditionalPosition;
    numDmrsSymbols  = pdsch.DMRS.DMRSLength * numDmrsClusters;

    % -------------------------------------------------------------------------
    % Step 3: Available data REs per PRB (N'_RE)
    % -------------------------------------------------------------------------
    dmrsRePerPRB       = rePerSymbol * numDmrsSymbols;
    pdschReTotalPerPRB = 12 * pdsch.SymbolAllocation(2);  % typically 14*12=168
    pdschRePerPRB      = pdschReTotalPerPRB - dmrsRePerPRB;

    % Cap at 156 REs/PRB per 3GPP TS 38.214 Section 5.1.3.2
    numRE = min(156, pdschRePerPRB) * length(pdsch.PRBSet);

    % Modulation order Qm
    switch pdsch.Modulation
        case 'QPSK',    Qm = 2;
        case '16QAM',   Qm = 4;
        case '64QAM',   Qm = 6;
        case '256QAM',  Qm = 8;
        case '1024QAM', Qm = 10;
        otherwise,      Qm = 2;
    end

    % Intermediate information bit count
    NInfo = numRE * pdsch.TargetCodeRate * Qm * pdsch.NumLayers;

    % -------------------------------------------------------------------------
    % Step 4: TBS lookup / calculation per 3GPP TS 38.214 Table 5.1.3.2-1/2
    % -------------------------------------------------------------------------
    if NInfo <= 3824
        % Small TBS: quantize and look up in standardized table
        n          = max(3, floor(log2(NInfo)) - 6);
        NInfoPrime = max(24, (2^n) * floor(NInfo / (2^n)));
        tableTBS   = [24, 32, 40, 48, 56, 64, 72, 80, 88, 96, 104, 112, 120, ...
                128, 136, 144, 152, 160, 168, 176, 184, 192, 208, 224, 240, ...
                256, 272, 288, 304, 320, 336, 352, 368, 384, 408, 432, 456, ...
                480, 504, 528, 552, 576, 608, 640, 672, 704, 736, 768, 808, ...
                848, 888, 928, 984, 1032, 1064, 1128, 1160, 1192, 1224, 1256, ...
                1288, 1320, 1352, 1416, 1480, 1544, 1608, 1672, 1736, 1800, ...
                1864, 1928, 2024, 2088, 2152, 2216, 2280, 2408, 2472, 2536, ...
                2600, 2664, 2728, 2792, 2856, 2976, 3104, 3240, 3368, 3496, ...
                3624, 3752, 3824];
        validTBS = tableTBS(tableTBS >= NInfoPrime);
        TBS      = validTBS(1);
    else
        % Large TBS: compute via LDPC block size formula
        n          = floor(log2(NInfo - 24)) - 5;
        round_val  = floor((NInfo - 24) / (2^n) + 0.5);
        NInfoPrime = max(3840, (2^n) * round_val);

        if pdsch.TargetCodeRate <= 1/4
            % Low code rate: segment into smaller LDPC blocks (max 3816 bits)
            C   = ceil((NInfoPrime + 24) / 3816);
            TBS = 8 * C * ceil((NInfoPrime + 24) / (8 * C)) - 24;
        else
            if NInfoPrime > 8424
                % High code rate, large payload: segment into blocks of 8424 bits
                C   = ceil((NInfoPrime + 24) / 8424);
                TBS = 8 * C * ceil((NInfoPrime + 24) / (8 * C)) - 24;
            else
                % High code rate, single block
                TBS = 8 * ceil((NInfoPrime + 24) / 8) - 24;
            end
        end
    end
end