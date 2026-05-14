%% CSI Report — 32 port | 273 RB | 30kHz | TDL-C | Type I Single Panel
clc; clear; close all;

%% 1. CARRIER
carrier = nrCarrierConfig;
carrier.SubcarrierSpacing = 30;
carrier.NSizeGrid         = 273;
carrier.NStartGrid        = 0;
carrier.NSlot             = 0;
carrier.NFrame            = 0;

%% 2. CSI-RS — 32 port, Row 18
csirs = nrCSIRSConfig;
csirs.CSIRSType           = {'nzp', 'nzp'};
csirs.RowNumber           = [18 18];
csirs.Density             = {'one', 'one'};
csirs.SubcarrierLocations = {[0 2 4 6], [0 2 4 6]};
csirs.SymbolLocations     = {0, 5};
csirs.NumRB               = 273;
csirs.RBOffset            = 0;
csirs.CSIRSPeriod         = [4 0];

nTxAnts = max(csirs.NumCSIRSPorts);  % 32
nRxAnts = 4;  % 4 Rx anten (= max layer muốn đo)

fprintf('=== CSI-RS: Tx=%d | Rx=%d ===\n\n', nTxAnts, nRxAnts);

%% 3. REPORT CONFIG
reportConfig = nrCSIReportConfig;
reportConfig.NStartBWP               = 0;
reportConfig.NSizeBWP                = 273;
reportConfig.CodebookType            = 'Type1SinglePanel';
reportConfig.PanelDimensions         = [1 4 4];    % N1=4, N2=4 → 32 port
reportConfig.CodebookMode            = 1;
reportConfig.CQITable                = 'Table2';
reportConfig.CQIFormatIndicator      = 'Wideband';
reportConfig.SubbandSize             = 32;
reportConfig.PMIFormatIndicator      = 'Wideband';
reportConfig.RIRestriction           = [];
reportConfig.CodebookSubsetRestriction = [];
reportConfig.RIRestriction = [0 0 0 1 0 0 0 0];

%% 4. PDSCH DMRS
pdsch = nrPDSCHConfig;

%% 5. TẠO CSI-RS VÀ MAP VÀO GRID
csirsInd = nrCSIRSIndices(carrier, csirs);
csirsSym = nrCSIRS(carrier, csirs);

txGrid           = nrResourceGrid(carrier, nTxAnts);
txGrid(csirsInd) = csirsSym;

%% 6. OFDM MODULATE
OFDMInfo   = nrOFDMInfo(carrier);
txWaveform = nrOFDMModulate(carrier, txGrid);

fprintf('=== OFDM: Nfft=%d | SampleRate=%.2f MHz ===\n\n', ...
    OFDMInfo.Nfft, OFDMInfo.SampleRate/1e6);

%% 7. TDL CHANNEL
channel = nrTDLChannel;
channel.NumTransmitAntennas = nTxAnts;   % 32
channel.NumReceiveAntennas  = nRxAnts;   % 4
channel.SampleRate          = OFDMInfo.SampleRate;
channel.DelayProfile        = 'TDL-C';
channel.DelaySpread         = 300e-9;
channel.MaximumDopplerShift = 5;
channel.Seed                = 42;

chInfo     = info(channel);
maxChDelay = ceil(max(chInfo.PathDelays * OFDMInfo.SampleRate)) ...
             + chInfo.ChannelFilterDelay;

%% 8. QUA KÊNH
rxWaveform = channel([txWaveform; zeros(maxChDelay, nTxAnts)]);

%% 9. TIMING SYNC
offset     = nrTimingEstimate(carrier, rxWaveform, csirsInd, csirsSym);
rxWaveform = rxWaveform(1+offset:end, :);

%% 10. THÊM AWGN
SNRdB = 20;
SNR   = 10^(SNRdB/10);
sigma = 1 / sqrt(2.0 * nRxAnts * double(OFDMInfo.Nfft) * SNR);
rng('default');
noise      = sigma * complex(randn(size(rxWaveform)), randn(size(rxWaveform)));
rxWaveform = rxWaveform + noise;

%% 11. OFDM DEMODULATE
rxGrid = nrOFDMDemodulate(carrier, rxWaveform);

%% 12. CHANNEL ESTIMATE
% CDMLengths=[2 1]: FD-CDM2 cho Row 18
[H, nVar] = nrChannelEstimate(rxGrid, csirsInd, csirsSym, 'CDMLengths', [2 1]);

fprintf('H size : [%s]\n', num2str(size(H)));
fprintf('nVar   : %.4e\n\n', nVar);

%% 13. CSI REPORT
[CSIReport, CSIInfo] = nrCSIReportCSIRS(carrier, csirs, reportConfig, pdsch.DMRS, H, nVar);

%% 14. KẾT QUẢ
fprintf('===== CSI Report =====\n');
fprintf('RI           : %d\n',      CSIReport.RI);
fprintf('CQI wideband : %d\n',      CSIReport.CQI(1,1));
fprintf('PMI i1       : [%s]\n',    num2str(CSIReport.PMISet.i1));
fprintf('PMI i2 size  : [%s]\n',    num2str(size(CSIReport.PMISet.i2)));
fprintf('Eff. SINR    : %.2f dB\n', 10*log10(CSIInfo.EffectiveSINR));
fprintf('W size       : [%s]\n',    num2str(size(CSIInfo.W)));


%% Tra PMI index từ CSI Report output
% CSIReport.PMISet.i1 = [i11, i12, i13]  (1-based từ MATLAB)
% CSIReport.PMISet.i2 = [i2_sb1, i2_sb2, ...]  (1-based, mỗi subband 1 giá trị)

%% Tra PMI index từ CSI Report output
% MATLAB dùng 1-based → convert sang 0-based để tra file
i11 = CSIReport.PMISet.i1(1) - 1;
i12 = CSIReport.PMISet.i1(2) - 1;
i13 = CSIReport.PMISet.i1(3) - 1;
i2_sb = CSIReport.PMISet.i2 - 1;  % [1 x numSubbands], 0-based

% Tính PMI_Index tuyến tính
% Với N1=4, N2=4, O1=4, O2=4:
%   i11 ∈ [0..7]   (O1*N1 - 1 = 7)
%   i12 ∈ [0..15]  (O2*N2 - 1 = 15)
%   i13 ∈ [0..3]   (4 giá trị)
%   i2  ∈ [0..1]   (2 giá trị, CodebookMode=1, rank 4)
N_i12 = 16;  % O2*N2
N_i13 = 4;
N_i2  = 2;

pmi_index_wideband = i11*(N_i12*N_i13*N_i2) + i12*(N_i13*N_i2) + i13*N_i2 + i2_sb(1);

fprintf('i11=%d, i12=%d, i13=%d\n', i11, i12, i13);
fprintf('i2 per subband (0-based): [%s]\n', num2str(i2_sb));
fprintf('PMI_Index (wideband, 0-based) = %d\n', pmi_index_wideband);

%% Đọc W matrix từ file
fid = fopen('Layer4_Port32_N1_4_N2-4_c1.txt', 'r');
if fid == -1
    error('Không mở được file codebook');
end
lines = textscan(fid, '%s', 'Delimiter', '\n');
lines = lines{1};
fclose(fid);

%% Tìm header dòng tương ứng PMI_Index
target_str  = sprintf('PMI_Index: %d,', pmi_index_wideband);
header_line = find(contains(lines, target_str), 1);

if isempty(header_line)
    fprintf('Không tìm thấy PMI_Index=%d trong file\n', pmi_index_wideband);
else
    fprintf('\nTìm thấy tại dòng %d: %s\n', header_line, lines{header_line});

    %% Đọc 32 dòng tiếp theo = W matrix [32 port x 4 layer]
    nPort   = 32;
    nLayers = 4;
    W_lookup = zeros(nPort, nLayers);

    for row = 1:nPort
        lineStr = strtrim(lines{header_line + row});

        % FIX: dùng regex thay sscanf để parse đúng "a+bi" và "a-bi"
        matches = regexp(lineStr, '[-+]?\d+\.\d+[+-]\d+\.\d+i', 'match');

        if numel(matches) < nLayers
            fprintf('Warning: dòng %d parse được %d số (cần %d)\n', ...
                header_line+row, numel(matches), nLayers);
            continue;
        end

        for col = 1:nLayers
            W_lookup(row, col) = str2double(matches{col});
        end
    end

    fprintf('\nW_lookup (32x4) — 4 hàng đầu:\n');
    disp(W_lookup(1:4, :));

    %% So sánh W_lookup với W từ CSI report
    W_csi = CSIInfo.W;  % [32 x 4]
    fprintf('W từ nrCSIReportCSIRS size : [%s]\n', num2str(size(W_csi)));
    fprintf('W từ file lookup      size : [%s]\n', num2str(size(W_lookup)));

    % Tính sai số Frobenius (chuẩn hóa theo phase)
    % W có thể lệch pha toàn cục → dùng abs để so sánh biên độ
    diff_abs = norm(abs(W_csi) - abs(W_lookup), 'fro');
    fprintf('||abs(W_csi) - abs(W_lookup)||_F = %.6f\n', diff_abs);

    if diff_abs < 1e-4
        fprintf('✓ W khớp với codebook file\n');
    else
        fprintf('✗ W KHÔNG khớp — kiểm tra lại công thức PMI_Index\n');
    end
end

function [CSIReport,CSIInfo] = nrCSIReportCSIRS(carrier,csirs,reportConfig,dmrsConfig,H,nVar)

    narginchk(6,6);
 
    % Validate inputs
    [reportConfig,csirsInd] = nr5g.internal.validateCSIInputs(carrier,csirs,reportConfig,dmrsConfig,H,nVar);

    % Calculate the number of subbands and size of each subband for the
    % given configuration
    PMISubbandInfo = nr5g.internal.getPMISubbandInfo(carrier,reportConfig);

    % Get the number of CSI-RS ports and receive antennas from the
    % dimensions of the channel estimate
    Pcsirs = size(H,4);
    nRxAnts = size(H,3);

    % Calculate the maximum possible transmission rank according to
    % codebook type
    if strcmpi(reportConfig.CodebookType,'Type1SinglePanel')
        % Maximum possible rank is 8 for Type I single-panel codebooks, as
        % defined in TS 38.214 Section 5.2.2.2.1
        maxRank = min([nRxAnts Pcsirs 8]);
    elseif strcmpi(reportConfig.CodebookType,'Type2') ||...
            (strcmpi(reportConfig.CodebookType,'eType2') && any(reportConfig.ParameterCombination == [7 8]))
        % Maximum possible rank is 2 for:
        % - Type II codebooks, as defined in TS 38.214 Section 5.2.2.2.3
        % - Enhanced type II codebooks with parameter combination value
        %   as one of {7, 8}, as defined in TS 38.214 Table 5.2.2.2.5-1
        maxRank = min(nRxAnts,2);
    else
        % Maximum possible rank is 4 for:
        % - Type I multi-panel codebooks, as defined in TS 38.214 Section 5.2.2.2.2
        % - Enhanced type II codebooks with parameter combination value in
        %   the range 1:6, as defined in TS 38.214 Table 5.2.2.2.5-1
        maxRank = min(nRxAnts,4);
    end

    % Check the rank indicator restriction parameter and derive the
    % ranks that are not restricted from usage
    if(~isempty(reportConfig.RIRestriction))
        unRestrictedRanks = find(reportConfig.RIRestriction);
        validRanks = intersect(unRestrictedRanks,1:maxRank);
    else
        validRanks = 1:maxRank;
    end

    % Initialize outputs
    [CSIReport,CSIInfo] = initOutputs(reportConfig,PMISubbandInfo);

    if ~isempty(validRanks) && ~isempty(csirsInd)
        [CSIReport,CSIInfo] = getCSIReport(carrier,csirs,reportConfig,dmrsConfig,H,nVar,validRanks,PMISubbandInfo);
    end
end

% Selection of rank indicator based on maximizing spectral efficiency
function [CSI,CSIInfo] = getCSIReport(carrier,csirs,reportConfig,dmrsConfig,H,nVar,validRanks,PMISubbandInfo)
    
    % Get the spectral Efficiency from the CQI table
    persistent SpecEffArray tableName;
    if (isempty(SpecEffArray)||(~strcmpi(tableName,reportConfig.CQITable)))
        tableName = reportConfig.CQITable;
        cqiTableClass = nrCQITables;
        TableCell = {'Table1','Table2','Table3','Table4'};        
        SpecEffArray= cqiTableClass.(['CQI' TableCell{strcmpi(tableName,TableCell)}]).SpectralEfficiency;
    end
   
    % Initialize outputs
    [CSI,CSIInfo] = initOutputs(reportConfig,PMISubbandInfo);

    % For each valid rank, select the best CQI. Then, find the rank
    % that maximizes modulation and coding efficiency
    maxRank = max(validRanks);
    efficiency = NaN(maxRank,1);
    for rank = validRanks
        % Determine the CQI and PMI for the current rank
        [cqi{rank},pmi(rank),cqiInfo(rank),pmiInfo(rank)] = nr5g.internal.nrCQIReport(carrier,csirs,reportConfig,dmrsConfig,rank,H,nVar); %#ok<AGROW>
    
        % Get wideband CQI
        cqiWideband = cqi{rank}(1,:);
    
        % If the wideband CQI is appropriate, calculate the efficiency
        if all(cqiWideband ~= 0)
            if ~any(isnan(cqiWideband))
                % Calculate throughput-related metric using number of
                % layers, code rate and modulation, and estimated BLER
                blerWideband = cqiInfo(rank).TransportBLER(1,:);
                ncw = numel(cqiWideband);
                cwLayers = floor((rank + (0:ncw-1)) / ncw);
                SpecEffValue = SpecEffArray(cqiWideband+1);
                eff = cwLayers .* (1 - blerWideband) * SpecEffValue;
                efficiency(rank) = eff;
            end
        else
            efficiency(rank) = 0;
        end
    end
    
    % Return the rank that maximizes the spectral efficiency and the
    % corresponding PMI.
    [maxEff,maxEffIndx] = max(efficiency);
    if ~isnan(maxEff)
        CSI.RI = maxEffIndx;
        CSI.PMISet = pmi(CSI.RI);
        CSI.CQI = cqi{CSI.RI};
        CSIInfo.W = pmiInfo(CSI.RI).W;
        CSIInfo.SINRPerSubband = cqiInfo(CSI.RI).SINRPerSubbandPerCW;
        CSIInfo.EffectiveSINR = cqiInfo(CSI.RI).EffectiveSINR;
    end

end

function [CSI,CSIInfo] = initOutputs(reportConfig,PMISubbandInfo)
%   [CSI,CSIInfo] = initOutputs(REPORTCONFIG,PMISUBBANDINFO) initializes the
%   rank and PMI set values with NaNs.

    CSI.RI = NaN;
    isType1SinglePanel = strcmpi(reportConfig.CodebookType,'Type1SinglePanel');
    isType2 = strcmpi(reportConfig.CodebookType,'Type2');
    isEnhType2 = strcmpi(reportConfig.CodebookType,'eType2');
    % Generate PMI set and output information structure with NaNs
    if isType2
        numI1Indices = 3 + (1 + 2*reportConfig.NumberOfBeams);
        numI2Columns = (1+reportConfig.SubbandAmplitude);
        numI2Rows = 2*reportConfig.NumberOfBeams;
        CSI.PMISet.i1 = NaN(1,numI1Indices);
        CSI.PMISet.i2 = NaN(numI2Rows,numI2Columns,PMISubbandInfo.NumSubbands);        
    elseif isEnhType2
        pv = reportConfig.Tables.EnhancedType2Configurations{reportConfig.ParameterCombination,4};
        Mv = ceil(pv*PMISubbandInfo.NumSubbands/reportConfig.NumberOfPMISubbandsPerCQISubband);
        numI1Indices = 4 + (1 + 2*reportConfig.NumberOfBeams*Mv + 1);
        numI2Values = (2 + 2*reportConfig.NumberOfBeams*Mv + 2*reportConfig.NumberOfBeams*Mv);
        CSI.PMISet.i1 = NaN(1,numI1Indices);
        CSI.PMISet.i2 = NaN(1,numI2Values,PMISubbandInfo.NumSubbands);        
    elseif isType1SinglePanel
        CSI.PMISet.i1 = NaN(1,3);
        CSI.PMISet.i2 = NaN(1,PMISubbandInfo.NumSubbands);
    else
        CSI.PMISet.i1 = NaN(1,6);
        CSI.PMISet.i2 = NaN(3,PMISubbandInfo.NumSubbands);
    end
    % Initialize structure for CSIInfo
    CSIInfo = struct('W',[],'SINRPerSubband',[],'EffectiveSINR',[]);

end