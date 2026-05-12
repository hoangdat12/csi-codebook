function [W_all, UE_Reported_Indices, totalPMI, PMI_list, H_list] = prepareData(config, nLayers, numberOfUE)
    SNR_dB = 20;
    % Extract codebook configuration parameters
    N1     = config.CodeBookConfig.N1;
    N2     = config.CodeBookConfig.N2;
    cbMode = config.CodeBookConfig.cbMode;
    nPort  = 2 * N1 * N2;
    filename = sprintf(config.FileName, nPort, nLayers, cbMode, N1, N2);

    fprintf('Loading precoding matrix pool from file: %s...\n', filename);

    fid = fopen(filename, 'r');
    if fid == -1
        error('Cannot open file: %s', filename);
    end

    W_pool      = [];
    pool_info   = {};
    pmi_in_file = 0;

    % Read all precoding matrices from file
    while ~feof(fid)
        info_line = fgetl(fid);
        if ~ischar(info_line), break; end
        if isempty(strtrim(info_line)), continue; end

        pmi_in_file = pmi_in_file + 1;
        pool_info{pmi_in_file} = info_line;

        W_temp = zeros(nPort, nLayers);
        for row = 1:nPort
            row_data = fgetl(fid);
            W_temp(row, :) = str2num(row_data);
        end
        W_pool(:, :, pmi_in_file) = W_temp;
    end
    fclose(fid);

    fprintf('Successfully loaded %d precoding matrices from file.\n', pmi_in_file);
    totalPMI = pmi_in_file;

    % -------------------------------------------------------------------------
    % Sinh numberOfUE kênh H ngẫu nhiên Rayleigh [Nr x nPort]
    % Với mỗi H tìm PMI tốt nhất: PMI = argmax_i ||H * W_i||^2_F
    % SNR không ảnh hưởng argmax với Type I nhưng truyền vào để mở rộng sau
    % -------------------------------------------------------------------------
    fprintf('Generating %d Rayleigh H [%d x %d], SNR = %d dB...\n', ...
        numberOfUE, nLayers, nPort, SNR_dB);

    H_list            = zeros(nLayers, nPort, numberOfUE);
    PMI_list          = zeros(numberOfUE, 1);       % 0-indexed
    best_idx_list     = zeros(numberOfUE, 1);       % 1-indexed (dùng nội bộ)

    for k = 1:numberOfUE
        % Sinh H theo Rayleigh fading
        H_k = (randn(nLayers, nPort) + 1j*randn(nLayers, nPort)) / sqrt(2);
        H_list(:, :, k) = H_k;

        % Tìm PMI tốt nhất
        best_val = -inf;
        best_idx = 1;
        for i = 1:totalPMI
            val = norm(H_k * W_pool(:, :, i), 'fro')^2;
            if val > best_val
                best_val = val;
                best_idx = i;
            end
        end

        PMI_list(k)      = best_idx - 1;   % 0-indexed
        best_idx_list(k) = best_idx;       % 1-indexed để index vào pool
    end

    fprintf('PMI search done. Extracting W and info...\n');

    % Vectorized extraction theo best_idx tìm được
    W_all               = W_pool(:, :, best_idx_list);
    UE_Reported_Indices = pool_info(best_idx_list);

    fprintf('Done. W_all: [%d x %d x %d]\n\n', size(W_all,1), size(W_all,2), size(W_all,3));
end