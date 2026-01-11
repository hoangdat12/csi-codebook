% ---------------------------------------------------------
% This function use to get Precoding Matrix for each PMI
% UE will report the PMI number and the number of Ports and Layers
% ---------------------------------------------------------
function W = getPrecodingMatrixByPMI(cfg, nLayers, pmi)
    [i1, i2] = getParameters(cfg, nLayers, pmi);

    W = generateTypeISinglePanelPrecoder(cfg, nLayers, i1, i2);
    disp(W);
end

% ---------------------------------------------------------
% This function use to create a parameters for the next function
% ---------------------------------------------------------
function [i1, i2] = getParameters(cfg, nLayers, pmi)
    N1 = cfg.CodebookConfig.N1;
    N2 = cfg.CodebookConfig.N2;
    O1 = cfg.CodebookConfig.O1;
    O2 = cfg.CodebookConfig.O2;
    codebookMode = cfg.CodebookConfig.codebookMode;
    [i11_lookup, i12_lookup, i13_lookup, i2_lookup] = lookupPMITable(N1, N2, O1, O2, nLayers, codebookMode);
   
    pmi_idx = pmi + 1;

    i11 = i11_lookup(pmi_idx);
    i12 = i12_lookup(pmi_idx);
    i13 = i13_lookup(pmi_idx);

    i1 = {i11, i12, i13};
        
    i2  = i2_lookup(pmi_idx);
end