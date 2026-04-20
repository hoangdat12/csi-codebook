function [sumRate_Mbps, throughput_list] = calculateSumRate(pdsch_list, SCS)
    num_UEs = length(pdsch_list);
    throughput_list = zeros(1, num_UEs);
    sumRate_Mbps = 0;
    
    for i = 1:num_UEs
        % Lấy cấu hình PDSCH của UE thứ i
        current_pdsch = pdsch_list{i};
        
        % Gọi hàm tính throughput. 
        % Truyền K=1 vì ta đang tính riêng lẻ cho từng UE trong danh sách.
        [throughput_UE, ~] = calculateThroughput(current_pdsch, SCS, 1);
        
        % Lưu lại kết quả
        throughput_list(i) = throughput_UE;
        sumRate_Mbps = sumRate_Mbps + throughput_UE;
    end
end