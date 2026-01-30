function [Scheduled_UE_Indices, W_Total] = Block_SUS(par, var)
% BLOCK SUS: Chọn User (bao gồm tất cả layers) thay vì chọn từng vector lẻ.
% Input:
%   par.Us: Tổng số User tối đa muốn chọn (hoặc giới hạn tổng số Layer tùy cách bạn set)
%   par.B:  Số anten phát
%   var.H:  Cell Array {1xU}, mỗi phần tử là ma trận [NxL] của 1 UE.
% Output:
%   Scheduled_UE_Indices: Danh sách ID các UE được chọn
%   W_Total: Ma trận Precoding tổng hợp (gồm các cột trực giao hóa)

    epsilon = 0.3; % Block SUS cần epsilon nhỏ hơn một chút so với vector SUS
    
    % Biến đổi: Tính chuẩn Frobenius của từng UE trước để dùng sau
    Num_UEs = length(var.H);
    Fro_Norms = zeros(1, Num_UEs);
    for u = 1:Num_UEs
        Fro_Norms(u) = norm(var.H{u}, 'fro');
    end

    order = []; 
    
    % Vòng lặp nới lỏng Epsilon (như code gốc)
    while (length(order) < par.Us && epsilon < 1.0)
        
        % Reset lại mỗi lần tăng epsilon
        U_group = 1:Num_UEs; % Danh sách ứng viên
        Q_basis = [];        % Không gian trực giao đã chọn (Basis Matrix)
        order = [];          % Danh sách user được chọn
        
        total_layers_selected = 0;

        % Vòng lặp chọn từng User
        while ~isempty(U_group)
            
            % --- STEP 2: PROJECT (CHIẾU VUÔNG GÓC) ---
            % Tính phần năng lượng còn lại của từng UE sau khi chiếu lên 
            % không gian null của các UE đã chọn trước đó.
            
            g_norms = zeros(1, length(U_group));
            
            % Tạo ma trận chiếu P = Q * Q'
            if isempty(Q_basis)
                Projection_Matrix = zeros(par.B); % Chưa chọn ai, chiếu là chính nó
            else
                Projection_Matrix = Q_basis * Q_basis';
            end
            
            Identity = eye(par.B);
            
            for k = 1:length(U_group)
                ue_idx = U_group(k);
                H_k = var.H{ue_idx}; % Ma trận kênh của UE k [16x2]
                
                % Chiếu H_k xuống không gian null
                % G_k = (I - P) * H_k
                G_k = (Identity - Projection_Matrix) * H_k;
                
                % Tính độ lớn (dùng chuẩn Frobenius cho ma trận)
                g_norms(k) = norm(G_k, 'fro'); 
            end
            
            % --- STEP 3: SELECTION (CHỌN USER MẠNH NHẤT) ---
            [~, sel_idx] = max(g_norms);
            selected_ue = U_group(sel_idx);
            
            % Kiểm tra điều kiện dừng (nếu user này quá yếu hoặc đã đủ số lượng)
            if g_norms(sel_idx) < 1e-6 
                break; 
            end
            
            % Lưu user được chọn
            order = [order, selected_ue];
            
            % Cập nhật Basis (Q_basis)
            % Ta cần thêm các vector của UE mới vào Basis và trực giao hóa chúng
            H_new = var.H{selected_ue};
            
            % Trực giao hóa H_new với Q cũ để lấy phần Basis mới
            % (Dùng Gram-Schmidt hoặc đơn giản là lấy phần dư G_new chuẩn hóa)
            if isempty(Q_basis)
                [Q_new, ~] = qr(H_new, 0); % QR để trực giao nội bộ UE đầu tiên
            else
                % Lấy phần dư (đã tính ở trên, nhưng tính lại cho chắc chắn với user được chọn)
                G_new = (Identity - Projection_Matrix) * H_new;
                [Q_new, ~] = qr(G_new, 0); % Trực giao hóa phần dư
            end
            
            % Mở rộng không gian đã chọn
            Q_basis = [Q_basis, Q_new];
            total_layers_selected = total_layers_selected + size(H_new, 2);
            
            if total_layers_selected >= 4 % Ví dụ max 4 layers tổng
                break;
            end
            
            % --- STEP 4: FILTERING (LỌC CÁC USER CÒN LẠI) ---
            % Loại bỏ user vừa chọn
            U_group(sel_idx) = [];
            
            temp_group = [];
            % Cập nhật ma trận chiếu với Basis mới nhất
            Projection_Matrix_New = Q_basis * Q_basis';
            
            for j = 1:length(U_group)
                cand_id = U_group(j);
                H_cand = var.H{cand_id};
                
                % Tính độ tương quan (Correlation)
                % Tỷ lệ năng lượng bị trùng lắp với không gian đã chọn
                % Proj_Energy = || P * H_cand ||_F
                Proj_Energy = norm(Projection_Matrix_New * H_cand, 'fro');
                
                % Total_Energy = || H_cand ||_F
                Total_Energy = Fro_Norms(cand_id);
                
                correlation = Proj_Energy / Total_Energy;
                
                % Nếu tương quan thấp (ít trùng lắp) -> Giữ lại
                if correlation < epsilon
                    temp_group = [temp_group, cand_id];
                end
            end
            U_group = temp_group;
        end
        
        % Nếu chưa đủ số lượng mong muốn, nới lỏng Epsilon để chọn dễ hơn
        if length(order) < par.Us
             epsilon = epsilon + 0.1;
        else
             break; % Đã đủ
        end
    end

    Scheduled_UE_Indices = sort(order);
    
    % Tạo W tổng hợp (nếu cần dùng ngay)
    W_Total = [];
    if ~isempty(Scheduled_UE_Indices)
        for i = 1:length(Scheduled_UE_Indices)
            W_Total = [W_Total, var.H{Scheduled_UE_Indices(i)}];
        end
    end
end