% -----------------------------------------------------------------
% This function calculates the MMSE Precoding Matrix
% It returns:
%   - W_mmse_transposed: The transposed precoding matrix
% -----------------------------------------------------------------
function W_mmse_transposed = getMMSEPrecoder(H_est, SNR_dB, ~) 
    % Bỏ numTx ở đầu vào (dùng dấu ~) vì ta không dùng nó để tính alpha nữa

    % -----------------------------------------------------------------
    % SNR & REGULARIZATION
    % -----------------------------------------------------------------
    % Chuyển SNR từ dB sang linear scale
    SNR_linear = 10^(SNR_dB/10);

    % Lấy số lượng luồng/UE (K)
    K = size(H_est, 1); 

    % SỬA LỖI 1: Tính alpha dựa trên số lượng UE (K) thay vì số lượng Anten phát
    alpha = K / SNR_linear; 
    
    % -----------------------------------------------------------------
    % MMSE MATRIX CALCULATION
    % -----------------------------------------------------------------
    H_conj = H_est';

    % Tính: (H * H') + (alpha * I)
    term = (H_est * H_conj) + (alpha * eye(K));
    
    % Tính Precoder P (Kích thước: NumTx x K)
    P = H_conj / term; 
    
    % -----------------------------------------------------------------
    % POWER NORMALIZATION (SỬA LỖI 2)
    % -----------------------------------------------------------------
    % Thay vì chuẩn hóa tổng, ta chuẩn hóa từng cột của P 
    % để đảm bảo mỗi UE/luồng nhận được mức công suất phát đều nhau (1 đơn vị)
    for k = 1:K
        norm_factor = norm(P(:, k));
        P(:, k) = P(:, k) / norm_factor;
    end
    
    % -----------------------------------------------------------------
    % OUTPUT
    % -----------------------------------------------------------------
    % Trả về ma trận chuyển vị (không liên hợp) để khớp với code của bạn
    W_mmse_transposed = P.'; 
end