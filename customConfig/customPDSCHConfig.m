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

        function [totalPTRS_RE] = calculateManualPTRSCount(obj)
            if ~obj.EnablePTRS
                totalPTRS_RE = 0;
                return;
            end
        end
    end

    methods (Access = public)

        function [G] = calculateManualG(obj)
            % --- 1. Basic Config ---
            numPRB = length(obj.PRBSet);
            numLayers = obj.NumLayers; 
            dmrsConfig = obj.DMRS;
            nSC = 12; 
            pdschLen = obj.SymbolAllocation(2);

            % --- 2. DMRS Symbol Count ---
            configAddPos = dmrsConfig.DMRSAdditionalPosition;
            if pdschLen < 4, m=0; elseif pdschLen < 8, m=1; elseif pdschLen < 10, m=2; else, m=3; end
            actualAddPos = min(configAddPos, m);
            numDMRSSymbols = 1 + actualAddPos; 
            if dmrsConfig.DMRSLength == 2, numDMRSSymbols = numDMRSSymbols * 2; end
            
            % --- 3. DMRS Overhead Per PRB ---
            cdmGroups = dmrsConfig.NumCDMGroupsWithoutData;
            if dmrsConfig.DMRSConfigurationType == 1, ov=6; else, ov=4; end
            overheadPerSym = cdmGroups * ov;
            dmrsOverhead_PerPRB = overheadPerSym * numDMRSSymbols;

            % --- 4. Calculate Total Reserved REs (Intersect logic) ---
            if isempty(obj.ReservedRE)
                numReversedRE = 0;
            else
                maxWidth = max(obj.PRBSet) * 12 + 1000;
                [k_res, l_res] = ind2sub([maxWidth, 14], obj.ReservedRE);
                
                min_k = min(obj.PRBSet) * 12 + 1;
                max_k = (max(obj.PRBSet) + 1) * 12;
                min_l = obj.SymbolAllocation(1) + 1; 
                max_l = obj.SymbolAllocation(1) + obj.SymbolAllocation(2);
                
                valid_k = (k_res >= min_k) & (k_res <= max_k);
                valid_l = (l_res >= min_l) & (l_res <= max_l);
                
                numReversedRE = sum(valid_k & valid_l);
            end

            % --- 5. Per PRB Calculation (FIXED HERE) ---
            totalRE_OnePRB = nSC * pdschLen;
            
            reAvailable_OnePRB = totalRE_OnePRB - dmrsOverhead_PerPRB; 

            % Apply 3GPP Rule (Floor 156)
            reData_PerPRB = min(156, reAvailable_OnePRB);
            
            % --- 6. Total Calculation ---
            totalReForPDSCH = reData_PerPRB * numPRB * numLayers;
            
            % --- 7. Subtract Holes (Reserved & PTRS) ---
            [totalPTRS_RE] = calculateManualPTRSCount(obj);
            
            totalReForPDSCH = totalReForPDSCH - totalPTRS_RE - numReversedRE;

            % --- 8. Final G ---
            switch obj.Modulation
                case 'QPSK',    Qm = 2;
                case '16QAM',   Qm = 4;
                case '64QAM',   Qm = 6;
                case '256QAM',  Qm = 8;
                case '1024QAM', Qm = 10;
                otherwise,      Qm = 2;
            end

            G = totalReForPDSCH * Qm;
        end
        
    end
end