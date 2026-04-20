function [W_all, UE_Reported_Indices, totalPMI] = prepareData(config, nLayers, numberOfUE)
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

    % Randomly sample numberOfUE matrices with replacement.
    % Example: if the file contains 128 matrices, rand_idx holds
    % numberOfUE random integers in [1, 128].
    fprintf('Sampling %d random precoding matrices from pool...\n', numberOfUE);
    rand_idx = randi(pmi_in_file, 1, numberOfUE);

    % Vectorized extraction
    W_all               = W_pool(:, :, rand_idx);
    UE_Reported_Indices = pool_info(rand_idx);
    totalPMI            = pmi_in_file;

    fprintf('Done. W_all: [%d x %d x %d]\n\n', size(W_all, 1), size(W_all, 2), size(W_all, 3));
end