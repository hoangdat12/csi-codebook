function [W_all, UE_Reported_Indices, totalPMI] = prepareData(config, nLayers, numberOfUE)
    % Trích xuất thông số cấu hình
    N1 = config.CodeBookConfig.N1;
    N2 = config.CodeBookConfig.N2;
    cbMode = config.CodeBookConfig.cbMode;
    nPort = 2 * N1 * N2;
    filename = sprintf(config.FileName, nPort, nLayers, cbMode, N1, N2);

    fprintf('Đang nạp "bể" ma trận (pool) từ file: %s...\n', filename);

    fid = fopen(filename, 'r');
    if fid == -1
        error('Không thể mở file: %s', filename);
    end

    W_pool = [];
    pool_info = {};
    pmi_in_file = 0;

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

    fprintf('Đã nạp thành công %d ma trận mẫu từ file.\n', pmi_in_file);

    % --- BƯỚC 2: LẤY MẪU NGẪU NHIÊN 20,000 CÁI TỪ POOL ---
    fprintf('Bắt đầu lấy mẫu %d ma trận ngẫu nhiên từ bể chứa...\n', numberOfUE);

    % Tạo 20,000 chỉ số ngẫu nhiên nằm trong khoảng từ 1 đến số lượng ma trận trong file
    % Ví dụ: Nếu file có 128 ma trận, rand_idx sẽ chứa 20,000 số ngẫu nhiên từ 1-128
    rand_idx = randi(pmi_in_file, 1, numberOfUE);

    % Trích xuất nhanh bằng cách sử dụng mảng chỉ số (Vectorized Indexing)
    W_all = W_pool(:, :, rand_idx);
    
    % Lấy thông tin PMI tương ứng
    UE_Reported_Indices = pool_info(rand_idx);

    totalPMI = pmi_in_file;

    fprintf('Hoàn thành! W_all: [%d x %d x %d]\n\n', size(W_all, 1), size(W_all, 2), size(W_all, 3));
end