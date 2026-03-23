function W_mmse_transposed = getMMSEPrecoder(H_est, SNR_dB, ~) 
    % Chuyển SNR từ dB sang linear scale
    SNR_linear = 10^(SNR_dB/10);

    % Lấy số lượng luồng/UE (K)
    K = size(H_est, 1); 

    % Tính hệ số điều chuẩn alpha
    alpha = K / SNR_linear; 
    
    % Tính toán ma trận nghịch đảo MMSE/RZF
    H_conj = H_est';
    term = (H_est * H_conj) + (alpha * eye(K));
    P = H_conj / term; 
    
    % Chuẩn hóa công suất từng luồng (Equal Power Allocation)
    for k = 1:K
        norm_factor = norm(P(:, k));
        P(:, k) = P(:, k) / norm_factor;
    end
    
    % Trả về ma trận chuyển vị
    W_mmse_transposed = P.'; 
end