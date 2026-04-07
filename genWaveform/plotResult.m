% ================================
% Plot EVM vs SNR for PDSCH
% ================================

clc; clear; close all;

% Dữ liệu
SNR = 10:5:30;  % dB
EVM = [6.041 4.187 2.404 1.348 0.758];  % %

% Vẽ hình
figure;
plot(SNR, EVM, '-o', 'LineWidth', 2, 'MarkerSize', 8);
grid on;

% Nhãn
xlabel('SNR (dB)');
ylabel('EVM (%)');
title('EVM vs SNR for PDSCH');

% Hiển thị giá trị trên từng điểm
for i = 1:length(SNR)
    text(SNR(i), EVM(i), sprintf('%.3f', EVM(i)), ...
        'VerticalAlignment', 'bottom', ...
        'HorizontalAlignment', 'center');
end

% Giới hạn trục (optional)
xlim([8 32]);
ylim([0 max(EVM)+1]);
