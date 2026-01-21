classdef customPDSCHConfig < nrPDSCHConfig
    % CUSTOMPDSCHCONFIG: Class mở rộng để chứa thêm CodeRate, PMI, RV
    
    properties
        % --- 1. Tham số cho Lập lịch (Scheduling) & Mã hóa ---
        
        % Target Code Rate (R): Dùng để chọn BaseGraph LDPC
        TargetCodeRate (1,1) double {mustBeInRange(TargetCodeRate, 0, 1)} = 490/1024;
        
        % Redundancy Version (rv): Dùng cho Rate Matching (0,1,2,3)
        RedundancyVersion (1,1) double {mustBeMember(RedundancyVersion, [0, 1, 2, 3])} = 0;
        
        % --- 2. Tham số cho MIMO / Precoding ---
        
        % PMI (Precoding Matrix Indicator)
        PMI = 0; 
        
        % Cấu hình Codebook (Số anten phát, loại codebook...)
        CodebookConfig struct = struct('NumTxAntennas', 4, 'CodebookType', 'Type1SinglePanel');
    end

    properties (Dependent)
        % MCS Index: Khi bạn set cái này, CodeRate và Modulation sẽ tự nhảy theo
        MCSIndex
    end

    properties (Access = private)
        pMCSIndex (1,1) double = 0; % Biến ẩn lưu giá trị MCS
    end

    methods
        % --- CONSTRUCTOR ---
        function obj = customPDSCHConfig()
            % Gọi constructor của lớp cha (nrPDSCHConfig)
            obj@nrPDSCHConfig();
            
            % Set giá trị mặc định ban đầu
            obj.Modulation = 'QPSK';
            obj.TargetCodeRate = 490/1024; % Tương đương MCS 13 (QPSK)
        end

        % --- SETTER: Logic tự động cập nhật ---
        function set.MCSIndex(obj, val)
            % 1. Lưu giá trị MCS
            obj.pMCSIndex = val;
            
            % 2. Tra bảng để lấy Modulation và CodeRate tương ứng
            [mod, rate] = obj.lookupMCS(val);
            
            % 3. Cập nhật vào thuộc tính (Modulation là của lớp cha, Rate là của lớp con)
            obj.Modulation = mod;          
            obj.TargetCodeRate = rate;     
        end

        % --- GETTER ---
        function val = get.MCSIndex(obj)
            val = obj.pMCSIndex;
        end
    end

    methods (Access = private)
        function [modType, codeRate] = lookupMCS(~, mcsIndex)
            % Bảng MCS chuẩn 3GPP TS 38.214 Table 5.1.3.1-1 (PDSCH Mapping Type A)
            % [Index | Modulation Order Qm | Target Code Rate x 1024]
            persistent mcsTable
            if isempty(mcsTable)
                mcsTable = [
                    0   2   120;  1   2   157;  2   2   193;  3   2   251;  4   2   308;
                    5   2   379;  6   2   449;  7   2   526;  8   2   602;  9   2   679;
                    10  4   340;  11  4   378;  12  4   434;  13  4   490;  14  4   553;
                    15  4   616;  16  4   658;  17  6   438;  18  6   466;  19  6   517;
                    20  6   567;  21  6   616;  22  6   666;  23  6   719;  24  6   772;
                    25  6   822;  26  6   873;  27  6   910;  28  6   948
                ];
            end
            
            % Tìm dòng chứa MCS Index
            idx = find(mcsTable(:,1) == mcsIndex, 1);
            if isempty(idx)
                % Fallback nếu nhập sai
                idx = 1; 
            end
            
            Qm = mcsTable(idx, 2);
            R_val = mcsTable(idx, 3);
            
            codeRate = R_val / 1024;
            
            switch Qm
                case 2, modType = 'QPSK';
                case 4, modType = '16QAM';
                case 6, modType = '64QAM';
                case 8, modType = '256QAM';
            end
        end

        function [G] = calculateManualG(obj)
            numPRB = length(obj.PRBSet);
            numSymbols = obj.SymbolAllocation(2); 

            % Total RE allocation
            totalAllocationRE = numPRB * 12 * numSymbols;

            % Total DMRS occupied
            dmrsConfig = obj.DMRS;

            dmrsConfigType = dmrsConfig.DMRSConfigurationType;
            dmrsMaxLength = dmrsConfig.DMRSLength;
            dmrsAdditionalPosition = dmrsConfig.DMRSAdditionalPosition;
            
            if dmrsConfigType == 1
                rePerGroup = 6;
            elseif dmrsConfigType == 2
                rePerGroup = 4;
            else
                error('Invalid DMRS config type');
            end

            rePerRBPerSymbol = rePerGroup * dmrsConfig.NumCDMGroupsWithoutData;

            % Number of DMRS symbols in time
            % Base symbol = 1
            % additionalPosition adds more
            totalDmrSymbols = (1 + dmrsAdditionalPosition) * dmrsMaxLength;

            % Total DMRS RE
            totalREOfDMRS = numPRB* totalDmrSymbols * rePerRBPerSymbol;

            % Total PTRS occupied

            % Total Reversed RE

            % Total ...

            switch obj.Modulation
                case 'QPSK',    Qm = 2;
                case '16QAM',   Qm = 4;
                case '64QAM',   Qm = 6;
                case '256QAM',  Qm = 8;
                case '1024QAM', Qm = 10;
                otherwise,      Qm = 2;
            end

            % Total RE for PDSCH
            totalDataRE = totalAllocationRE - totalREOfDMRS;

            % The total RE is limited by min(156, totalDataRE)
            totalDataREActual = min(156, totalDataRE);

            % The maximum bit
            G = totalDataREActual * Qm;
        end
        
    end
end