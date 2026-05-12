%% Full CSI Report — Type I Single Panel | 32 ports | 273 RB | 30kHz
%  Dùng nrPerfectChannelEstimate + CDL thay TDL để tránh lỗi RAM
%  Yêu cầu: 5G Toolbox (MathWorks)

clc; clear; close all;
addpath('D:\Programs\Matlab\R2025a\toolbox\5g\5g');

%% ========== 1. CARRIER ==========
carrier = nrCarrierConfig;
carrier.SubcarrierSpacing = 30;
carrier.NSizeGrid         = 273;
carrier.NStartGrid        = 0;
carrier.NSlot             = 0;
carrier.NFrame            = 0;

fprintf('=== Carrier: SCS=%dkHz | Grid=%d RBs ===\n\n', ...
    carrier.SubcarrierSpacing, carrier.NSizeGrid);

%% ========== 2. CSI-RS ==========
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
nRxAnts = 32;

fprintf('=== CSI-RS: Tx=%d | Rx=%d ===\n\n', nTxAnts, nRxAnts);

%% ========== 3. REPORT CONFIG ==========
reportConfig = nrCSIReportConfig;
reportConfig.NStartBWP               = 0;
reportConfig.NSizeBWP                = 273;
reportConfig.CodebookType            = 'Type1SinglePanel';
reportConfig.PanelDimensions         = [1 4 4];
reportConfig.CodebookMode            = 1;
reportConfig.CQITable                = 'table1';
reportConfig.CQIFormatIndicator      = 'Subband';
reportConfig.SubbandSize             = 4;
reportConfig.PMIFormatIndicator      = 'Subband';
reportConfig.CodebookSubsetRestriction = [];

fprintf('=== Report: %s | Panel[N1=%d N2=%d] | BWP=%d RBs ===\n\n', ...
    reportConfig.CodebookType, ...
    reportConfig.PanelDimensions(1), reportConfig.PanelDimensions(2), ...
    reportConfig.NSizeBWP);

%% ========== 4. CDL CHANNEL ==========
% Dùng CDL thay TDL — CDL không cần gen waveform dài như TDL
channel = nrCDLChannel;
channel.DelayProfile        = 'CDL-C';
channel.DelaySpread         = 300e-9;
channel.MaximumDopplerShift = 5;
channel.TransmitAntennaArray.Size = [32 1 1 1 1];  % [M N P Mg Ng]
channel.ReceiveAntennaArray.Size  = [32 1 1 1 1];
channel.Seed                = 42;
channel.NormalizePathGains  = true;

OFDMInfo = nrOFDMInfo(carrier);

%% ========== 5. PDSCH DMRS ==========
pdsch      = nrPDSCHConfig;
dmrsConfig = pdsch.DMRS;

%% ========== 6. HÀM PERFECT CHANNEL ESTIMATE ==========
% Tránh cấp phát waveform lớn — lấy path gains từ 1 slot nhỏ
getH = @(ch, snrDb) localPerfectEst(carrier, ch, snrDb);

%% ========== 7. SINGLE POINT SNR=20dB ==========
SNRdB = 20;
fprintf('=== Single Point SNR=%ddB ===\n', SNRdB);

[H, nVar] = getH(channel, SNRdB);
fprintf('H size: [%s] | nVar=%.2e\n\n', num2str(size(H)), nVar);

[CSIReport, CSIInfo] = nrCSIReportCSIRS( ...
    carrier, csirs, reportConfig, dmrsConfig, H, nVar);

fprintf('[RI]  = %d\n', CSIReport.RI);
fprintf('[i1]  = [%s]\n', num2str(CSIReport.PMISet.i1));
fprintf('[i2]  = [%s]\n', num2str(CSIReport.PMISet.i2(:)'));
fprintf('[CQI] Wideband = %d\n', CSIReport.CQI(1,1));
fprintf('[W]   size = [%s]\n\n', num2str(size(CSIInfo.W)));

%% ========== 8. SWEEP SNR ==========
fprintf('=== Sweep SNR ===\n');
fprintf('%-10s %-5s %-10s\n', 'SNR(dB)', 'RI', 'WB_CQI');
fprintf('%s\n', repmat('-',1,28));

SNRdB_range = -5:5:30;
CQI_wb = NaN(1, length(SNRdB_range));
RI_arr = NaN(1, length(SNRdB_range));

for idx = 1:length(SNRdB_range)
    release(channel);
    channel.Seed = idx;

    try
        [H_i, nVar_i] = getH(channel, SNRdB_range(idx));
        [CSI_i, ~]    = nrCSIReportCSIRS( ...
            carrier, csirs, reportConfig, dmrsConfig, H_i, nVar_i);
        CQI_wb(idx) = CSI_i.CQI(1,1);
        RI_arr(idx) = CSI_i.RI;
    catch ME
        fprintf('SNR=%ddB: %s\n', SNRdB_range(idx), ME.message);
    end

    fprintf('%-10d %-5d %-10d\n', SNRdB_range(idx), RI_arr(idx), CQI_wb(idx));
end

%% ========== 9. VẼ ĐỒ THỊ ==========
figure('Name','CSI 32-port 273RB','Position',[100 100 950 420]);

subplot(1,2,1);
plot(SNRdB_range, CQI_wb,'b-o','LineWidth',2,'MarkerSize',7,'MarkerFaceColor','b');
grid on; xlabel('SNR (dB)'); ylabel('Wideband CQI');
title('Wideband CQI vs SNR'); ylim([0 16]); yticks(0:15);

subplot(1,2,2);
plot(SNRdB_range, RI_arr,'r-s','LineWidth',2,'MarkerSize',7,'MarkerFaceColor','r');
grid on; xlabel('SNR (dB)'); ylabel('Rank Indicator');
title('RI vs SNR'); ylim([0 9]); yticks(1:8);

sgtitle('Type I Single Panel | 32-port | N1=4,N2=4 | 273RB | SCS=30kHz | CDL-C');

fprintf('\nHoàn tất!\n');

%% ========== LOCAL FUNCTION ==========
function [H, nVar] = localPerfectEst(carrier, channel, SNRdB)
    % Lấy path gains bằng waveform tối thiểu (1 symbol, 1 slot)
    % Không cấp phát waveform lớn
    OFDMInfo = nrOFDMInfo(carrier);
    nTx      = channel.NumTransmitAntennas;
    Nfft     = OFDMInfo.Nfft;
    cpLen    = OFDMInfo.CyclicPrefixLengths(1);
    nSym     = carrier.SymbolsPerSlot;
    nSamples = (Nfft + cpLen) * nSym;   % 1 slot, ít samples nhất

    % Qua kênh với tín hiệu zeros để lấy path gains
    txSig = zeros(nSamples, nTx);
    [~, pathGains, sampleTimes] = channel(txSig);

    % Perfect channel estimate — không cần OFDM modulate/demodulate
    H = nrPerfectChannelEstimate(carrier, pathGains, ...
        channel.PathDelays, sampleTimes);

    % Noise variance từ SNR (normalized)
    nVar = 1 / (10^(SNRdB/10));
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