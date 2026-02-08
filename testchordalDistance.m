clear; clc; close all;

setupPath();

% -----------------------------------------------------------------
% Configuration Parameters
% -----------------------------------------------------------------
nLayers = 2;
nTxAnts = 8;                
nRxAnts = 4;                 
sampleRate = 61440000;  
SNR_dB = 20;
NumUEs = 10;


% Channel for test
% Rayleigh || AWGN || Ideal || TDL
% With Ideal channel, we can't choose the PMI orthogonal 
% Because of all channel use the same PMI
channelType = "TDL";
channel = getChannel(channelType, SNR_dB, nRxAnts, 1, sampleRate); 

% -----------------------------------------------------------------
% Carrier Configuration
% -----------------------------------------------------------------
carrier = nrCarrierConfig;
% Sharetechnote frame structure 
% Table 5.3.2-1 138-101-1
% https://www.etsi.org/deliver/etsi_ts/138100_138199/13810101/17.08.00_60/ts_13810101v170800p.pdf
carrier.SubcarrierSpacing = 15;  
carrier.NSizeGrid = 273;

% -----------------------------------------------------------------
% CSI Configuration
% -----------------------------------------------------------------
csiConfig = nrCSIRSConfig;
csiConfig.CSIRSType = {'nzp'};
% https://www.etsi.org/deliver/etsi_ts/138200_138299/138211/18.06.00_60/ts_138211v180600p.pdf
% Bảng 7.4.1.5.3-1.
csiConfig.RowNumber = 6;           
csiConfig.Density = {'one'};
csiConfig.SubcarrierLocations = {[0 2 4 6]};
csiConfig.SymbolLocations = {0};
csiConfig.CSIRSPeriod = [4 0];
csiConfig.NumRB = 273;
csiConfig.RBOffset = 0;

% -----------------------------------------------------------------
% CSI Report Configuration Type II
% -----------------------------------------------------------------
subbandAmplitude = true;
csiReport = nrCSIReportConfig;
csiReport.CQITable = "table2"; 
csiReport.CodebookType = "type2";
csiReport.PanelDimensions = [1 4 1]; 
csiReport.PMIFormatIndicator = "subband";
csiReport.CQIFormatIndicator = "subband";
csiReport.SubbandSize = 32;
csiReport.SubbandAmplitude = subbandAmplitude;
csiReport.NumberOfBeams = 2;
csiReport.PhaseAlphabetSize = 4;
csiReport.RIRestriction = [1 1 0 0]; 

% -----------------------------------------------------------------
% PDSCH Configuration
% -----------------------------------------------------------------
pdsch = customPDSCHConfig(); 

pdsch.DMRS.DMRSConfigurationType = 1;
pdsch.DMRS.DMRSAdditionalPosition = 1;
pdsch.NumLayers = nLayers;
% 273 PRB
pdsch.PRBSet = 0:272;

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


    [schedulingList, info] = scheduling(all_W, channelList, 0.9);

    
pairedUEs = schedulingList.pair;
unPairedUEs = schedulingList.unPair;

BER_THREAD_HOLD = 10e-9;

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
% This function performs User Scheduling based on PMI correlation
% It return:
%   - schedulingList: Structure containing paired and unpaired UEs
%   - info: Statistics about the scheduling result (counts, min/max corr)
% -----------------------------------------------------------------
function [schedulingList, info] = scheduling(All_UE_Feedback, channelList, THREAD_HOLD)

    setupPath();

    % Total number of UEs
    num_ues = length(All_UE_Feedback);
    
    % -----------------------------------------------------------------
    % INITIALIZATION
    % -----------------------------------------------------------------
    % Variables to track orthogonality stats (High score is good)
    min_score = inf;
    max_score = -inf;
    
    % Initialize the scheduling list structure
    schedulingList.pair = struct('UE1', {}, 'UE2', {}, 'orthogonalityScore', {});
    schedulingList.unPair = struct('UE1', {}, 'orthogonalityScore', {});
    
    % Counters for the lists
    countPair = 1;
    countUnpair = 1;

    % Tracking array: FALSE = not paired, TRUE = paired
    is_paired = false(1, num_ues);

    % -----------------------------------------------------------------
    % PAIRING LOGIC (Greedy Search)
    % -----------------------------------------------------------------
    for m = 1:num_ues
        % Skip if UE m is already paired
        if is_paired(m) 
            continue; 
        end

        best_candidate = -1;
        best_current_score = -1;

        % Tìm ghép cặp tốt nhất cho UE m trong số các UE chưa ghép còn lại
        for n = m+1:num_ues
            % Skip if UE n is already paired
            if is_paired(n) 
                continue; 
            end
            
            % Retrieve Precoding Matrices
            W1 = All_UE_Feedback{m};
            W2 = All_UE_Feedback{n};
            
            % [UPDATE] Use the new chordalDistance function
            % Score: 0 (Trùng nhau/Xấu) -> 1 (Trực giao/Tốt)
            current_score = chordalDistance(W1, W2);

            % [LOGIC CHANGE] Chúng ta tìm cặp có điểm CAO HƠN ngưỡng
            if current_score > THREAD_HOLD
                % Nếu tìm thấy cặp thỏa mãn, bạn có thể chọn ngay (Greedy) 
                % hoặc lưu lại để tìm cặp tốt nhất (Best Fit). 
                % Ở đây tôi giữ logic "gặp là chốt" (First Fit) như code cũ để chạy nhanh.
                
                % Update stats
                if current_score < min_score, min_score = current_score; end
                if current_score > max_score, max_score = current_score; end

                % 1. Create info structures for both UEs
                ue1_info = struct('ueIdx', m, 'W', W1, 'channel', channelList{m});
                ue2_info = struct('ueIdx', n, 'W', W2, 'channel', channelList{n});
                
                % 2. Save to the 'pair' list
                schedulingList.pair(countPair).UE1 = ue1_info;
                schedulingList.pair(countPair).UE2 = ue2_info;
                schedulingList.pair(countPair).orthogonalityScore = current_score;
                
                countPair = countPair + 1;
                
                % 3. Mark UEs as paired
                is_paired(m) = true;
                is_paired(n) = true;
                
                % Đã tìm được cặp cho m, thoát vòng lặp n để chuyển sang UE tiếp theo
                best_candidate = n; 
                break; 
            end
        end
    end

    % -----------------------------------------------------------------
    % UNPAIRED UES HANDLING
    % -----------------------------------------------------------------
    for k = 1:num_ues
        if ~is_paired(k)
            % Create info structure for the unpaired UE
            ue1_info = struct('ueIdx', k, 'W', All_UE_Feedback{k}, 'channel', channelList{k});
            
            % Save to 'unPair' list
            schedulingList.unPair(countUnpair).UE1 = ue1_info;
            schedulingList.unPair(countUnpair).orthogonalityScore = NaN; 
            
            countUnpair = countUnpair + 1;
        end
    end

    % -----------------------------------------------------------------
    % STATISTICS & RETURN
    % -----------------------------------------------------------------
    info.total_ues = num_ues;
    info.scheduled_pairs = length(schedulingList.pair);
    info.unpaired_ues = length(schedulingList.unPair);
    
    % Handle cases where no pairs were formed
    if isinf(min_score)
        info.min_score = NaN;
        info.max_score = NaN;
    else
        info.min_score = min_score;
        info.max_score = max_score;
    end
    
    fprintf(' -> Scheduling Done: %d Pairs | %d Unpaired UEs | Best Score: %.4f\n', ...
            info.scheduled_pairs, info.unpaired_ues, info.max_score);
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