function rxBits = rxPDSCHDecode(carrier, pdsch, rxWaveform, txWaveform, TBS)
    pdschInd = nrPDSCHIndices(carrier, pdsch);
    refGrid = nrResourceGrid(carrier, pdsch.NumLayers);

    dmrsSym = nrPDSCHDMRS(carrier, pdsch);
    dmrsInd = nrPDSCHDMRSIndices(carrier, pdsch);

    refGrid(dmrsInd) = dmrsSym;

    offset = nrTimingEstimate(carrier, rxWaveform, refGrid);

    rxWaveformSync = rxWaveform(1+offset:end, :);

    samplesNeeded = length(txWaveform); 

    if size(rxWaveformSync, 1) < samplesNeeded
        padding = samplesNeeded - size(rxWaveformSync, 1);
        rxWaveformSync = [rxWaveformSync; zeros(padding, size(rxWaveformSync, 2))];
    end

    rxGrid = nrOFDMDemodulate(carrier, rxWaveformSync);
    rxGrid = rxGrid(1:carrier.NSizeGrid*12, 1:carrier.SymbolsPerSlot, :);

    [Hest, nVar] = nrChannelEstimate(carrier, rxGrid, dmrsInd, dmrsSym, ...
        'CDMLengths', pdsch.DMRS.CDMLengths, ... 
        'AveragingWindow', [1 1]);

    [pdschRx, pdschHest] = nrExtractResources(pdschInd, rxGrid, Hest);
    eqSymbols = nrEqualizeMMSE(pdschRx, pdschHest, nVar);

    dlschLLRs = nrPDSCHDecode(carrier, pdsch, eqSymbols, nVar);

    decDL = nrDLSCHDecoder; 
    decDL.TransportBlockLength = TBS; 
    decDL.TargetCodeRate = pdsch.TargetCodeRate;
    decDL.LDPCDecodingAlgorithm = 'Normalized min-sum';
    decDL.MaximumLDPCIterationCount = 6;

    rv = 0; 
    modStr = char(pdsch.Modulation); 

    rxBits = decDL(dlschLLRs, modStr, pdsch.NumLayers, rv);
end