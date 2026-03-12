clear; clc; close all;

setupPath();
% -----------------------------------------------------------------
% Configuration Parameters
% -----------------------------------------------------------------
NLAYERS = 2;
SUBBAND_AMPLITUDE = true;
N1 = 4; N2 = 1; O1 = 4; O2 = 1;
NUMBER_OF_BEAMS = 2;
PHASE_ALPHABET_SIZE = 4;
MCS = 12; % 6 517 3.0293

% TBS size % Done
% 14 symbols 1 slot % Done
% slot 0 % Done
% 1 layer 1 port 
% 1 frame % Done
% DMRS type % Done

% Currently support 2 or 4 layers
if NUMBER_OF_BEAMS == 2
    i11 = [1 0];
    i12 = 3;
    i13 = [0 0];
    i14 = [7,4,2,1; 7,5,6,0];

    i21 = [0,0,0,1; 0,3,0,2];
    i22 = [1,1,1,1; 1,1,1,1];
else
    i11 = [1 1];
    i12 = 3;
    i13 = [0 0];
    i14 = [7,4,2,1,3,0,2,6; 7,5,6,0,1,3,4,0];

    i21 = [0,0,2,1,0,3,1,0; 0,3,0,2,2,1,3,0];
    i22 = [1,1,1,1,1,1,1,1; 1,1,1,1,1,1,1,1];
end

% -----------------------------------------------------------------
% Carrier Configuration
% -----------------------------------------------------------------
carrier = nrCarrierConfig;
% Sharetechnote frame structure 
% Table 5.3.2-1 138-101-1
% https://www.etsi.org/deliver/etsi_ts/138100_138199/13810101/17.08.00_60/ts_13810101v170800p.pdf
carrier.SubcarrierSpacing = 30;  
carrier.NSizeGrid = 273;
carrier.CyclicPrefix = "normal";
carrier.NSlot = 0;
carrier.NFrame = 0;

% -----------------------------------------------------------------
% Codebook Configuration
% -----------------------------------------------------------------
cfg = struct();
cfg.N1 = N1;
cfg.N2 = N2;
cfg.O1 = O1;
cfg.O2 = O2;
cfg.NumberOfBeams = NUMBER_OF_BEAMS;      
cfg.PhaseAlphabetSize = PHASE_ALPHABET_SIZE; 
cfg.SubbandAmplitude = SUBBAND_AMPLITUDE;
cfg.numLayers = NLAYERS;   

% -----------------------------------------------------------------
% PDSCH Configuration
% -----------------------------------------------------------------
pdsch = customPDSCHConfig(); 

pdsch.CodebookConfig = cfg;
pdsch.DMRS.DMRSConfigurationType = 1; % [0, 2, 4, 6, 10]
pdsch.DMRS.DMRSAdditionalPosition = 0; % 1 dmrs
pdsch.DMRS.DMRSTypeAPosition = 2; % symbols 2
pdsch.DMRS.NumCDMGroupsWithoutData = 2; % Default
pdsch.NumLayers = NLAYERS;
pdsch.MappingType = 'A'; % PDSCH Start at 2 or 3
% 273 PRB
pdsch.PRBSet = 0:272;

pdsch.Indices.i1 = {i11, i12, i13, i14};
pdsch.Indices.i2 = {i21, i22};

% Table 5.1.3.1-2: MCS index table 2 for PDSCH - 138 214
% https://www.etsi.org/deliver/etsi_ts/138200_138299/138214/18.06.00_60/ts_138214v180600p.pdf
pdsch = pdsch.setMCS(MCS);

% -----------------------------------------------------------------
% Generate Bits
% -----------------------------------------------------------------
[~, pdschInfo] = nrPDSCHIndices(carrier, pdsch);
NREPerPRB = pdschInfo.NREPerPRB;

% TBS = nrTBS(pdsch.Modulation, pdsch.NumLayers, ...
%             length(pdsch.PRBSet), NREPerPRB, pdsch.TargetCodeRate);
% Manual
TBS = manualCalculateTBS(pdsch);

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

% Frame Grid
frameGrid = ResourceGrid(carrier, 2 * cfg.N1 * cfg.N2);
% Slot grid
txGrid = nrResourceGrid(carrier, 2 * cfg.N1 * cfg.N2); 

% Mapping on slot 0
txGrid(antind) = antsym;
txGrid(dmrsAntInd) = dmrsAntSym;  

symbolsPerSlot = carrier.SymbolsPerSlot;
currentSlotIdx = carrier.NSlot; 

startSym = currentSlotIdx * symbolsPerSlot + 1;
endSym = (currentSlotIdx + 1) * symbolsPerSlot;

% Extended to all Frame
frameGrid(:, startSym:endSym, :) = txGrid;

NFFT = 4096; % Kích thước IFFT
numRe = size(frameGrid, 1); % Tổng số subcarriers mang dữ liệu (Ví dụ: 273*12 = 3276)
numSymb = size(frameGrid, 2); % Tổng số symbol trong frameGrid

datall = frameGrid(:, :, 8); % 1 Port

txDataF1 = [datall(numRe/2+1:end, :); ...
            zeros(NFFT - numRe, numSymb); ...
            datall(1:numRe/2, :)];

txdata1 = ofdmModulation(txDataF1, NFFT);

% centerFreq = 0;
% nchannel = 2; 
% nFrame = 5; 
% scs = 30000; % SCS 30kHz
% data_repeat = repmat(txdata1, nFrame, 1); 
% savevsarecordingmulti('PDSCH_Waveform_1P1V.mat', data_repeat, NFFT*scs, centerFreq, nchannel);



% % -----------------------------------------------------------------
% % Channel
% % -----------------------------------------------------------------
% channel = nrTDLChannel;
% channel.NumTransmitAntennas = 8;
% channel.NumReceiveAntennas = 4;
% channel.SampleRate = 61440000;
% channel.DelayProfile = 'TDL-C';
% channel.DelaySpread = 0;
% channel.Seed = 1;
% channel.MaximumDopplerShift = 5;

% rxWaveform = channel(txWaveform);

% signalPower = var(rxWaveform);

% signalPower_dBW = 10 * log10(mean(signalPower));
% noisePower_dBW = signalPower_dBW - 20;
% noiseVariance = 10^(noisePower_dBW / 10);
% noise = sqrt(noiseVariance / 2) * (randn(size(rxWaveform)) + 1i * randn(size(rxWaveform)));
% rxWaveform = rxWaveform + noise;

% % -----------------------------------------------------------------
% % RX and Calculate BER
% % -----------------------------------------------------------------
% rxBits = rxPDSCHDecode(carrier, pdsch, rxWaveform, txWaveform, TBS);

% numErrors = biterr(double(inputBits), double(rxBits));
% BER = numErrors / TBS;

% fprintf('BER: %.5f. \n', BER);


function TBS = manualCalculateTBS(pdsch)
    if pdsch.DMRS.DMRSConfigurationType == 1
        dmrsPatern = [0, 2, 4, 6, 8, 10];
    else
        dmrsPatern = [1, 2, 6, 7];
    end

    % The number of dmrs re in the prb
    dmrsRePerPRB = length(dmrsPatern) * pdsch.DMRS.NumCDMGroupsWithoutData;

    % The number of pdsch re in the prb
    pdschReTotalPerPRB = 12 * pdsch.SymbolAllocation(2);

    % The number of pdsch re available for data in the prb
    pdschRePerPRB = pdschReTotalPerPRB - dmrsRePerPRB;

    % The total Re of PDSCH available for data
    numRE = min(156, pdschRePerPRB) * length(pdsch.PRBSet);

    switch pdsch.Modulation
        case 'QPSK',    Qm = 2;
        case '16QAM',   Qm = 4;
        case '64QAM',   Qm = 6;
        case '256QAM',  Qm = 8;
        case '1024QAM', Qm = 10;
        otherwise,      Qm = 2;
    end

    NInfo = numRE * pdsch.TargetCodeRate * Qm * pdsch.NumLayers;

    if NInfo <= 3824
        n = max(3, floor(log2(NInfo)) - 6);
        NInfoPrime = max(24, (2^n) * floor(NInfo / (2^n)));
        tableTBS = [24, 32, 40, 48, 56, 64, 72, 80, 88, 96, 104, 112, 120, ...
                128, 136, 144, 152, 160, 168, 176, 184, 192, 208, 224, 240, ...
                256, 272, 288, 304, 320, 336, 352, 368, 384, 408, 432, 456, ...
                480, 504, 528, 552, 576, 608, 640, 672, 704, 736, 768, 808, ...
                848, 888, 928, 984, 1032, 1064, 1128, 1160, 1192, 1224, 1256, ...
                1288, 1320, 1352, 1416, 1480, 1544, 1608, 1672, 1736, 1800, ...
                1864, 1928, 2024, 2088, 2152, 2216, 2280, 2408, 2472, 2536, ...
                2600, 2664, 2728, 2792, 2856, 2976, 3104, 3240, 3368, 3496, ...
                3624, 3752, 3824];
        validTBS = tableTBS(tableTBS >= NInfoPrime);

        TBS = validTBS(1);
    else
        n = floor(log2(NInfo - 24)) - 5;

        round_val = floor((NInfo - 24) / (2^n) + 0.5);
        NInfoPrime = max(3840, (2^n) * round_val);

        if pdsch.TargetCodeRate <= 1/4
            C = ceil((NInfoPrime + 24) / 3816);
            TBS = 8 * C * ceil((NInfoPrime + 24) / (8 * C)) - 24;
        else
            if NInfoPrime > 8424
                C = ceil((NInfoPrime + 24) / 8424);
                TBS = 8 * C * ceil((NInfoPrime + 24) / (8 * C)) - 24;
            else
                TBS = 8 * ceil((NInfoPrime + 24) / 8) - 24;
            end
        end
    end
end