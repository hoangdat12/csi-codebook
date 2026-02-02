clear; clc; close all;

N1 = 4; 
N2 = 1;
O1 = 4;
O2 = 1;
L = 2;

nlayers = 2;

[best_pair, W_best_UE1, W_best_UE2, all_candidate_pairs, min_corr, best_Cmn] = ...
    findBestUEPair(100, nlayers ,N1, N2, O1, O2, L);

% Display
disp(best_Cmn);

if ~isempty(all_candidate_pairs)
    results_table = struct2table(all_candidate_pairs);
    disp('UE Candidate:');
    disp(results_table);
else
    disp('Empty List!.');
end

fprintf('Best UE Selected: %d and %d\n', best_pair(1), best_pair(2));



