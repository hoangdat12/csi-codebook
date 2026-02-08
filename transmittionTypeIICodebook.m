clear; clc; close all;

setupPath();

% -----------------------------------------------------------------
% Descriptions - How this repo works
% -----------------------------------------------------------------

% This function use the Configuration Parameters below as inputs
% The Example will first create randomly channel for each UE,
%   it's randomly so there are some problems that the code currently
%   can't control, especially when using AWGN or Rayleigh channel
%   ber can be raised higher than Ideal (0.01 - 0.1).
% The Example also use the Basic Retransmission mechanism.
%   If the BER > THREAHOLD, the MCS will reduce by 5 times until 
%   BER < THREAHOLD. If exceed 10 times, it will drop the message.


% -----------------------------------------------------------------
% Configuration Parameters
% -----------------------------------------------------------------
nLayers = 2;
SNR_dB = 20;
NumUEs = 10;
% The value in the range = {8, 16, 32}, because of the related RowNumber.
nTxAnts = 8;                
nRxAnts = 4;                 
sampleRate = 61440000;

% Channel for test
% AWGN || Ideal || TDL
% With Ideal channel, we can't choose the PMI orthogonal 
% Because of all channel use the same PMI
channelType = "TDL";

% Threadhold for identify PMI Pair
if nLayers == 2
    THREAD_HOLD = 1e-15;
elseif nLayers == 3
    THREAD_HOLD = 1e-2;
else
    THREAD_HOLD = 1e-2;
end

BER_THREAD_HOLD = 10e-9;

% Csi Config
csiConfig = nrCSIRSConfig;
csiConfig.CSIRSType = {'nzp'};
% https://www.etsi.org/deliver/etsi_ts/138200_138299/138211/18.06.00_60/ts_138211v180600p.pdf
% Bảng 7.4.1.5.3-1.
% 6 -> 8 Ports
% 11 -> 16 Ports
% 16 -> 32 Ports

if nTxAnts == 8
    rowNumber = 6;
    csiReportAntenna = [1 4 1];
    csiReportSymbolLocations = {0};
elseif nTxAnts == 16
    rowNumber = 11;
    csiReportAntenna = [1 4 2];
    csiReportSymbolLocations = {0};
else 
    rowNumber = 17;
    csiReportAntenna = [1 4 4];
    csiReportSymbolLocations = {[2 3]};
end

csiConfig.RowNumber = rowNumber;           
csiConfig.Density = {'one'};
csiConfig.SubcarrierLocations = {[0 2 4 6]};
csiConfig.SymbolLocations = csiReportSymbolLocations;
csiConfig.CSIRSPeriod = [4 0];
csiConfig.NumRB = 273;
csiConfig.RBOffset = 0;

% CSI Report Config (Type II)
subbandAmplitude = true;
csiReport = nrCSIReportConfig;
% Table 2 support 256QAM
csiReport.CQITable = "table2"; 
csiReport.CodebookType = "type2";
% [Ng N1 N2]
csiReport.PanelDimensions = csiReportAntenna; 
% Report PMI for each subband
csiReport.PMIFormatIndicator = "subband";
% Report CQI for every subband
csiReport.CQIFormatIndicator = "subband";
csiReport.SubbandSize = 32;
csiReport.SubbandAmplitude = subbandAmplitude;
csiReport.NumberOfBeams = 2;
csiReport.PhaseAlphabetSize = 4;
csiReport.RIRestriction = [1 1 0 0]; 

% -----------------------------------------------------------------
% Carrier Configuration
% -----------------------------------------------------------------
carrier = nrCarrierConfig;
carrier.SubcarrierSpacing = 15;
% With 273 RB, we need scs 30 
carrier.NSizeGrid = 273;

% -----------------------------------------------------------------
% TX
% -----------------------------------------------------------------

% -----------------------------------------------------------------
% Find the orthogonal PMI
% -----------------------------------------------------------------
% Because of nrCQIReport function just only use 
% DMRSLength, DMRSAdditionalPosition and DMRSEnhancedR18 from PDSCH DM-RS configuration
% So the pdsch for both use in the aspect of prepareData function
pdsch = customPDSCHConfig;
pdsch.DMRS.DMRSConfigurationType = 1;
pdsch.DMRS.DMRSAdditionalPosition = 1;
pdsch.NumLayers = nLayers;

% 273 PRB
% The PDSCH channel occupies the entire bandwidth
pdsch.PRBSet = 0:272;

% -----------------------------------------------------------------
% Preparation
% -----------------------------------------------------------------
[all_W, channelList, MCS_List] = prepareData(...
        NumUEs, carrier, csiConfig, csiReport, pdsch, sampleRate,...
        nRxAnts, SNR_dB, nLayers, channelType ...
    );

% -----------------------------------------------------------------
% Scheduling
% -----------------------------------------------------------------
schedulingList = scheduling(all_W, channelList, THREAD_HOLD);
pairedUEs = schedulingList.pair;
unPairedUEs = schedulingList.unPair;

% -----------------------------------------------------------------
% Transmit
% -----------------------------------------------------------------

% -----------------------------------------------------------------
% MU MIMO
% -----------------------------------------------------------------
for idx = 1:length(pairedUEs)
    transmittUEPair = pairedUEs(idx);

    % UE1
    idx1 = transmittUEPair.UE1.ueIdx;
    MCS1 = MCS_List{idx1};
    W1   = transmittUEPair.UE1.W;
    H1   = transmittUEPair.UE1.channel;

    % UE 2
    idx2 = transmittUEPair.UE2.ueIdx;
    MCS2 = MCS_List{idx2};
    W2   = transmittUEPair.UE2.W;
    H2   = transmittUEPair.UE2.channel;

    UE1Infor = struct('id', idx1, 'W', W1, 'MCS', MCS1, 'channel', H1);
    UE2Infor = struct('id', idx2, 'W', W2, 'MCS', MCS2, 'channel', H2);

    [BER1, BER2] = muMimo(carrier, pdsch, UE1Infor, UE2Infor, SNR_dB);

    fprintf('MU-MIMO Pair #%d:\n', idx);
    evaluateBERandRetransmission( ...
        idx1, MCS1, BER1, BER_THREAD_HOLD, ...
        carrier, pdsch, UE1Infor, SNR_dB);

    evaluateBERandRetransmission( ...
        idx2, MCS2, BER2, BER_THREAD_HOLD, ...
        carrier, pdsch, UE2Infor, SNR_dB);

    fprintf('\n');
end

% -----------------------------------------------------------------
% SU MIMO
% -----------------------------------------------------------------
disp('SU-MIMO UE');

for idx = 1:length(unPairedUEs)
    transmittUEPair = unPairedUEs(idx);

    idx1 = transmittUEPair.UE1.ueIdx;
    MCS1 = MCS_List{idx1};
    W1   = transmittUEPair.UE1.W;
    H1   = transmittUEPair.UE1.channel;

    UEInfor = struct('id', idx1, 'W', W1, 'MCS', MCS1, 'channel', H1);

    BER = suMimo(carrier, pdsch, UEInfor, SNR_dB);

    evaluateBERandRetransmission( ...
        idx1, MCS1, BER, BER_THREAD_HOLD, ...
        carrier, pdsch, UEInfor, SNR_dB);
end

% -----------------------------------------------------------------
% HELPER FUNCTION
% -----------------------------------------------------------------

% -----------------------------------------------------------------
% This function use to find UE have PMI that orthogonal with each others 
% It return:
%   - all_W: The W precoding matrix for each UE
%   - channelList: The channel for each UE
%   - MCS_List: MCS select after evaluate the CQI Report
% -----------------------------------------------------------------
function [...
    all_W, channelList, MCS_List] = ...
prepareData(...
        NumUEs, carrier, csiConfig, csiReport, pdsch, sampleRate,...
        nRxAnts, SNR_dB, nLayers, channelType...
)

    % Initial channel list
    channelList = cell(1, NumUEs);

    % Initial W
    all_W = cell(1, NumUEs);
    MCS_List = cell(1, NumUEs);

    % Codebook Config - The same for all UE
    cfg = struct();
    cfg.CodebookConfig.N1 = csiReport.PanelDimensions(2); 
    cfg.CodebookConfig.N2 = csiReport.PanelDimensions(3);
    cfg.CodebookConfig.O1 = 4;
    cfg.CodebookConfig.O2 = 1;
    cfg.CodebookConfig.NumberOfBeams = csiReport.PanelDimensions(1) * csiReport.NumberOfBeams;      
    cfg.CodebookConfig.PhaseAlphabetSize = csiReport.PhaseAlphabetSize; 
    cfg.CodebookConfig.SubbandAmplitude = csiReport.SubbandAmplitude;
    cfg.CodebookConfig.numLayers = nLayers;          

    % Starting calculate the csi
    for ueIdx = 1:NumUEs
        channel = getChannel(channelType, SNR_dB, nRxAnts, ueIdx, sampleRate); 

        channelList{ueIdx} = channel;
        
        % CSI Mesurement
        [MCS, PMI] = csiRsMesurements(carrier, channel, csiConfig, csiReport, pdsch, nLayers);
        
        % Generate Precoding matrix with corresponding PMI Report
        W = generateTypeIIPrecoder(cfg, PMI.i1, PMI.i2, true);
        MCS_List{ueIdx} = MCS;
        
        all_W{ueIdx} = W;
    end
end

% -----------------------------------------------------------------
% This function use to Evaluate the BER and perform Retransmission
% It return:
%   - success: TRUE | FALSE
% -----------------------------------------------------------------
function success = evaluateBERandRetransmission( ...
    ueID, MCS, BER, BER_THRESHOLD, ... 
    carrier, pdsch, UEInfor, SNR_dB ...
)

    % The number retransmission time
    % If this parameter is exceeded, then return FALSE 
    MAX_RETX = 10;

    % Starting count index
    retxCnt  = 0;
    
    % Evaluate if BER valid, return TRUE
    if BER <= BER_THRESHOLD
        fprintf('  -> UE ID %d (MCS %d) - SUCCESS (BER: %.3e)\n', ueID, MCS, BER);
        success = true;
        return;
    end
    
    % -----------------------------------------------------------------
    % RETRANSMISSION MECHANISM
    % -----------------------------------------------------------------
    fprintf('  -> UE ID %d (MCS %d) - FAILED (BER %.3e > TH %.3e). Starting Retransmission...\n', ...
            ueID, MCS, BER, BER_THRESHOLD);

    success = false; 
    
    while BER > BER_THRESHOLD && retxCnt < MAX_RETX
        retxCnt = retxCnt + 1;
        [BER, UEInfor] = suMimo(carrier, pdsch, UEInfor, SNR_dB, true); 

        fprintf('     Retry #%d: BER = %.3e\n', retxCnt, BER);

        if BER <= BER_THRESHOLD
            fprintf('  -> UE ID %d : RECOVERED after %d retransmissions (BER %.3e)\n', ...
                    ueID, retxCnt, BER);
            success = true;
            return;
        end
    end

    fprintf('  -> UE ID %d : DROP PACKET - Retransmission failed after %d attempts (Final BER: %.3e)\n', ...
            ueID, MAX_RETX, BER);
end