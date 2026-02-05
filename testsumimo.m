clear; clc; close all;

setupPath();

% -----------------------------------------------------------------
% Configuration Parameters
% -----------------------------------------------------------------
nlayers = 2;
nTxAnts = 8;                
nRxAnts = 4;                 
sampleRate = 61440000;  
SNR_dB = 20;


% Channel for test
% Rayleigh || AWGN || Ideal || CDL
% With Ideal channel, we can't choose the PMI orthogonal 
% Because of all channel use the same PMI
channelType = "Rayleigh";
channel = getChannel(channelType, SNR_dB, nRxAnts, 1, [4 1 2 1 1], sampleRate); 

% -----------------------------------------------------------------
% Carrier Configuration
% -----------------------------------------------------------------
carrier = nrCarrierConfig;
% Sharetechnote frame structure 
% Table 5.3.2-1 138-101-1
% https://www.etsi.org/deliver/etsi_ts/138100_138199/13810101/17.08.00_60/ts_13810101v170800p.pdf
carrier.SubcarrierSpacing = 15;  
carrier.NSizeGrid = 273;

% -----------------------------------------------------------------
% CSI Configuration
% -----------------------------------------------------------------
csiConfig = nrCSIRSConfig;
csiConfig.CSIRSType = {'nzp'};
% https://www.etsi.org/deliver/etsi_ts/138200_138299/138211/18.06.00_60/ts_138211v180600p.pdf
% Bảng 7.4.1.5.3-1.
csiConfig.RowNumber = 6;           
csiConfig.Density = {'one'};
csiConfig.SubcarrierLocations = {[0 2 4 6]};
csiConfig.SymbolLocations = {0};
csiConfig.CSIRSPeriod = [4 0];
csiConfig.NumRB = 273;
csiConfig.RBOffset = 0;

% -----------------------------------------------------------------
% CSI Report Configuration Type II
% -----------------------------------------------------------------
subbandAmplitude = true;
csiReport = nrCSIReportConfig;
csiReport.CQITable = "table2"; 
csiReport.CodebookType = "type2";
csiReport.PanelDimensions = [1 4 1]; 
csiReport.PMIFormatIndicator = "subband";
csiReport.CQIFormatIndicator = "subband";
csiReport.SubbandSize = 32;
csiReport.SubbandAmplitude = subbandAmplitude;
csiReport.NumberOfBeams = 2;
csiReport.PhaseAlphabetSize = 4;
csiReport.RIRestriction = [1 1 0 0]; 

% -----------------------------------------------------------------
% Codebook Configuration
% -----------------------------------------------------------------
cfg = struct();
cfg.N1 = csiReport.PanelDimensions(2); 
cfg.N2 = csiReport.PanelDimensions(3);
cfg.O1 = 4;
cfg.O2 = 1;
cfg.NumberOfBeams = csiReport.PanelDimensions(1) * csiReport.NumberOfBeams;      
cfg.PhaseAlphabetSize = csiReport.PhaseAlphabetSize; 
cfg.SubbandAmplitude = csiReport.SubbandAmplitude;
cfg.numLayers = nlayers;   

% -----------------------------------------------------------------
% PDSCH Configuration
% -----------------------------------------------------------------
pdsch = customPDSCHConfig(); 

pdsch.CodebookConfig = cfg;
pdsch.DMRS.DMRSConfigurationType = 1;
pdsch.DMRS.DMRSAdditionalPosition = 1;
pdsch.NumLayers = nlayers;
% 273 PRB
pdsch.PRBSet = 0:272;

% -----------------------------------------------------------------
% Mesurements
% -----------------------------------------------------------------
[MCS, PMI] = csiRsMesurements(carrier, channel, csiConfig, csiReport, pdsch, nlayers);

pdsch.Indices.i1 = PMI.i1;
pdsch.Indices.i2 = PMI.i2;

% Table 5.1.3.1-2: MCS index table 2 for PDSCH - 138 214
% https://www.etsi.org/deliver/etsi_ts/138200_138299/138214/18.06.00_60/ts_138214v180600p.pdf
pdsch = linkAdaption(pdsch, MCS, SNR_dB);

% -----------------------------------------------------------------
% Generate Bits
% -----------------------------------------------------------------
[~, pdschInfo] = nrPDSCHIndices(carrier, pdsch);
NREPerPRB = pdschInfo.NREPerPRB;

TBS = nrTBS(pdsch.Modulation, pdsch.NumLayers, ...
            length(pdsch.PRBSet), NREPerPRB, pdsch.TargetCodeRate);
inputBits = randi([0 1], TBS, 1);

% -----------------------------------------------------------------
% PDSCH Modulation
% -----------------------------------------------------------------
[layerMappedSym, pdschInd] = PDSCHEncode(pdsch, carrier, inputBits);
W = generateTypeIIPrecoder(pdsch, pdsch.Indices.i1, pdsch.Indices.i2, true);
W_transposed = W.';
[antsym, antind] = nrPDSCHPrecode(carrier, layerMappedSym, pdschInd, W_transposed);
dmrsSym = nrPDSCHDMRS(carrier, pdsch);
dmrsInd = nrPDSCHDMRSIndices(carrier, pdsch);
[dmrsAntSym, dmrsAntInd] = nrPDSCHPrecode(carrier, dmrsSym, dmrsInd, W_transposed);
txGrid = nrResourceGrid(carrier, 2 * cfg.N1 * cfg.N2); 
txGrid(antind) = antsym;
txGrid(dmrsAntInd) = dmrsAntSym;  

[txWaveform, waveformInfo] = nrOFDMModulate(carrier, txGrid);

% -----------------------------------------------------------------
% Channel
% -----------------------------------------------------------------
rxWaveform = channel(txWaveform);

% -----------------------------------------------------------------
% RX and Calculate BER
% -----------------------------------------------------------------
rxBits = rxPDSCHDecode(carrier, pdsch, rxWaveform, txWaveform, TBS);

numErrors = biterr(double(inputBits), double(rxBits));
BER = numErrors / TBS;

fprintf('SNR: %d dB | BER: %.5f. \n', SNR_dB, BER);

% -----------------------------------------------------------------
% This function use to get the channel for TEST
% It return:
%   - channel: AWGN | Rayleigh | Ideal channel.
% -----------------------------------------------------------------
function channel = getChannel(channelType, SNR_dB, nRxAnts, ueIdx, cdlChannelAntenna, sampleRate) 
    switch channelType
        case 'AWGN'
            channel = AWGNChannel('SNRdB', SNR_dB, 'NumRxAnts', nRxAnts);
            
        case 'Rayleigh'
            channel = RayleighChannel('SNRdB', SNR_dB, 'NumRxAnts', nRxAnts);
            
        case 'Ideal'
            channel = IdealChannel('SNRdB', SNR_dB, 'NumRxAnts', nRxAnts);

        case 'CDL'
            % cdlChannel = nrCDLChannel;
            % cdlChannel.DelayProfile = 'CDL-C';
            % % Format [M, N, P, Mg, Ng] 
            % %   M: The number of antenna in the vertical = N1
            % %   N: The number of antenna in the horizontal = N2
            % %   P: Polarization
            % %   Mg: The number of panel row
            % %   Ng: The number of panel column
            % cdlChannel.TransmitAntennaArray.Size = cdlChannelAntenna;
            % cdlChannel.ReceiveAntennaArray.Size = [2, 1, 2, 1, 1];   
            % cdlChannel.Seed = ueIdx; 

            % --- BƯỚC 1: Tạo kênh tham chiếu & ÁP DỤNG DELAY SPREAD NGAY TẠI ĐÂY ---
            refChan = nrCDLChannel;
            refChan.DelayProfile = 'CDL-C';
            refChan.DelaySpread = 300e-9; % [Quan trọng] Co giãn thời gian trễ chuẩn ở đây
            
            % --- BƯỚC 2: Tính góc xoay ngẫu nhiên ---
            rng(ueIdx); 
            azimuthOffset = 360 * rand() - 180; 
            
            % --- BƯỚC 3: Tạo kênh Custom ---
            channelObj = nrCDLChannel;
            channelObj.DelayProfile = 'Custom'; 
            
            % Gán Delay và Gain (Lấy từ refChan đã được scale sẵn)
            channelObj.PathDelays = refChan.PathDelays;       % Giá trị giây thực tế
            channelObj.AveragePathGains = refChan.AveragePathGains;
            
            % Gán các góc chuẩn
            channelObj.AnglesAoA = refChan.AnglesAoA;
            channelObj.AnglesZoD = refChan.AnglesZoD;
            channelObj.AnglesZoA = refChan.AnglesZoA;
            
            % Chỉ gán HasLOSCluster (CDL-C mặc định là false, nhưng cứ copy cho chắc)
            channelObj.HasLOSCluster = refChan.HasLOSCluster;
            
            % [FIX] Không gán KFactorFirstCluster vì CDL-C là NLOS (HasLOSCluster=false)
            
            % --- BƯỚC 4: Xoay góc AoD ---
            newAoD = refChan.AnglesAoD + azimuthOffset;
            newAoD = mod(newAoD + 180, 360) - 180; % Wrap góc
            channelObj.AnglesAoD = newAoD;

            % --- BƯỚC 5: Cấu hình chung ---
            % [FIX] Không set DelaySpread ở đây nữa (vì đã áp dụng ở bước 1 rồi)
            
            channelObj.CarrierFrequency = 3.5e9;
            channelObj.MaximumDopplerShift = 5;
            
            channelObj.TransmitAntennaArray.Size = cdlChannelAntenna;
            channelObj.ReceiveAntennaArray.Size = [2, 1, 2, 1, 1]; 
            
            channelObj.SampleRate = sampleRate;
            channelObj.Seed = ueIdx;

            channel = channelObj;
            
        otherwise
            error('Invalid Type "%s"', channelType);
    end
end