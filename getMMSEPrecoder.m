% -----------------------------------------------------------------
% This function calculates the MMSE Precoding Matrix
% It return:
%   - W_mmse_transposed: The transposed precoding matrix
% -----------------------------------------------------------------
function W_mmse_transposed = getMMSEPrecoder(H_est, SNR_dB, numTx)

    % -----------------------------------------------------------------
    % SNR & REGULARIZATION
    % -----------------------------------------------------------------
    % Convert SNR from dB to linear scale
    SNR_linear = 10^(SNR_dB/10);

    % Calculate regularization factor alpha
    % Usually defined as NumTx / SNR_linear for MMSE
    alpha = numTx / SNR_linear; 
    
    % -----------------------------------------------------------------
    % MMSE MATRIX CALCULATION
    % -----------------------------------------------------------------
    % Hermitian transpose (Conjugate Transpose) of Channel Matrix
    H_conj = H_est';

    % Calculate term: (H * H') + (alpha * I)
    term = (H_est * H_conj) + (alpha * eye(size(H_est, 1)));
    
    % Compute unnormalized precoder P = H' * inv(term)
    % Using Matrix Right Division (/) is numerically more stable than inv()
    P = H_conj / term; 
    
    % -----------------------------------------------------------------
    % POWER NORMALIZATION
    % -----------------------------------------------------------------
    % Calculate scaling factor to ensure total power constraint
    scale = sqrt(size(H_est, 1) / trace(P * P'));
    P = P * scale; 
    
    % -----------------------------------------------------------------
    % OUTPUT
    % -----------------------------------------------------------------
    % Return the non-conjugate transpose of the precoder
    W_mmse_transposed = P.'; 
end