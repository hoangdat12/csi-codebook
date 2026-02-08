function orthogonalityScore = chordalDistance(PMI_m, PMI_n)
    % -----------------------------------------------------------------
    % INPUT VALIDATION
    % -----------------------------------------------------------------
    if size(PMI_m, 1) ~= size(PMI_n, 1)
        error('Input matrices must have the same number of rows (Antennas).');
    end

    % -----------------------------------------------------------------
    % CHORDAL DISTANCE CALCULATION (Chuẩn cho MU-MIMO)
    % -----------------------------------------------------------------
    % 1. Tính ma trận tương quan chéo (R = W1' * W2)
    R = PMI_m' * PMI_n;
    
    % 2. Tính bình phương chuẩn Frobenius của R
    normR2 = norm(R, 'fro')^2;
    
    % 3. Chuẩn hóa bằng năng lượng của từng PMI
    normM2 = norm(PMI_m, 'fro')^2;
    normN2 = norm(PMI_n, 'fro')^2;
    
    correlation = normR2 / (normM2 * normN2);
    
    orthogonalityScore = 1 - correlation;
end