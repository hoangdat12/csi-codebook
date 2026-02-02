function [best_pair_info, worst_pair_info, all_candidates, info] = ...
    findBestUEPair(All_UE_Feedback, channelList, THREAD_HOLD)

    setupPath();

    num_ues = length(All_UE_Feedback);
    min_corr = inf;
    max_corr = -inf;
    best_Cmn = 0;
    worst_Cmn = 0;
    best_pair_info = [];
    worst_pair_info = [];
    
    all_candidates = struct('indices', {}, 'correlation', {});
    count = 1;

    for m = 1:num_ues
        for n = m+1:num_ues
            W1 = All_UE_Feedback{m};
            W2 = All_UE_Feedback{n};
            
            c_complex = PMIPair(W1, W2);
            current_corr = abs(c_complex);

            if current_corr < THREAD_HOLD
                all_candidates(count).indices = [m n];
                all_candidates(count).correlation = current_corr;
                count = count + 1;
            end

            if current_corr < min_corr
                min_corr = current_corr;
                best_Cmn = c_complex; 
                
                best_pair_info = struct('indices', [m n], 'c_complex', c_complex, ...
                    'UE1', struct('idx', m, 'W', W1, 'channel', channelList{m}), ...
                    'UE2', struct('idx', n, 'W', W2, 'channel', channelList{n}));
            end

            if current_corr > max_corr
                max_corr = current_corr;
                worst_Cmn = c_complex;
                
                worst_pair_info = struct('indices', [m n], 'c_complex', c_complex, ...
                    'UE1', struct('idx', m, 'W', W1, 'channel', channelList{m}), ...
                    'UE2', struct('idx', n, 'W', W2, 'channel', channelList{n}));
            end
        end
    end

    info.total_ues = num_ues;
    info.total_pairs = (num_ues * (num_ues - 1)) / 2;
    info.valid_count = length(all_candidates);
    info.invalid_count = info.total_pairs - info.valid_count;
    
    info.best_Cmn = best_Cmn;
    info.worst_Cmn = worst_Cmn;
    info.min_corr_abs = min_corr;
    info.max_corr_abs = max_corr;

    fprintf('UEs: %d | Valid Pairs: %d/%d\n', info.total_ues, info.valid_count, info.total_pairs);
end