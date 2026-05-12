clear; clc; close all;
setupPath();

% ----------------------------------------------------------------------------
% Configuration
% ----------------------------------------------------------------------------
nLayers    = 4;
numberOfUE = 1000;
Nr         = 4;
SNR_dB     = 20;
SNR_linear = 10^(SNR_dB/10);

config.CodeBookConfig.N1     = 4;
config.CodeBookConfig.N2     = 4;
config.CodeBookConfig.cbMode = 1;
config.FileName              = "Layer4_Port32_N1_4_N2-4_c1.txt";

nPort = 2 * config.CodeBookConfig.N1 * config.CodeBookConfig.N2;  % 32

% ----------------------------------------------------------------------------
% Bước 1: Load toàn bộ codebook Type I từ file
% ----------------------------------------------------------------------------
fid = fopen(config.FileName, 'r');
if fid == -1, error('Cannot open file: %s', config.FileName); end

W_pool    = [];
pool_info = {};
totalPMI  = 0;

while ~feof(fid)
    info_line = fgetl(fid);
    if ~ischar(info_line), break; end
    if isempty(strtrim(info_line)), continue; end

    totalPMI = totalPMI + 1;
    pool_info{totalPMI} = info_line;

    W_temp = zeros(nPort, nLayers);
    for row = 1:nPort
        row_data = fgetl(fid);
        W_temp(row, :) = str2num(row_data);
    end
    W_pool(:, :, totalPMI) = W_temp;
end
fclose(fid);

fprintf('Loaded %d Type I precoders. W_pool: [%d x %d x %d]\n\n', ...
    totalPMI, size(W_pool,1), size(W_pool,2), size(W_pool,3));

% ----------------------------------------------------------------------------
% Bước 2: Sinh 1000 H theo Rayleigh fading [Nr x nPort]
% ----------------------------------------------------------------------------
H_all = (randn(Nr, nPort, numberOfUE) + ...
         1j*randn(Nr, nPort, numberOfUE)) / sqrt(2);

fprintf('Generated %d Rayleigh H [%d x %d], SNR = %d dB\n\n', ...
    numberOfUE, Nr, nPort, SNR_dB);

% ----------------------------------------------------------------------------
% Bước 3: Tìm PMI tốt nhất
% Tiêu chí: PMI = argmax_i  (SNR/nLayers) * ||H * W_i||²_F
% Với Type I, scale SNR không đổi thứ tự argmax
% nhưng norm_best trả về giá trị có nghĩa vật lý (effective SNR per layer)
% ----------------------------------------------------------------------------
PMI_best      = zeros(numberOfUE, 1);
norm_best     = zeros(numberOfUE, 1);
eff_SNR_best  = zeros(numberOfUE, 1);

for k = 1:numberOfUE
    H_k      = H_all(:, :, k);
    best_val = -inf;
    best_idx = 1;

    for i = 1:totalPMI
        HW  = H_k * W_pool(:, :, i);   % [Nr x nLayers]
        val = norm(HW, 'fro')^2;
        if val > best_val
            best_val = val;
            best_idx = i;
        end
    end

    PMI_best(k)     = best_idx - 1;
    norm_best(k)    = best_val;
    eff_SNR_best(k) = (SNR_linear / nLayers) * best_val;   % effective SNR
end

% ----------------------------------------------------------------------------
% Bước 4: In kết quả
% ----------------------------------------------------------------------------
fprintf('%-8s  %-6s  %-14s  %-14s  %s\n', ...
    'Index', 'PMI', '||HW||^2_F', 'Eff SNR (lin)', 'PMI Info');
fprintf('%s\n', repmat('-', 1, 80));
for k = 1:numberOfUE
    fprintf('%-8d  %-6d  %-14.4f  %-14.4f  %s\n', ...
        k, PMI_best(k), norm_best(k), eff_SNR_best(k), ...
        pool_info{PMI_best(k) + 1});
end

% ----------------------------------------------------------------------------
% Bước 5: Thống kê
% ----------------------------------------------------------------------------
fprintf('\nSNR = %d dB | Mean ||HW||^2_F = %.4f | Mean Eff SNR = %.4f (%.2f dB)\n', ...
    SNR_dB, mean(norm_best), mean(eff_SNR_best), ...
    10*log10(mean(eff_SNR_best)));

pmi_counts = histcounts(PMI_best, -0.5:1:totalPMI-0.5);

figure('Name', 'PMI Distribution');
bar(0:totalPMI-1, pmi_counts, 'FaceColor', [0.2 0.6 0.9], 'EdgeColor', 'white');
xlabel('PMI Index'); ylabel('Count');
title(sprintf('Type I PMI distribution — %d UE, SNR = %d dB', numberOfUE, SNR_dB));
grid on;

figure('Name', 'Effective SNR per UE');
plot(1:numberOfUE, 10*log10(eff_SNR_best), '.', ...
    'Color', [0.2 0.6 0.9], 'MarkerSize', 4);
xlabel('UE index'); ylabel('Effective SNR (dB)');
title('Effective SNR after Type I beamforming'); grid on;