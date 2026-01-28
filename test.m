%% 5G NR TYPE II PRECODING LINK-LEVEL SIMULATION
% This script simulates a full 5G NR Transmitter-Channel-Receiver chain 
% using Type II (High-Resolution) Precoding Codebook.

clc; clear; close all;

setupPath();   

% -----------------------------------------------------------
% Transport Block and PDSCH Configuration
% Type II Precoding supports up to nLayers = 2 (v = {1, 2}).
% 273 RB, 14 symbols, 256QAM, 1 slot 14 symbols
% -----------------------------------------------------------
inputLen = 4000;
inputBits = randi([0 1], inputLen, 1); 

% Table 5.1.3.1-2: MCS index table 2 for PDSCH - 138 214
bitRate = 711/1024;
nlayers = 2;

carrier = nrCarrierConfig;
% Sharetechnote frame structure 
% Table 5.3.2-1 138-101-1
% https://www.etsi.org/deliver/etsi_ts/138100_138199/13810101/17.08.00_60/ts_13810101v170800p.pdf
carrier.SubcarrierSpacing = 15;  
carrier.NSizeGrid = 273;

pdschConfig = nrPDSCHConfig;
pdschConfig.Modulation = '256QAM';
pdschConfig.NumLayers = nlayers;
pdschConfig.PRBSet = 0:272;

txGrid = PDSCHToolbox(pdschConfig, carrier, bitRate, nlayers, inputBits);

[K,L,P] = size(txGrid);
NRB = carrier.NSizeGrid;   % 273
scPerRB = 12;

% Gộp 12 subcarriers thành 1 PRB bằng cách lấy trung bình năng lượng
txGridPRB = zeros(NRB, L, P);

for p = 1:P
    tmp = reshape(abs(txGrid(:,:,p)), scPerRB, NRB, L);
    txGridPRB(:,:,p) = squeeze(mean(tmp,1));  % [PRB × symbol]
end

figure;
for p = 1:P
    subplot(4,4,p);
    imagesc(txGridPRB(:,:,p));
    axis xy;
    title(['Port ', num2str(p)]);
    xlabel('OFDM Symbols');
    ylabel('PRB Index');
    colorbar;
end

sgtitle('PDSCH Resource Grid in PRB Domain');

portIdx = 1;

figure;
imagesc(txGridPRB(:,:,portIdx));
axis xy;
xlabel('OFDM Symbols');
ylabel('PRB Index');
title(['PRB-level Grid - Port ', num2str(portIdx)]);
colorbar;
