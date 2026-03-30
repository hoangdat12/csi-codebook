function orthogonalityScore = chordalDistance(PMI_m, PMI_n)
    % -----------------------------------------------------------------
    % INPUT VALIDATION
    % -----------------------------------------------------------------
    if size(PMI_m, 1) ~= size(PMI_n, 1)
        error('Input matrices must have the same number of rows (Antennas).');
    end
    
    if size(PMI_m, 2) ~= size(PMI_n, 2)
        error('Input matrices must have the same number of columns (Layers).');
    end

    % Lấy số lượng Layers (L)
    NumLayers = size(PMI_m, 2);

    % -----------------------------------------------------------------
    % CHORDAL DISTANCE CALCULATION (Chuẩn cho MU-MIMO mọi cấu hình Layer)
    % -----------------------------------------------------------------
    % 1. Tính ma trận tương quan chéo (R = W1' * W2)
    R = PMI_m' * PMI_n;
    
    % 2. Tính bình phương chuẩn Frobenius của R
    normR2 = norm(R, 'fro')^2;
    
    % 3. Chuẩn hóa bằng năng lượng của từng PMI
    normM2 = norm(PMI_m, 'fro')^2;
    normN2 = norm(PMI_n, 'fro')^2;
    
    % 4. Tính tương quan có nhân thêm NumLayers để cân bằng tỷ lệ
    correlation = (NumLayers * normR2) / (normM2 * normN2);
    
    % Ngăn chặn sai số phẩy động của MATLAB (ví dụ correlation = 1.00000002)
    correlation = min(real(correlation), 1);
    
    % 5. Trả về khoảng cách
    orthogonalityScore = 1 - correlation;
end