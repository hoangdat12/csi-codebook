% % --- Cấu hình giả lập (Setup) ---

% setupPath();

% carrier = nrCarrierConfig;
% carrier.NSizeGrid = 52; % Kích thước tài nguyên của carrier

% pdsch = nrPDSCHConfig;
% pdsch.PRBSet = 0:25;
% pdsch.NStartBWP = 0;        % Bắt đầu BWP tại PRB 0
% pdsch.NSizeBWP = 52;        % Toàn bộ băng thông BWP
% pdsch.VRBBundleSize = 2;    % Kích thước cụm L_i [cite: 40]
% pdsch.VRBToPRBInterleaving = true;
% pdsch.DMRS.DMRSReferencePoint = 'CRB0';
% pdsch.PRBSetType = 'PRB';

% % Các biến hỗ trợ
% prbset = pdsch.PRBSet;
% nSizeBWP = pdsch.NSizeBWP;
% nrb = length(prbset);
% NStartGrid = carrier.NStartGrid;
% NStartBWP = pdsch.NStartBWP;
% DMRSReferencePoint = pdsch.DMRS.DMRSReferencePoint;

% % --- 1. MATLAB TOOLBOX CODE ---
% % Lấy điểm tham chiếu và thực hiện ánh xạ bằng hàm nội bộ của Toolbox
% rbrefpoint_matlab = nr5g.internal.pdsch.getRBReferencePoint(NStartGrid, NStartBWP, DMRSReferencePoint);
% mapIndices_matlab = nr5g.internal.pdsch.vrbToPRBInterleaver(nSizeBWP, rbrefpoint_matlab, double(pdsch.VRBBundleSize));

% mapMatrix = repmat(mapIndices_matlab,numel(prbset),1) == repmat(reshape(prbset,[],1),1,nSizeBWP);
% prbsetInterleave = mapIndices_matlab(any(mapMatrix,1));

% grid = ResourceGrid(carrier, 4);
% pdschIndices = nrPDSCHIndices(carrier, pdsch); 
% numRE = length(pdschIndices); 

% % Tạo dữ liệu ngẫu nhiên dựa trên số RE thực tế
% inSym = (randn(numRE, 1) + 1i*randn(numRE, 1)) / sqrt(2);
% mappingGrid = ResourceMapping(grid, inSym, pdsch, carrier);


% =====================================================================
% TÍNH TOÁN DM-RS DỰA TRÊN 3GPP TS 38.211 [cite: 1, 15]
% =====================================================================

% 1. Lấy thông tin cấu hình
dmrsConfig = pdsch.DMRS;
numPorts = pdsch.NumLayers;
SUBCARRIERS_PER_PRB = 12;

% Giả sử bạn đã có dmrsSymIdx (1-based) từ hàm lookup 
% và mappingGrid đã được khởi tạo theo kích thước [Subcarriers x Symbols x Ports]

% 2. Xác định mẫu Subcarrier cơ sở (Base REs) cho từng loại Configuration 
if dmrsConfig.DMRSConfigurationType == 1
    % Type 1: 6 RE mỗi PRB, cách nhau 1 SC 
    dmrs_base_pattern = [0, 2, 4, 6, 8, 10]; 
    shift_multiplier = 1;
    max_cdm_groups = 2;
else
    % Type 2: 4 RE mỗi PRB, đi theo cặp 
    dmrs_base_pattern = [0, 1, 6, 7]; 
    shift_multiplier = 2;
    max_cdm_groups = 3;
end

% 3. Xác định các nhóm CDM cần phải né (CDM groups without data) 
% Càng nhiều nhóm CDM, số lượng RE bị chiếm dụng càng tăng
numCDMGroups = min(dmrsConfig.NumCDMGroupsWithoutData, max_cdm_groups);

% 4. Vòng lặp tường minh qua từng thành phần của tài nguyên
for p = 1:numPorts
    for t = 1:length(dmrsSymIdx)
        currSym = dmrsSymIdx(t); % Biểu tượng OFDM chứa DM-RS
        
        % Chạy qua từng PRB sau khi đã xen kẽ (Interleaved PRBs) [cite: 22, 25]
        for idx = 1:length(prbsetInterleave)
            currentPRB = prbsetInterleave(idx);
            startSubc = currentPRB * SUBCARRIERS_PER_PRB; % SC đầu tiên của PRB này
            
            % Chạy qua từng nhóm CDM để đánh dấu RE "bận"
            for g = 0:(numCDMGroups - 1)
                delta_shift = g * shift_multiplier;
                
                % Chạy qua các vị trí RE của mẫu DM-RS
                for m = 1:length(dmrs_base_pattern)
                    % Tính chỉ số Subcarrier tuyệt đối (1-based cho MATLAB)
                    absoluteSubc = startSubc + dmrs_base_pattern(m) + delta_shift + 1;
                    
                    % Đánh dấu vào Grid (Ví dụ dùng -1 để ký hiệu DM-RS/Reserved)
                    if absoluteSubc <= size(mappingGrid, 1)
                        mappingGrid(absoluteSubc, currSym, p) = -1;
                    end
                end
            end
        end
    end
end