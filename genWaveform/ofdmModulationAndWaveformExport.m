function outWaveform = ofdmModulationAndWaveformExport(frameGrid, fileName, W)
    NFFT = 4096; % Kích thước IFFT
    numRe = size(frameGrid, 1); % Tổng số subcarriers mang dữ liệu
    numSymb = size(frameGrid, 2); % Tổng số symbol trong frameGrid
    numTxPorts = size(W, 1);

    txdata1 = []; 

    for p = 1:numTxPorts
        % 1. Dịch tần số (IFFT shift) và chèn Zero-padding cho Port p
        txDataF_Port = [frameGrid(numRe/2+1:end, :, p); ...
                        zeros(NFFT - numRe, numSymb); ...
                        frameGrid(1:numRe/2, :, p)];
        
        temp_txdata = ofdmModulation(txDataF_Port, NFFT);
        
        txdata1 = [txdata1, temp_txdata];
    end
    fprintf('Kích thước sau OFDM (1 Frame) [Số mẫu x Số Port]::: %d x %d\n\n', size(txdata1, 1), size(txdata1, 2));

    centerFreq = 0;
    nchannel = numTxPorts; 
    nFrame = 5; 
    scs = 30000; % SCS 30kHz
    data_repeat = repmat(txdata1, nFrame, 1); 

    outWaveform = data_repeat;

    savevsarecordingmulti(fileName, data_repeat, NFFT*scs, centerFreq, nchannel);

    fprintf('Đã lưu thành công file %s với %d ports.\n', fileName, nchannel);
end