function [prbset,symbolset,dmrssymbolset,ldash] = ...
    initializeResources(carrierConfig,pdschConfig)

    symbperslot = carrierConfig.SymbolsPerSlot;

    nPDSCHStart = pdschConfig.SymbolAllocation(1);
    nPDSCHSym = pdschConfig.SymbolAllocation(end);
    symbolset = nPDSCHStart:nPDSCHStart+nPDSCHSym-1;
    symbolset = symbolset(symbolset < symbperslot);
  
end