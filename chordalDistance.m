function orthogonalityScore = chordalDistance(PMI_m, PMI_n)
    if size(PMI_m, 1) ~= size(PMI_n, 1)
        error('Input matrices must have the same number of rows (Antennas).');
    end
    % KHÔNG ép cùng số layer

    % Orthonormalize: đưa về orthonormal basis của subspace
    [Q_m, ~] = qr(PMI_m, 0);
    [Q_n, ~] = qr(PMI_n, 0);

    % L = min số layer — bậc tự do tối đa để so sánh
    L = min(size(PMI_m, 2), size(PMI_n, 2));

    % Cross-correlation giữa 2 subspace
    R  = Q_m' * Q_n;          % (L_m x L_n)

    % SVD để lấy principal angles — bắt buộc với multi-layer
    sv = svd(R);
    sv = min(real(sv), 1.0);  % clamp floating-point

    % Grassmannian chordal distance, normalize về [0,1]
    chordalDist        = sqrt(max(L - sum(sv.^2), 0));
    orthogonalityScore = chordalDist / sqrt(L);
end