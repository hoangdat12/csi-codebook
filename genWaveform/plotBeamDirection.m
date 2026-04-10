function plotBeamDirection(W1, N1, N2)
    [angles_az, gains_az] = getBeamPattern('azimuth', W1, N1, N2, 360);
    [angles_el, gains_el] = getBeamPattern('elevation', W1, N1, N2, 180);
    
    floor_dB = -40; 
    gains_az_db = max(20 * log10(max(gains_az, 1e-10)), floor_dB);
    gains_el_db = max(20 * log10(max(gains_el, 1e-10)), floor_dB);
    
    figure('Name', 'Antenna Beam Pattern (dB Scale)', 'Position', [100, 100, 900, 400]);
    
    % Azimuth
    subplot(1, 2, 1);
    polarplot(angles_az, gains_az_db, 'b-', 'LineWidth', 1.5);
    title('Azimuth (XY)');
    ax = gca;
    ax.ThetaZeroLocation = 'right';
    ax.ThetaDir = 'clockwise';     % ✅ khớp canvas JS
    rlim([floor_dB 0]);
    
    % Elevation
    subplot(1, 2, 2);
    angles_el_js = angles_el - pi/2;  % giữ nguyên vì JS cũng trừ pi/2
    polarplot(angles_el_js, gains_el_db, 'r-', 'LineWidth', 1.5);
    title('Elevation (XZ)');
    ax = gca;
    ax.ThetaZeroLocation = 'right';
    ax.ThetaDir = 'clockwise';     % ✅ khớp canvas JS
    rlim([floor_dB 0]);
end

% =========================================================================
% 2. DATA GENERATOR: Quét góc và trả về mảng dữ liệu
function [angles, gains] = getBeamPattern(type, weights, N1, N2, steps)
    if nargin < 5
        steps = 180;
    end
    
    % Khởi tạo mảng (để tăng tốc độ)
    angles = zeros(1, steps + 1);
    gains = zeros(1, steps + 1);
    TAU = 2 * pi;
    
    for i = 0:steps
        if strcmp(type, 'azimuth')
            theta = pi / 2;           % Cố định mặt phẳng XY
            phi = (i / steps) * TAU;  % Quét 360 độ
            angleToLog = phi;
        else % 'elevation'
            theta = (i / steps) * pi; % Quét 180 độ
            phi = 0;                  % Cố định mặt phẳng XZ
            angleToLog = theta;
        end
        
        % Tính Gain tại góc này
        gain = calculateGain(theta, phi, weights, N1, N2);
        
        % Lưu kết quả (MATLAB index bắt đầu từ 1)
        angles(i + 1) = angleToLog;
        gains(i + 1) = gain;
    end
end

% =========================================================================
% 1. ENGINE VẬT LÝ: Tính toán sức mạnh (Gain)
function gain = calculateGain(theta, phi, weights, N1, N2)
    pol0 = 0; % Số phức tổng cho phân cực 0
    pol1 = 0; % Số phức tổng cho phân cực 1
    nPortsPerPol = N1 * N2;
    
    for n1 = 0:(N1 - 1)
        for n2 = 0:(N2 - 1)
            % Độ lệch pha không gian
            spatialPhase = pi * (n1 * sin(theta) * cos(phi) + n2 * cos(theta));
            
            % Chuyển đổi pha thành số phức
            % 1i trong MATLAB đại diện cho số phức j
            e = exp(1i * spatialPhase); 
            
            % Chỉ số mảng (lưu ý: JS bắt đầu từ 0, MATLAB bắt đầu từ 1)
            idx = (n1 * N2) + n2 + 1;
            
            % Nhóm phân cực 1
            t0 = weights(idx) * e;
            pol0 = pol0 + t0;
            
            % Nhóm phân cực 2
            t1 = weights(nPortsPerPol + idx) * e;
            pol1 = pol1 + t1;
        end
    end
    
    % Trả về tổng biên độ (Gain) đã chuẩn hóa
    % abs() trong MATLAB tính module của số phức (tương đương sqrt(re^2 + im^2))
    totalPower = abs(pol0)^2 + abs(pol1)^2;
    gain = sqrt(totalPower);
end