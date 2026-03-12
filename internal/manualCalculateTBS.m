function TBS = manualCalculateTBS(pdsch)
    if pdsch.DMRS.DMRSConfigurationType == 1
        dmrsPatern = [0, 2, 4, 6, 8, 10];
    else
        dmrsPatern = [1, 2, 6, 7];
    end

    % The number of dmrs re in the prb
    dmrsRePerPRB = length(dmrsPatern) * pdsch.DMRS.NumCDMGroupsWithoutData;

    % The number of pdsch re in the prb
    pdschReTotalPerPRB = 12 * pdsch.SymbolAllocation(2);

    % The number of pdsch re available for data in the prb
    pdschRePerPRB = pdschReTotalPerPRB - dmrsRePerPRB;

    % The total Re of PDSCH available for data
    numRE = min(156, pdschRePerPRB) * length(pdsch.PRBSet);

    switch pdsch.Modulation
        case 'QPSK',    Qm = 2;
        case '16QAM',   Qm = 4;
        case '64QAM',   Qm = 6;
        case '256QAM',  Qm = 8;
        case '1024QAM', Qm = 10;
        otherwise,      Qm = 2;
    end

    NInfo = numRE * pdsch.TargetCodeRate * Qm * pdsch.NumLayers;

    if NInfo <= 3824
        n = max(3, floor(log2(NInfo)) - 6);
        NInfoPrime = max(24, (2^n) * floor(NInfo / (2^n)));
        tableTBS = [24, 32, 40, 48, 56, 64, 72, 80, 88, 96, 104, 112, 120, ...
                128, 136, 144, 152, 160, 168, 176, 184, 192, 208, 224, 240, ...
                256, 272, 288, 304, 320, 336, 352, 368, 384, 408, 432, 456, ...
                480, 504, 528, 552, 576, 608, 640, 672, 704, 736, 768, 808, ...
                848, 888, 928, 984, 1032, 1064, 1128, 1160, 1192, 1224, 1256, ...
                1288, 1320, 1352, 1416, 1480, 1544, 1608, 1672, 1736, 1800, ...
                1864, 1928, 2024, 2088, 2152, 2216, 2280, 2408, 2472, 2536, ...
                2600, 2664, 2728, 2792, 2856, 2976, 3104, 3240, 3368, 3496, ...
                3624, 3752, 3824];
        validTBS = tableTBS(tableTBS >= NInfoPrime);

        TBS = validTBS(1);
    else
        n = floor(log2(NInfo - 24)) - 5;

        round_val = floor((NInfo - 24) / (2^n) + 0.5);
        NInfoPrime = max(3840, (2^n) * round_val);

        if pdsch.TargetCodeRate <= 1/4
            C = ceil((NInfoPrime + 24) / 3816);
            TBS = 8 * C * ceil((NInfoPrime + 24) / (8 * C)) - 24;
        else
            if NInfoPrime > 8424
                C = ceil((NInfoPrime + 24) / 8424);
                TBS = 8 * C * ceil((NInfoPrime + 24) / (8 * C)) - 24;
            else
                TBS = 8 * ceil((NInfoPrime + 24) / 8) - 24;
            end
        end
    end
end