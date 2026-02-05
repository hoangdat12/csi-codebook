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
NumUEs = 40;
% The value in the range = {8, 16, 32}, because of the related RowNumber.
nTxAnts = 8;                
nRxAnts = 4;                 
sampleRate = 61440000;

% Channel for test
% Rayleigh || AWGN || Ideal || CDL
% With Ideal channel, we can't choose the PMI orthogonal 
% Because of all channel use the same PMI
channelType = "CDL";

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
    cdlChannelAntenna = [4 1 2 1 1];
    csiReportSymbolLocations = {0};
elseif nTxAnts == 16
    rowNumber = 11;
    csiReportAntenna = [1 4 2];
    cdlChannelAntenna = [4 2 2 1 1];
    csiReportSymbolLocations = {0};
else 
    rowNumber = 17;
    csiReportAntenna = [1 4 4];
    cdlChannelAntenna = [4 4 2 1 1];
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
        nRxAnts, SNR_dB, nLayers, channelType, cdlChannelAntenna ...
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

    fprintf('\n');
end

% -----------------------------------------------------------------
% SU MIMO
% -----------------------------------------------------------------
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
        nRxAnts, SNR_dB, nLayers, channelType, cdlChannelAntenna...
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
        channel = getChannel(channelType, SNR_dB, nRxAnts, ueIdx, cdlChannelAntenna, sampleRate); 

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
% This function use to get the channel for TEST
% It return:
%   - channel: AWGN | Rayleigh | Ideal channel.
% -----------------------------------------------------------------
function channel = getChannel(channelType, SNR_dB, nRxAnts, ueIdx, cdlChannelAntenna, sampleRate) 
    switch channelType
        case 'AWGN'
            channel = AWGNChannel('SNRdB', SNR_dB, 'NumRxAnts', nRxAnts);
            
        case 'Rayleigh'
            channel = RayleighChannel('SNRdB', SNR_dB, 'NumRxAnts', nRxAnts);
            
        case 'Ideal'
            channel = IdealChannel('SNRdB', SNR_dB, 'NumRxAnts', nRxAnts);

        case 'CDL'
            % cdlChannel = nrCDLChannel;
            % cdlChannel.DelayProfile = 'CDL-C';
            % % Format [M, N, P, Mg, Ng] 
            % %   M: The number of antenna in the vertical = N1
            % %   N: The number of antenna in the horizontal = N2
            % %   P: Polarization
            % %   Mg: The number of panel row
            % %   Ng: The number of panel column
            % cdlChannel.TransmitAntennaArray.Size = cdlChannelAntenna;
            % cdlChannel.ReceiveAntennaArray.Size = [2, 1, 2, 1, 1];   
            % cdlChannel.Seed = ueIdx; 

            % --- BƯỚC 1: Tạo kênh tham chiếu & ÁP DỤNG DELAY SPREAD NGAY TẠI ĐÂY ---
            refChan = nrCDLChannel;
            refChan.DelayProfile = 'CDL-C';
            refChan.DelaySpread = 300e-9; % [Quan trọng] Co giãn thời gian trễ chuẩn ở đây
            
            % --- BƯỚC 2: Tính góc xoay ngẫu nhiên ---
            rng(ueIdx); 
            azimuthOffset = 360 * rand() - 180; 
            
            % --- BƯỚC 3: Tạo kênh Custom ---
            channelObj = nrCDLChannel;
            channelObj.DelayProfile = 'Custom'; 
            
            % Gán Delay và Gain (Lấy từ refChan đã được scale sẵn)
            channelObj.PathDelays = refChan.PathDelays;       % Giá trị giây thực tế
            channelObj.AveragePathGains = refChan.AveragePathGains;
            
            % Gán các góc chuẩn
            channelObj.AnglesAoA = refChan.AnglesAoA;
            channelObj.AnglesZoD = refChan.AnglesZoD;
            channelObj.AnglesZoA = refChan.AnglesZoA;
            
            % Chỉ gán HasLOSCluster (CDL-C mặc định là false, nhưng cứ copy cho chắc)
            channelObj.HasLOSCluster = refChan.HasLOSCluster;
            
            % [FIX] Không gán KFactorFirstCluster vì CDL-C là NLOS (HasLOSCluster=false)
            
            % --- BƯỚC 4: Xoay góc AoD ---
            newAoD = refChan.AnglesAoD + azimuthOffset;
            newAoD = mod(newAoD + 180, 360) - 180; % Wrap góc
            channelObj.AnglesAoD = newAoD;

            % --- BƯỚC 5: Cấu hình chung ---
            % [FIX] Không set DelaySpread ở đây nữa (vì đã áp dụng ở bước 1 rồi)
            
            channelObj.CarrierFrequency = 3.5e9;
            channelObj.MaximumDopplerShift = 5;
            
            channelObj.TransmitAntennaArray.Size = cdlChannelAntenna;
            channelObj.ReceiveAntennaArray.Size = [2, 1, 2, 1, 1]; 
            
            channelObj.SampleRate = sampleRate;
            channelObj.Seed = ueIdx;

            channel = channelObj;
            
        otherwise
            error('Invalid Type "%s"', channelType);
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
