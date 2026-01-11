% % % --- 1. CẤU HÌNH THAM SỐ CƠ BẢN ---
% % nLayers = 4;
% % L = 4;
% % Mv = 4;
% % TotalBits = 2 * L * Mv; % = 32 bit
% % N3 = 20; % Đặt > 19 để test nhánh 'else' (đầy đủ tham số)

% % % --- 2. TẠO DỮ LIỆU GIẢ LẬP CHO PART 1 (i1) ---
% % % i1 = {i11, i12, i15, i16, i17, i18}

% % % i11, i12, i15, i16 (Dữ liệu nền, không ảnh hưởng logic chính)
% % i11 = [1 1]; 
% % i12 = [2 2];
% % i15 = 1; 
% % i16Reported = cell(nLayers, 1); % Dummy

% % % --- QUAN TRỌNG: TẠO i18 (CHỈ SỐ HỆ SỐ MẠNH NHẤT - 0 BASED) ---
% % % Layer 1: Mạnh nhất tại 0 (Đầu tiên)
% % % Layer 2: Mạnh nhất tại 4 
% % % Layer 3: Mạnh nhất tại 10
% % % Layer 4: Mạnh nhất tại 31 (Cuối cùng)
% % i18Reported = {0; 4; 10; 31}; 

% % % --- QUAN TRỌNG: TẠO i17 (BITMAP) ---
% % i17Reported = cell(nLayers, 1);

% % % Layer 1: Mạnh nhất tại 0. Các hệ số khác tại 2, 5.
% % % (Lưu ý: Trong Matlab index bắt đầu từ 1, nên index 0 của 3GPP là phần tử số 1)
% % bmp1 = zeros(1, 32); bmp1([1, 3, 6]) = 1; 
% % i17Reported{1} = bmp1; 
% % % => Knz=3. Trừ strongest còn 2 giá trị cần báo cáo.

% % % Layer 2: Mạnh nhất tại 4 (Matlab idx 5). Các hệ số khác tại 0, 1.
% % bmp2 = zeros(1, 32); bmp2([1, 2, 5]) = 1;
% % i17Reported{2} = bmp2;
% % % => Knz=3. Trừ strongest còn 2 giá trị.

% % % Layer 3: Mạnh nhất tại 10 (Matlab idx 11). Chỉ có thêm 1 hệ số tại 12.
% % bmp3 = zeros(1, 32); bmp3([11, 13]) = 1;
% % i17Reported{3} = bmp3;
% % % => Knz=2. Trừ strongest còn 1 giá trị.

% % % Layer 4: Mạnh nhất tại 31 (Matlab idx 32). Các hệ số khác tại 29, 30.
% % bmp4 = zeros(1, 32); bmp4([30, 31, 32]) = 1;
% % i17Reported{4} = bmp4;
% % % => Knz=3. Trừ strongest còn 2 giá trị.

% % % Đóng gói i1
% % i1 = {i11, i12, i15, i16Reported, i17Reported, i18Reported};

% % % --- 3. TẠO DỮ LIỆU GIẢ LẬP CHO PART 2 (i2) ---
% % % i2 = {i23, i24, i25}

% % % i23 (Wideband Amplitude)
% % i23Reported = [12; 10; 8; 14]; % 4 giá trị cho 4 lớp

% % % i24 (Subband Amplitude - Stream nén) & i25 (Phase)
% % % Lưu ý: Số lượng phần tử phải khớp với (Knz - 1)
% % i24Reported = cell(nLayers, 1);
% % i25Reported = cell(nLayers, 1);

% % % Layer 1 (Bitmap 1 tại 0, 2, 5. Strongest tại 0. Còn lại 2, 5)
% % i24Reported{1} = [3, 5]; 
% % i25Reported{1} = [1, 2];

% % % Layer 2 (Bitmap 1 tại 0, 1, 4. Strongest tại 4. Còn lại 0, 1)
% % i24Reported{2} = [2, 4]; % Giá trị cho vị trí 0 và 1
% % i25Reported{2} = [6, 7];

% % % Layer 3 (Bitmap 1 tại 10, 12. Strongest tại 10. Còn lại 12)
% % i24Reported{3} = [6];
% % i25Reported{3} = [3];

% % % Layer 4 (Bitmap 1 tại 29, 30, 31. Strongest tại 31. Còn lại 29, 30)
% % i24Reported{4} = [1, 2];
% % i25Reported{4} = [0, 4];

% % % Đóng gói i2
% % i2 = {i23Reported, i24Reported, i25Reported};

% % % --- 4. GỌI HÀM KIỂM TRA ---
% % fprintf('--- Bắt đầu chạy test ---\n');
% % [~, ~, ~, ~, i17_out, i18_out, i23_out, i24_out, i25_out] = computeInputs_3D(i1, i2, nLayers, N3, 4, 4)

% % % --- 5. HIỂN THỊ KẾT QUẢ ĐỂ KIỂM TRA ---

% clear; clc;

% %% 1. Cấu hình (Configuration)
% nLayers = 4; % Rank = 4

% % Cấu hình Codebook (ParamCombination = 4 -> L=4, Beta=1/2)
% cfg.CodeBookConfig.CodebookType = 'typeII-r16';
% cfg.CodeBookConfig.N1 = 4;
% cfg.CodeBookConfig.N2 = 4; 
% cfg.CodeBookConfig.ParamCombination = 4; 
% cfg.CodeBookConfig.NumberOfPMISubbandsPerCQISubband = 1; % R = 1
% cfg.CodeBookConfig.TypeIIRIRestriction = []; 
% cfg.CodeBookConfig.SubbandAmplitude = true;
% cfg.CodebookConfig.O1 = 4;
% cfg.CodebookConfig.O2 = 4;

% % Cấu hình Grid (Để ra N3 = 32)
% cfg.CSIReportConfig.SubbandSize = 4; 
% cfg.CarrierConfig.NStartGrid = 0;
% cfg.CarrierConfig.NSizeGrid = 128; 

% %% 2. Tạo i1 (Part 1)
% % N3 = 32, L = 4, Mv = 4 -> Bitmap Length = 32
% bitmap_len = 32;

% % i1{1}: q1, q2 (Chỉ có 2 giá trị)
% i1{1} = [1, 2]; 

% % i1{2}: i12 (Spatial index)
% i1{2} = 0; 

% % i1{3}: i15 (M_initial - window start)
% i1{3} = 0; 

% % i1{4}: i16 (Frequency basis indices - Combinatorial)
% i1{4} = randi([0, 34], nLayers, 1); %

% % i1{5}: i17 (Bitmap)
% i1_7_cell = cell(nLayers, 1);
% num_nz_per_layer = zeros(nLayers, 1);
% rng(42); % Seed cố định
% for l = 1:nLayers
%     bits = zeros(1, bitmap_len);
%     perm = randperm(bitmap_len, 8); % Random 8 bit 1
%     bits(perm) = 1;
%     i1_7_cell{l} = bits;
%     num_nz_per_layer(l) = sum(bits);
% end
% i1{5} = i1_7_cell;

% % i1{6}: i18 (Strongest coefficient indicator)
% i1_8_cell = cell(nLayers, 1);
% for l = 1:nLayers
%     i1_8_cell{l} = randi([0, 7]); % Random beam index 0-7
% end
% i1{6} = i1_8_cell;

% %% 3. Tạo i2 (Part 2)
% % i2{1}: i23 (Wideband Amp - p1)
% i2{1} = randi([1, 15], nLayers, 2); 

% % i2{2} (Subband Amp) & i2{3} (Phase)
% i2_4_cell = cell(nLayers, 1);
% i2_5_cell = cell(nLayers, 1);

% for l = 1:nLayers
%     % Stream length = Số bit 1 trong bitmap trừ đi 1 (strongest)
%     stream_len = max(0, num_nz_per_layer(l) - 1);
    
%     i2_4_cell{l} = randi([0, 7], 1, stream_len);  
%     i2_5_cell{l} = randi([0, 15], 1, stream_len); 
% end

% i2{2} = i2_4_cell;
% i2{3} = i2_5_cell;

% W = generateEnhancedTypeIIPrecoder(cfg, nLayers, i1, i2);
% disp(W);

%% Case 2
% 1. Cấu hình (Configuration)
nLayers = 1;

%Cấu hình Codebook (ParamCombination = 4 -> L=4, Beta=1/2)
cfg.CodeBookConfig.CodebookType = 'typeII-r16';
cfg.CodeBookConfig.N1 = 4;
cfg.CodeBookConfig.N2 = 2; 
cfg.CodeBookConfig.ParamCombination = 4; 
cfg.CodeBookConfig.NumberOfPMISubbandsPerCQISubband = 1; % R = 2
cfg.CodeBookConfig.TypeIIRIRestriction = []; 
cfg.CodeBookConfig.SubbandAmplitude = true;
cfg.CodebookConfig.O1 = 4;
cfg.CodebookConfig.O2 = 4;

% Cấu hình Grid (Để ra N3 = 32)
cfg.CSIReportConfig.SubbandSize = 8; 
cfg.CarrierConfig.NStartGrid = 0;
cfg.CarrierConfig.NSizeGrid = 128; 

N3 = 16; Mv = 4; L = 4;

% Dữ liệu Part 1
i11 = [1, 2]; 
i12 = 5; 
i15 = 0; 
i16 = [4];

bitmap_vec = [0 0 0 1 0 0 0 0, 0 0 0 0 0 0 0 0, 1 1 0 0 0 0 0 0, 0 0 0 0 0 0 1 0];
i17 = {bitmap_vec};              

i18 = {[0]}; 

i23 = {[3]};          
i24 = {[3, 2, 4]};   
i25 = {[1, 9, 11]};  

if N3 <= 19
    i1 = {i11, i12, i16, i17, i18}; 
else
    i1 = {i11, i12, i15, i16, i17, i18}; 
end

% [i11, i12, i15, i16, i17, i18, i23, i24, i25] = computeInputs(i1, i2, nLayers, N3, L, Mv)

W = generateEnhancedTypeIIPrecoder(cfg, nLayers, i1, i2)