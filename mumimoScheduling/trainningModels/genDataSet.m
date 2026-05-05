% =========================================================================
% generateMLDataset.m
%
% Script tạo bộ dữ liệu Dataset cho Machine Learning.
% - Sử dụng logic đọc file gốc từ prepareData để nạp toàn bộ Codebook.
% - Tính toán vét cạn C(N, 2) cặp để lấy nhãn Chordal Distance.
% =========================================================================
clear; clc; close all;
setupPath();

%% 1. Cấu hình thông số
nLayers = 4;
config.CodeBookConfig.N1 = 4;
config.CodeBookConfig.N2 = 4;
config.CodeBookConfig.cbMode = 1;

% Format tên file giống như trong prepareData của bạn
N1 = config.CodeBookConfig.N1;
N2 = config.CodeBookConfig.N2;
cbMode = config.CodeBookConfig.cbMode;
nPort = 2 * N1 * N2;

% Tên file cố định theo chuẩn của bạn (hoặc đổi lại %s nếu cần)
config.FileName = "Layer4_Port32_N1_4_N2-4_c1.txt"; 

fprintf('--- BẮT ĐẦU TẠO DATASET CHO MACHINE LEARNING ---\n');

%% 2. Đọc toàn bộ Codebook từ file TXT (Logic trích xuất từ prepareData)
fprintf('1. Đang tải precoding matrix pool từ file: %s...\n', config.FileName);

fid = fopen(config.FileName, 'r');
if fid == -1
    error('Cannot open file: %s', config.FileName);
end

W_codebook  = [];
pmi_in_file = 0;

% Đọc vét cạn file để lấy toàn bộ các ma trận (không random)
while ~feof(fid)
    info_line = fgetl(fid);
    if ~ischar(info_line), break; end
    if isempty(strtrim(info_line)), continue; end

    pmi_in_file = pmi_in_file + 1;

    W_temp = zeros(nPort, nLayers);
    for row = 1:nPort
        row_data = fgetl(fid);
        W_temp(row, :) = str2num(row_data);
    end
    W_codebook(:, :, pmi_in_file) = W_temp;
end
fclose(fid);

fprintf('   -> Đã tải thành công %d precoding matrices gốc.\n', pmi_in_file);

%% 3. Khởi tạo mảng dữ liệu (Pre-allocation)
numPMI = pmi_in_file;
numPairs = (numPMI * (numPMI - 1)) / 2; 

fprintf('\n2. Khởi tạo tính toán cho %d tổ hợp cặp...\n', numPairs);
dataset = zeros(numPairs, 3); % Format: [Index_1, Index_2, Chordal_Distance]

%% 4. Vòng lặp kép tính toán vét cạn
idx = 1;
tic; % Bắt đầu đo thời gian

for i = 1:(numPMI - 1)
    W_i = W_codebook(:, :, i);
    for j = (i + 1):numPMI
        W_j = W_codebook(:, :, j);
        
        % Tính khoảng cách Chordal (Gọi hàm có sẵn trong dự án)
        dist = chordalDistance(W_i, W_j);
        
        % Lưu dữ liệu
        dataset(idx, 1) = i;
        dataset(idx, 2) = j;
        dataset(idx, 3) = dist;
        
        idx = idx + 1;
    end
    
    % In tiến độ cho mỗi 100 ma trận
    if mod(i, 100) == 0
        fprintf('   - Đã tính xong các cặp của PMI thứ %d / %d\n', i, numPMI);
    end
end

thoi_gian_chay = toc;
fprintf('   -> Hoàn thành tính toán trong %.2f giây.\n', thoi_gian_chay);

%% 5. Xuất kết quả ra file CSV để train Model
outputFilename = 'mu_mimo_dataset_full.csv';
fprintf('\n3. Đang xuất dữ liệu ra file: %s...\n', outputFilename);

header = {'PMI_Index_1', 'PMI_Index_2', 'Chordal_Distance'};
dataTable = array2table(dataset, 'VariableNames', header);
writetable(dataTable, outputFilename);

fprintf('--- XONG! SẴN SÀNG ĐƯA QUA PYTHON ĐỂ TRAIN MODEL. ---\n');