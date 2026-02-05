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


if nTxAnts == 8
    rowNumber = 6;
    csiReportAntenna = [1 4 1];
    cdlChannelAntenna = [4 1 2 1 1];
    csiReportSymbolLocations = {0};
elseif nTxAnts == 16
    rowNumber = 11;
    csiReportAntenna = [1 4 2];
    cdlChannelAntenna = [4 2 2 1 1];
    csiReportSymbolLocations = {0};
else 
    rowNumber = 17;
    csiReportAntenna = [1 4 4];
    cdlChannelAntenna = [4 4 2 1 1];
    csiReportSymbolLocations = {[2 3]};
end


% Channel for test
% Rayleigh || AWGN || Ideal || CDL
% With Ideal channel, we can't choose the PMI orthogonal 
% Because of all channel use the same PMI
channelType = "CDL";
channel = getChannel(channelType, SNR_dB, nRxAnts, 1, [4 1 2 1 1]); 

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
csiConfig.RowNumber = rowNumber;           
csiConfig.Density = {'one'};
csiConfig.SubcarrierLocations = {[0 2 4 6]};
csiConfig.SymbolLocations = csiReportSymbolLocations;
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
csiReport.PanelDimensions = csiReportAntenna; 
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

numUes = 10;

[all_W, channelList, MCS_List] = ...
    prepareData(...
        numUes, carrier, csiConfig, csiReport, pdsch, nTxAnts,...
        nRxAnts, SNR_dB, channelType, cdlChannelAntenna, nlayers ...
    );

% -----------------------------------------------------------------
% BƯỚC 1: TÍNH MA TRẬN TƯƠNG QUAN (CORRELATION MATRIX)
% -----------------------------------------------------------------

numUes = length(all_W);
correlationMatrix = zeros(numUes, numUes);

% Số lượng subband (lấy từ dữ liệu của UE 1)
numSubbands = size(all_W{1}, 3); 

fprintf('Dang tinh toan ma tran tuong quan cho %d UEs...\n', numUes);

minRho = 100;           
bestPairIndices = [0 0]; 

for i = 1:numUes
    for j = 1:numUes
        if i == j
            correlationMatrix(i, j) = 1;
        else
            rho_sum = 0;
            
            W_i_all = all_W{i};
            W_j_all = all_W{j};
            
            for sb = 1:numSubbands
                w_i_sb = W_i_all(:, :, sb); 
                w_j_sb = W_j_all(:, :, sb);
                
                rho = calculateOrthogonality(w_i_sb, w_j_sb);
                rho_sum = rho_sum + rho;
            end
            
            avg_rho = rho_sum / numSubbands;
            correlationMatrix(i, j) = avg_rho;

            if avg_rho < minRho
                minRho = avg_rho;
                bestPairIndices = [i, j];
            end
        end
    end
end


function [...
    all_W, channelList, MCS_List] = ...
prepareData(...
        NumUEs, carrier, csiConfig, csiReport, pdsch, nTxAnts,...
        nRxAnts, SNR_dB, channelType, cdlChannelAntenna, nlayers...
)

    % Initial channel list
    channelList = cell(1, NumUEs);

    % Initial W
    all_W = cell(1, NumUEs);
    MCS_List = cell(1, NumUEs);

    % Starting calculate the csi
    for ueIdx = 1:NumUEs
        channel = getChannel(channelType, SNR_dB, nRxAnts, ueIdx, cdlChannelAntenna); 

        channelList{ueIdx} = channel;
        
        % -----------------------------------------------------------------
        % Mesurements
        % -----------------------------------------------------------------
        [MCS, PMI] = csiRsMesurementsV2(carrier, channel, csiConfig, csiReport, pdsch, nlayers);

        % 1. Xác định kích thước
        numSubbands = size(PMI.i2{1}, 3);

        i21_cell = PMI.i2{1};
        i22_cell = PMI.i2{2};

        all_W_Ue = complex(zeros(nTxAnts, nlayers, numSubbands)); 

        for sb = 1:numSubbands
            i21 = i21_cell(:, :, sb);
            i22 = i22_cell(:, :, sb);
            i2 = {i21, i22};
            
            % Tính toán
            W_subband = generateTypeIIPrecoder(pdsch, PMI.i1, i2, true);
            
            all_W_Ue(:, :, sb) = W_subband; 
        end

        MCS_List{ueIdx} = MCS;
        
        all_W{ueIdx} = all_W_Ue;
    end
end

% -----------------------------------------------------------------
% This function use to get the channel for TEST
% It return:
%   - channel: AWGN | Rayleigh | Ideal channel.
% -----------------------------------------------------------------
function channel = getChannel(channelType, SNR_dB, nRxAnts, ueIdx, cdlChannelAntenna) 
    switch channelType
        case 'AWGN'
            channel = AWGNChannel('SNRdB', SNR_dB, 'NumRxAnts', nRxAnts);
            
        case 'Rayleigh'
            channel = RayleighChannel('SNRdB', SNR_dB, 'NumRxAnts', nRxAnts);
            
        case 'Ideal'
            channel = IdealChannel('SNRdB', SNR_dB, 'NumRxAnts', nRxAnts);

        case 'CDL'
            cdlChannel = nrCDLChannel;
            cdlChannel.DelayProfile = 'CDL-C';
            % Format [M, N, P, Mg, Ng] 
            %   M: The number of antenna in the vertical = N1
            %   N: The number of antenna in the horizontal = N2
            %   P: Polarization
            %   Mg: The number of panel row
            %   Ng: The number of panel column
            cdlChannel.TransmitAntennaArray.Size = cdlChannelAntenna;
            cdlChannel.ReceiveAntennaArray.Size = [2, 1, 2, 1, 1];   
            cdlChannel.Seed = ueIdx; 

            channel = cdlChannel;
            
        otherwise
            error('Invalid Type "%s"', channelType);
    end
end

% -----------------------------------------------------------------
% Hàm tính độ tương quan không gian giữa 2 Precoder (PMI/W)
% Output:
%   - rho: Giá trị từ [0 đến 1]
%       + Gần 0: Hai UE trực giao tốt (Good for MU-MIMO)
%       + Gần 1: Hai UE trùng hướng chùm tia (Bad - High Interference)
% -----------------------------------------------------------------
function rho = calculateOrthogonality(W_m, W_n)
    % W_m, W_n có kích thước [nTxAnts x nLayers]

    % 1. Kiểm tra kích thước
    if any(size(W_m) ~= size(W_n))
        error('DimensionMismatch');
    end

    % 2. Chuyển đổi ma trận thành vector cột (Vectorization)
    % Giúp tính toán nhanh hơn vòng lặp for
    vec_m = W_m(:);
    vec_n = W_n(:);

    % 3. Tính tích vô hướng (Hermitian inner product)
    dotProduct = vec_m' * vec_n; % Tương đương sum(conj(m) * n)

    % 4. Tính độ lớn (Norm) của từng vector
    norm_m = norm(vec_m);
    norm_n = norm(vec_n);

    % 5. Tính hệ số tương quan chuẩn hóa (Cosine Similarity)
    if norm_m == 0 || norm_n == 0
        rho = 0; % Tránh chia cho 0 nếu vector rỗng
    else
        rho = abs(dotProduct) / (norm_m * norm_n);
    end
end