function [Scheduled_Struct, Precoding_Matrix] = MultiRank_SUS_Wrapper(All_UE_Feedback, params)
    % Hàm Wrapper để xử lý input đa layer cho SUS
    
    % B1: Duỗi dữ liệu (Flattening) - Chuyển từ UE sang User ảo
    H_virtual = [];
    Map_Table = []; % [UE_ID, Layer_ID]
    
    total_candidates = 0;
    for u = 1:length(All_UE_Feedback)
        W = All_UE_Feedback{u};
        if isempty(W), continue; end % Bỏ qua nếu W rỗng
        
        for l = 1:size(W, 2)
            total_candidates = total_candidates + 1;
            vec = W(:, l);
            % Chuẩn hóa vector để thuật toán SUS tính góc chính xác
            if norm(vec) > 0
                vec = vec / norm(vec); 
            end
            H_virtual = [H_virtual, vec];
            Map_Table(total_candidates, :) = [u, l];
        end
    end
    
    % Kiểm tra nếu không có ứng viên nào
    if total_candidates == 0
        Scheduled_Struct = struct('UE_ID', {}, 'Layer_ID', {});
        Precoding_Matrix = [];
        return;
    end
    
    % B2: Cấu hình và gọi SUS
    sus_par.Us = params.Max_Layers;
    sus_par.U  = total_candidates;
    sus_par.B  = params.Num_Antennas;
    sus_par.timeslots = 1;
    sus_var.H  = H_virtual;
    
    % Gọi hàm SUS
    try
        C_matrix = SUS(sus_par, sus_var);
    catch err
        error('Lỗi khi gọi hàm SUS: %s. Hãy kiểm tra file SUS.m', err.message);
    end
    
    % B3: Xử lý kết quả
    selected_indices = find(C_matrix(:,1) == 1);
    num_selected = length(selected_indices);
    
    if num_selected == 0
        Scheduled_Struct = struct('UE_ID', {}, 'Layer_ID', {});
        Precoding_Matrix = [];
        return;
    end

    % --- FIX LỖI INDEX EXCEEDS BOUNDS ---
    % Cấp phát trước struct với kích thước chính xác
    Scheduled_Struct = repmat(struct('UE_ID', [], 'Layer_ID', []), 1, num_selected);
    
    for i = 1:num_selected
        idx = selected_indices(i);
        Scheduled_Struct(i).UE_ID = Map_Table(idx, 1);
        Scheduled_Struct(i).Layer_ID = Map_Table(idx, 2);
    end
    
    % B4: Tính Zero-Forcing Precoding
    H_effective = H_virtual(:, selected_indices);
    
    % W_ZF = H_eff * inv(H_eff' * H_eff) -> Dùng pinv cho an toàn
    W_ZF = pinv(H_effective'); 
    
    % Chuẩn hóa công suất (Chia đều P=1 cho các stream)
    P_total = 1;
    % Đảm bảo chia cho số stream thực tế
    scaling = sqrt(P_total / size(W_ZF, 2)); 
    Precoding_Matrix = W_ZF .* scaling;
end