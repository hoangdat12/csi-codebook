function [i1, i2] = csiRsMesurements(carrier, channel, csiConfig, csiReport, nLayers, channelType)
    % Description
    % This function use to mesurement PMI from CSI RS

    % Example Usage

    % nLayers = 2;                    

    % % Carrier Config
    % carrier = nrCarrierConfig;
    % carrier.NSizeGrid = 52;

    % % Csi Config
    % csiConfig = nrCSIRSConfig;
    % csiConfig.CSIRSType = {'nzp'};
    % % https://www.etsi.org/deliver/etsi_ts/138200_138299/138211/18.06.00_60/ts_138211v180600p.pdf
    % % Bảng 7.4.1.5.3-1.
    % csiConfig.RowNumber = 12;          
    % csiConfig.Density = {'one'};
    % csiConfig.SubcarrierLocations = {[0 2 4 6]};
    % csiConfig.SymbolLocations = {0};
    % csiConfig.CSIRSPeriod = [4 0];

    % % Channel
    % nTxAnts = csiConfig.NumCSIRSPorts;  
    % nRxAnts = nTxAnts;
    % OFDMInfo = nrOFDMInfo(carrier);

    % channel = nrTDLChannel();
    % channel.NumTransmitAntennas = nTxAnts;
    % channel.NumReceiveAntennas = nRxAnts;
    % channel.SampleRate = OFDMInfo.SampleRate;
    % channel.DelayProfile = 'TDL-C';
    % channel.DelaySpread = 300e-9;
    % channel.MaximumDopplerShift = 5;

    % % CSI Report
    % subbandAmplitude = true;
    % csiReport = nrCSIReportConfig;
    % csiReport.CQITable = "table2"; % 256QAM
    % csiReport.CodebookType = "type2";
    % csiReport.PanelDimensions = [1 4 2];
    % csiReport.PMIFormatIndicator = "subband";
    % csiReport.CQIFormatIndicator = "subband";
    % csiReport.SubbandSize = 32;
    % csiReport.SubbandAmplitude = subbandAmplitude;
    % csiReport.NumberOfBeams = 4;
    % csiReport.PhaseAlphabetSize = 8;

    % % Maximum 2 layers
    % csiReport.RIRestriction = [1 1 0 0];

    % % CSI Mesurements
    % [i1, i2] = csiRsMesurements(carrier, channel, csiConfig, csiReport, nLayers);

    % cfg = struct();

    % cfg.CodebookConfig.N1 = 4;
    % cfg.CodebookConfig.N2 = 2;
    % cfg.CodebookConfig.O1 = 4;
    % cfg.CodebookConfig.O2 = 4;

    % cfg.CodebookConfig.NumberOfBeams = 4;     
    % cfg.CodebookConfig.PhaseAlphabetSize = 8; 
    % cfg.CodebookConfig.SubbandAmplitude = subbandAmplitude;
    % cfg.CodebookConfig.numLayers = nLayers;         

    % W = generateTypeIIPrecoder(cfg, i1, i2, true);

    if nargin < 6
        channelType = "FlatFading";
    end        

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
    if channelType == "PropagateAndSync"
            rxWaveform = channelPropagateAndSync( ...
                txWaveform, carrier, channel, csirsInd, csirsSym, 20);
    else
        [rxWaveform, ~] = channelFlatFading(txWaveform, 20, 4);
    end
    
    % -----------------------------------------------------------------
    % CSI RX and Mesurement
    % -----------------------------------------------------------------
    rxGrid = nrOFDMDemodulate(carrier,rxWaveform);
    % Reuse the above csi generated
    [H,nVar] = nrChannelEstimate(rxGrid,csirsInd,csirsSym,'CDMLengths',[2 1]);

        
    % -----------------------------------------------------------------
    % Mesurement and create PMI
    % -----------------------------------------------------------------
    [PMISet,~] = nr5g.internal.nrPMIReport(carrier,csiConfig,csiReport,nLayers,H,nVar);

    % Format output
    [i11,i12,i13,i14, i21, i22] = ...
        extractPMISet(PMISet, nLayers, csiReport.NumberOfBeams * 2, subbandAmplitude);

    i1 = {i11, i12, i13, i14};
    i2 = {i21, i22};
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
