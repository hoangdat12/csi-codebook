% -----------------------------------------------------------------
% This function performs User Scheduling based on PMI correlation
% It return:
%   - schedulingList: Structure containing paired and unpaired UEs
%   - info: Statistics about the scheduling result (counts, min/max corr)
% -----------------------------------------------------------------
function [schedulingList, info] = ...
    scheduling(All_UE_Feedback, channelList, THREAD_HOLD)

    setupPath();

    % Total number of UEs
    num_ues = length(All_UE_Feedback);
    
    % -----------------------------------------------------------------
    % INITIALIZATION
    % -----------------------------------------------------------------
    % Variables to track min/max correlation stats
    min_corr = inf;
    max_corr = -inf;
    
    % Initialize the scheduling list structure
    schedulingList.pair = struct('UE1', {}, 'UE2', {}, 'correlation', {});
    schedulingList.unPair = struct('UE1', {}, 'correlation', {});
    
    % Counters for the lists
    countPair = 1;
    countUnpair = 1;

    % Tracking array: FALSE = not paired, TRUE = paired
    is_paired = false(1, num_ues);

    % -----------------------------------------------------------------
    % PAIRING LOGIC
    % -----------------------------------------------------------------
    for m = 1:num_ues
        % Skip if UE m is already paired
        if is_paired(m) 
            continue; 
        end

        for n = m+1:num_ues
            % Skip if UE n is already paired
            if is_paired(n) 
                continue; 
            end
            
            % Retrieve Precoding Matrices
            W1 = All_UE_Feedback{m};
            W2 = All_UE_Feedback{n};
            
            % Calculate correlation
            c_complex = PMIPair(W1, W2);
            current_corr = abs(c_complex);

            % Check if correlation satisfies the threshold
            if current_corr < THREAD_HOLD
                % Update statistics
                if current_corr < min_corr, min_corr = current_corr; end
                if current_corr > max_corr, max_corr = current_corr; end

                % 1. Create info structures for both UEs
                ue1_info = struct('ueIdx', m, 'W', W1, 'channel', channelList{m});
                ue2_info = struct('ueIdx', n, 'W', W2, 'channel', channelList{n});
                
                % 2. Save to the 'pair' list
                schedulingList.pair(countPair).UE1 = ue1_info;
                schedulingList.pair(countPair).UE2 = ue2_info;
                schedulingList.pair(countPair).correlation = current_corr;
                
                countPair = countPair + 1;
                
                % 3. Mark UEs as paired
                is_paired(m) = true;
                is_paired(n) = true;

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
            
            % Save to 'unPair' list (Correlation is NaN)
            schedulingList.unPair(countUnpair).UE1 = ue1_info;
            schedulingList.unPair(countUnpair).correlation = NaN; 
            
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
    if isinf(min_corr)
        info.min_corr_abs = NaN;
        info.max_corr_abs = NaN;
    else
        info.min_corr_abs = min_corr;
        info.max_corr_abs = max_corr;
    end
    
    fprintf(' -> Scheduling Done: %d Pairs | %d Unpaired UEs\n', ...
            info.scheduled_pairs, info.unpaired_ues);
end