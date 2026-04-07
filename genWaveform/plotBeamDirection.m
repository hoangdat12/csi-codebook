% % Khởi tạo ma trận W1 và W2
% W1 = [
%    0.1768 + 0.0000i   0.1768 + 0.0000i   0.1768 + 0.0000i   0.1768 + 0.0000i;
%   -0.1768 + 0.0000i   0.0000 - 0.1768i  -0.1768 + 0.0000i   0.0000 - 0.1768i;
%    0.1768 + 0.0000i  -0.1768 + 0.0000i   0.1768 + 0.0000i  -0.1768 + 0.0000i;
%   -0.1768 + 0.0000i   0.0000 + 0.1768i  -0.1768 + 0.0000i   0.0000 + 0.1768i;
%    0.0000 + 0.1768i   0.0000 + 0.1768i   0.0000 - 0.1768i   0.0000 - 0.1768i;
%    0.0000 - 0.1768i   0.1768 + 0.0000i   0.0000 + 0.1768i  -0.1768 + 0.0000i;
%    0.0000 + 0.1768i   0.0000 - 0.1768i   0.0000 - 0.1768i   0.0000 + 0.1768i;
%    0.0000 - 0.1768i  -0.1768 + 0.0000i   0.0000 + 0.1768i   0.1768 + 0.0000i
% ];

% W2 = [
%    0.1768 + 0.0000i   0.1768 + 0.0000i   0.1768 + 0.0000i   0.1768 + 0.0000i;
%    0.0000 + 0.1768i   0.1768 + 0.0000i   0.0000 + 0.1768i   0.1768 + 0.0000i;
%   -0.1768 + 0.0000i   0.1768 + 0.0000i  -0.1768 + 0.0000i   0.1768 + 0.0000i;
%    0.0000 - 0.1768i   0.1768 + 0.0000i   0.0000 - 0.1768i   0.1768 + 0.0000i;
%    0.0000 + 0.1768i   0.0000 + 0.1768i   0.0000 - 0.1768i   0.0000 - 0.1768i;
%   -0.1768 + 0.0000i   0.0000 + 0.1768i   0.1768 + 0.0000i   0.0000 - 0.1768i;
%    0.0000 - 0.1768i   0.0000 + 0.1768i   0.0000 + 0.1768i   0.0000 - 0.1768i;
%    0.1768 + 0.0000i   0.0000 + 0.1768i  -0.1768 + 0.0000i   0.0000 - 0.1768i
% ];

% % Thiết lập tham số
% theta = linspace(-pi/2, pi/2, 500); % Quét từ -90 đến 90 độ
% d_lambda = 0.5;                     % Khoảng cách ăng-ten d = lambda/2

% figure('Name', 'MIMO Beam Patterns', 'Position', [100, 100, 1000, 500]);

% % ==================== Vẽ ma trận W1 ====================
% subplot(1, 2, 1);
% polaraxes; hold on;
% for col = 1:4
%     w = W1(:, col);
%     w_pol1 = w(1:4); % 4 port cho phân cực 1
%     w_pol2 = w(5:8); % 4 port cho phân cực 2
    
%     AF_pol1 = zeros(size(theta));
%     AF_pol2 = zeros(size(theta));
    
%     % Tính Array Factor (AF) cho từng phần tử
%     for n = 0:3
%         phase_shift = 2 * pi * d_lambda * n * sin(theta);
%         AF_pol1 = AF_pol1 + w_pol1(n+1) * exp(1i * phase_shift);
%         AF_pol2 = AF_pol2 + w_pol2(n+1) * exp(1i * phase_shift);
%     end
    
%     % Tổng hợp công suất (dB)
%     Total_Pattern = abs(AF_pol1).^2 + abs(AF_pol2).^2;
%     Pattern_dB = 10 * log10(Total_Pattern + 1e-10);
    
%     % Cắt sàn nhiễu ở -20dB để đồ thị gọn gàng
%     Pattern_dB = max(Pattern_dB, -20); 
    
%     polarplot(theta, Pattern_dB, 'LineWidth', 1.5, 'DisplayName', ['Cột ', num2str(col)]);
% end

% % Format đồ thị W1
% ax = gca;
% ax.ThetaZeroLocation = 'top';     % 0 độ chĩa lên trên
% ax.ThetaDir = 'clockwise';        % Chiều dương theo chiều kim đồng hồ
% ax.ThetaLim = [-90 90];           % Chỉ hiển thị từ -90 tới 90 độ
% ax.RLim = [-20 5];                % Giới hạn bán kính dB
% title('Hướng Beam - Ma trận W1');
% legend('Location', 'best');
% hold off;

% % ==================== Vẽ ma trận W2 ====================
% subplot(1, 2, 2);
% polaraxes; hold on;
% for col = 1:4
%     w = W2(:, col);
%     w_pol1 = w(1:4);
%     w_pol2 = w(5:8);
    
%     AF_pol1 = zeros(size(theta));
%     AF_pol2 = zeros(size(theta));
    
%     for n = 0:3
%         phase_shift = 2 * pi * d_lambda * n * sin(theta);
%         AF_pol1 = AF_pol1 + w_pol1(n+1) * exp(1i * phase_shift);
%         AF_pol2 = AF_pol2 + w_pol2(n+1) * exp(1i * phase_shift);
%     end
    
%     Total_Pattern = abs(AF_pol1).^2 + abs(AF_pol2).^2;
%     Pattern_dB = 10 * log10(Total_Pattern + 1e-10);
%     Pattern_dB = max(Pattern_dB, -20);
    
%     polarplot(theta, Pattern_dB, 'LineWidth', 1.5, 'DisplayName', ['Cột ', num2str(col)]);
% end

% % Format đồ thị W2
% ax = gca;
% ax.ThetaZeroLocation = 'top';
% ax.ThetaDir = 'clockwise';
% ax.ThetaLim = [-90 90];
% ax.RLim = [-20 5];
% title('Hướng Beam - Ma trận W2');
% legend('Location', 'best');
% hold off;

W1 = [
   0.1250 + 0.0000i   0.1250 + 0.0000i   0.1250 + 0.0000i   0.1250 + 0.0000i;
   0.0000 - 0.1250i   0.0000 - 0.1250i   0.0000 - 0.1250i   0.0000 - 0.1250i;
   0.0884 - 0.0884i   0.0884 - 0.0884i   0.0884 - 0.0884i   0.0884 - 0.0884i;
  -0.0884 - 0.0884i  -0.0884 - 0.0884i  -0.0884 - 0.0884i  -0.0884 - 0.0884i;
   0.0000 - 0.1250i   0.0000 - 0.1250i   0.0000 - 0.1250i   0.0000 - 0.1250i;
  -0.1250 + 0.0000i  -0.1250 + 0.0000i  -0.1250 + 0.0000i  -0.1250 + 0.0000i;
  -0.0884 - 0.0884i  -0.0884 - 0.0884i  -0.0884 - 0.0884i  -0.0884 - 0.0884i;
  -0.0884 + 0.0884i  -0.0884 + 0.0884i  -0.0884 + 0.0884i  -0.0884 + 0.0884i;
   0.0000 - 0.1250i   0.0000 - 0.1250i   0.0000 - 0.1250i   0.0000 - 0.1250i;
  -0.1250 + 0.0000i  -0.1250 + 0.0000i  -0.1250 + 0.0000i  -0.1250 + 0.0000i;
  -0.0884 - 0.0884i  -0.0884 - 0.0884i  -0.0884 - 0.0884i  -0.0884 - 0.0884i;
  -0.0884 + 0.0884i  -0.0884 + 0.0884i  -0.0884 + 0.0884i  -0.0884 + 0.0884i;
   0.1250 + 0.0000i   0.1250 + 0.0000i   0.1250 + 0.0000i   0.1250 + 0.0000i;
   0.0000 - 0.1250i   0.0000 - 0.1250i   0.0000 - 0.1250i   0.0000 - 0.1250i;
   0.0884 - 0.0884i   0.0884 - 0.0884i   0.0884 - 0.0884i   0.0884 - 0.0884i;
  -0.0884 - 0.0884i  -0.0884 - 0.0884i  -0.0884 - 0.0884i  -0.0884 - 0.0884i
];

W2 = [
    0.1250 + 0.0000i   0.1250 + 0.0000i   0.1250 + 0.0000i   0.1250 + 0.0000i;
   0.0000 - 0.1250i   0.0000 - 0.1250i   0.0000 - 0.1250i   0.0000 - 0.1250i;
  -0.0884 + 0.0884i  -0.0884 + 0.0884i  -0.0884 + 0.0884i  -0.0884 + 0.0884i;
   0.0884 + 0.0884i   0.0884 + 0.0884i   0.0884 + 0.0884i   0.0884 + 0.0884i;
   0.0884 - 0.0884i   0.0884 - 0.0884i   0.0884 - 0.0884i   0.0884 - 0.0884i;
  -0.0884 - 0.0884i  -0.0884 - 0.0884i  -0.0884 - 0.0884i  -0.0884 - 0.0884i;
   0.0000 + 0.1250i   0.0000 + 0.1250i   0.0000 + 0.1250i   0.0000 + 0.1250i;
   0.1250 + 0.0000i   0.1250 + 0.0000i   0.1250 + 0.0000i   0.1250 + 0.0000i;
  -0.1250 + 0.0000i  -0.1250 + 0.0000i  -0.1250 + 0.0000i  -0.1250 + 0.0000i;
   0.0000 + 0.1250i   0.0000 + 0.1250i   0.0000 + 0.1250i   0.0000 + 0.1250i;
   0.0884 - 0.0884i   0.0884 - 0.0884i   0.0884 - 0.0884i   0.0884 - 0.0884i;
  -0.0884 - 0.0884i  -0.0884 - 0.0884i  -0.0884 - 0.0884i  -0.0884 - 0.0884i;
   0.0884 - 0.0884i   0.0884 - 0.0884i   0.0884 - 0.0884i   0.0884 - 0.0884i;
  -0.0884 - 0.0884i  -0.0884 - 0.0884i  -0.0884 - 0.0884i  -0.0884 - 0.0884i;
   0.0000 + 0.1250i   0.0000 + 0.1250i   0.0000 + 0.1250i   0.0000 + 0.1250i;
   0.1250 + 0.0000i   0.1250 + 0.0000i   0.1250 + 0.0000i   0.1250 + 0.0000i
];

W3 = [
    0.1250 + 0.0000i   0.1250 + 0.0000i   0.1250 + 0.0000i   0.1250 + 0.0000i;
   0.0000 + 0.1250i   0.0000 + 0.1250i   0.0000 + 0.1250i   0.0000 + 0.1250i;
   0.0000 - 0.1250i   0.0000 - 0.1250i   0.0000 - 0.1250i   0.0000 - 0.1250i;
   0.1250 + 0.0000i   0.1250 + 0.0000i   0.1250 + 0.0000i   0.1250 + 0.0000i;
  -0.0884 - 0.0884i  -0.0884 - 0.0884i  -0.0884 - 0.0884i  -0.0884 - 0.0884i;
   0.0884 - 0.0884i   0.0884 - 0.0884i   0.0884 - 0.0884i   0.0884 - 0.0884i;
  -0.0884 + 0.0884i  -0.0884 + 0.0884i  -0.0884 + 0.0884i  -0.0884 + 0.0884i;
  -0.0884 - 0.0884i  -0.0884 - 0.0884i  -0.0884 - 0.0884i  -0.0884 - 0.0884i;
  -0.1250 + 0.0000i  -0.1250 + 0.0000i  -0.1250 + 0.0000i  -0.1250 + 0.0000i;
   0.0000 - 0.1250i   0.0000 - 0.1250i   0.0000 - 0.1250i   0.0000 - 0.1250i;
   0.0000 + 0.1250i   0.0000 + 0.1250i   0.0000 + 0.1250i   0.0000 + 0.1250i;
  -0.1250 + 0.0000i  -0.1250 + 0.0000i  -0.1250 + 0.0000i  -0.1250 + 0.0000i;
  -0.0884 - 0.0884i  -0.0884 - 0.0884i  -0.0884 - 0.0884i  -0.0884 - 0.0884i;
   0.0884 - 0.0884i   0.0884 - 0.0884i   0.0884 - 0.0884i   0.0884 - 0.0884i;
  -0.0884 + 0.0884i  -0.0884 + 0.0884i  -0.0884 + 0.0884i  -0.0884 + 0.0884i;
  -0.0884 - 0.0884i  -0.0884 - 0.0884i  -0.0884 - 0.0884i  -0.0884 - 0.0884i
];

plotBeamPatternMIMO(W1, W2, W3);

function plotBeamPatternMIMO(W1, W2, W3)
    % Hàm vẽ Beam Pattern cho ma trận Precoding [16 x 4] (16 ports, 4 layers)
    % Đầu vào W1, W2, W3 là các ma trận kích thước 16x4
    
    % 1. Cài đặt các thông số mảng anten (ULA 8 phần tử, Dual-Polarized)
    N_elements = 8;
    theta_deg = -90:0.5:90; % Quét góc từ -90 độ đến 90 độ
    theta_rad = deg2rad(theta_deg);
    
    % 2. Tính toán búp sóng cho từng UE
    pat_W1 = calculateTotalPattern(W1, theta_rad, N_elements);
    pat_W2 = calculateTotalPattern(W2, theta_rad, N_elements);
    pat_W3 = calculateTotalPattern(W3, theta_rad, N_elements);
    
    % ==========================================
    % 3. Vẽ đồ thị
    % ==========================================
    figure('Name', 'MIMO 4-Layer Beam Patterns', 'Position', [100, 100, 1000, 450]);
    
    % --- Đồ thị 1: Cartesian View (Tọa độ Đề-các) ---
    subplot(1, 2, 1);
    plot(theta_deg, pat_W1, 'LineWidth', 2); hold on;
    plot(theta_deg, pat_W2, 'LineWidth', 2);
    plot(theta_deg, pat_W3, 'LineWidth', 2);
    grid on;
    xlim([-90 90]);
    ylim([-30 2]);
    xlabel('Azimuth Angle (Degree)', 'FontWeight', 'bold');
    ylabel('Normalized Gain (dB)', 'FontWeight', 'bold');
    title('Beam Pattern - Cartesian View');
    legend('W1 (UE 1)', 'W2 (UE 2)', 'W3 (UE 3)', 'Location', 'south');
    
    % --- Đồ thị 2: Polar View (Tọa độ Cực) ---
    subplot(1, 2, 2);
    % Sử dụng polaraxes cho MATLAB đời mới
    ax = polaraxes;
    polarplot(ax, theta_rad, pat_W1, 'LineWidth', 2); hold on;
    polarplot(ax, theta_rad, pat_W2, 'LineWidth', 2);
    polarplot(ax, theta_rad, pat_W3, 'LineWidth', 2);
    
    % Xoay đồ thị cực cho hướng 0 độ chỉ lên trên (giống ăng ten trạm gốc)
    ax.ThetaZeroLocation = 'top';
    ax.ThetaDir = 'clockwise';
    ax.ThetaLim = [-90 90]; % Chỉ hiển thị nửa trên mặt phẳng
    ax.RLim = [-30 0];      % Giới hạn dải dB
    
    title('Beam Pattern - Polar View');
    legend('W1 (UE 1)', 'W2 (UE 2)', 'W3 (UE 3)', 'Location', 'southoutside', 'Orientation', 'horizontal');
end

% =========================================================================
% HÀM PHỤ: Tính tổng công suất búp sóng của 4 Layers
% =========================================================================
function pat_db = calculateTotalPattern(W, angles_rad, N_elements)
    num_layers = size(W, 2);
    pattern_linear = zeros(1, length(angles_rad));
    
    % Duyệt qua từng layer (từng cột của ma trận W)
    for layer = 1:num_layers
        w_layer = W(:, layer);
        
        % Tách 16 ports thành 2 phân cực
        w_pol1 = w_layer(1:N_elements);
        w_pol2 = w_layer(N_elements+1:end);
        
        % Tính công suất cho layer hiện tại ở tất cả các góc
        for i = 1:length(angles_rad)
            theta = angles_rad(i);
            % Vector lái (Steering vector) cho ULA d = lambda/2
            a = exp(1j * pi * (0:N_elements-1)' * sin(theta)); 
            
            gain_pol1 = abs(a' * w_pol1)^2;
            gain_pol2 = abs(a' * w_pol2)^2;
            
            % Cộng dồn công suất của layer này vào tổng
            pattern_linear(i) = pattern_linear(i) + gain_pol1 + gain_pol2;
        end
    end
    
    % Chuyển sang dB và chuẩn hóa đỉnh về 0 dB
    pat_db = 10 * log10(pattern_linear + 1e-10);
    pat_db = pat_db - max(pat_db);
end