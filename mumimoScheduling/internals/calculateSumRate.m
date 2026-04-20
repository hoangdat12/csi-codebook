function [sumRate_Mbps, throughput_list_Mbps] = calculateSumRate(pdsch_list, SCS)
    num_UEs             = length(pdsch_list);
    throughput_list_Mbps = zeros(1, num_UEs);
    sumRate_Mbps        = 0;

    for i = 1:num_UEs
        % Get PDSCH config for UE i
        current_pdsch = pdsch_list{i};

        % Compute single-UE throughput (K=1: no MU-MIMO scaling)
        [throughput_UE, ~] = calculateThroughput(current_pdsch, SCS, 1);

        throughput_list_Mbps(i) = throughput_UE;
        sumRate_Mbps            = sumRate_Mbps + throughput_UE;
    end
end