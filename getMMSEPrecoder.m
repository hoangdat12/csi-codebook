function W_mmse_transposed = getMMSEPrecoder(H_est, SNR_dB, numTx)
    SNR_linear = 10^(SNR_dB/10);
    alpha = numTx / SNR_linear; 
    
    H_conj = H_est';
    term = (H_est * H_conj) + (alpha * eye(size(H_est, 1)));
    P = H_conj / term; 
    
    scale = sqrt(size(H_est, 1) / trace(P * P'));
    P = P * scale; 
    
    W_mmse_transposed = P.'; 
end