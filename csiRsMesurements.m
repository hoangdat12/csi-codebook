function [MCS, PMI] = csiRsMesurements(carrier, channel, csiConfig, csiReport, pdsch, nLayers)
    % -----------------------------------------------------------------
    % Parameters
    % -----------------------------------------------------------------
    nTxAnts = csiConfig.NumCSIRSPorts;  
    subbandAmplitude = csiReport.SubbandAmplitude;

    % -----------------------------------------------------------------
    % CSI TX
    % -----------------------------------------------------------------
    csirsInd = nrCSIRSIndices(carrier,csiConfig);
    csirsSym = nrCSIRS(carrier,csiConfig);

    txGrid = nrResourceGrid(carrier,nTxAnts);
    txGrid(csirsInd) = csirsSym;

    txWaveform = nrOFDMModulate(carrier, txGrid);

    % -----------------------------------------------------------------
    % Channel
    % -----------------------------------------------------------------
    rxWaveform = channel(txWaveform);
    
    % -----------------------------------------------------------------
    % CSI RX and Mesurement
    % -----------------------------------------------------------------
    rxGrid = nrOFDMDemodulate(carrier,rxWaveform);
    % Reuse the above csi generated
    [H,nVar] = nrChannelEstimate(rxGrid,csirsInd,csirsSym,'CDMLengths',[2 1]);

        
    % -----------------------------------------------------------------
    % Mesurement and create PMI
    % -----------------------------------------------------------------
    % Type II
    % [PMISet,~] = nr5g.internal.nrPMIReport(carrier,csiConfig,csiReport,nLayers,H,nVar);
    % CQISet have difference value, too keep everything simple
    % Temporay use the first one
    [CQISet ,PMISet] = nr5g.internal.nrCQIReport(carrier,csiConfig,csiReport,pdsch.DMRS,nLayers,H,nVar);

    % Format output
    [i11,i12,i13,i14, i21, i22] = ...
        extractPMISet(PMISet, nLayers, csiReport.NumberOfBeams * 2, subbandAmplitude);

    i1 = {i11, i12, i13, i14};
    i2 = {i21, i22};

    % Output
    PMI.i1 = i1;
    PMI.i2 = i2;
    % Choose the wideband CQI
    CQI = CQISet(1);
    % Convert from CQI -> MCS
    mcsSet = nr5g.internal.nrCQITables("table2", CQI);
    MCS = mapCQItoMCS(mcsSet);
end


%% Helper Function
function [i11, i12, i13, i14, i21, i22] = ...
    extractPMISet(PMISet, nLayers, numBeams, subbandAmplitude)

    % Extract i1
    % i1 = [q1 q2 i12 i131 i141 i132 i142 ...]
    % i1 - 1 based index 
    % i22 - 1 based index
    % i21 - 0 based index
    i1 = PMISet.i1;

    % Convert to 0-based index
    i11 = [i1(1) i1(2)] - 1;
    i12 = i1(3) - 1;

    i13 = zeros(1, nLayers);
    i14 = zeros(numBeams, nLayers);

    % The Matlab start index for look up i13 and i14
    startIdx = 4;

    for v = 1:nLayers
        i13(v) = i1(startIdx);
        i14(:, v) = i1(startIdx + 1 : startIdx + numBeams);
        startIdx = startIdx + numBeams + 1;
    end

    % Convert to 0-based index
    i13 = i13 - 1;
    i14 = i14' - 1;

    % Get the first subband 
    i2_sb1 = PMISet.i2(:,:,1);

    % Extract and convert to 0-based index
    if subbandAmplitude
        i21 = i2_sb1(:,1:2:end)';
        i22 = i2_sb1(:,2:2:end)' - 1;
    else
        i21 = i2_sb1';
        i22 = [];
    end
end

function mcsIndex = mapCQItoMCS(cqiParams)
    targetEfficiency = cqiParams(4);
    
    mcsTableFromImage = [
        0   2   120     0.2344;
        1   2   193     0.3770;
        2   2   308     0.6016;
        3   2   449     0.8770;
        4   2   602     1.1758;
        5   4   378     1.4766;
        6   4   434     1.6953;
        7   4   490     1.9141;
        8   4   553     2.1602;
        9   4   616     2.4063;
        10  4   658     2.5703;
        11  6   466     2.7305;
        12  6   517     3.0293;
        13  6   567     3.3223;
        14  6   616     3.6094;
        15  6   666     3.9023;
        16  6   719     4.2129;
        17  6   772     4.5234;
        18  6   822     4.8164;
        19  6   873     5.1152;
        20  8   682.5   5.3320; 
        21  8   711     5.5547;
        22  8   754     5.8906;
        23  8   797     6.2266;
        24  8   841     6.5703;
        25  8   885     6.9141;
        26  8   916.5   7.1602; 
        27  8   948     7.4063;
    ];
    
    diff = mcsTableFromImage(:, 4) - targetEfficiency;
    
    [~, idx] = min(abs(diff));
    
    mcsIndex = mcsTableFromImage(idx, 1) - 3;
end
