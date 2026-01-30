inputLen = 4000;
inputBits = randi([0 1], inputLen, 1); 

nlayers = 2;

carrier = nrCarrierConfig;
% Sharetechnote frame structure 
% Table 5.3.2-1 138-101-1
% https://www.etsi.org/deliver/etsi_ts/138100_138199/13810101/17.08.00_60/ts_13810101v170800p.pdf
carrier.SubcarrierSpacing = 15;  
carrier.NSizeGrid = 273;

cfg = struct();
cfg.N1 = 4;
cfg.N2 = 2;
cfg.O1 = 4;
cfg.O2 = 4;
cfg.NumberOfBeams = 4;
cfg.PhaseAlphabetSize = 8;
cfg.SubbandAmplitude = true;
cfg.numLayers = nlayers;

i11 = [2, 1];
i12 = 2;
i13 = [3, 1];
i14 = [4, 6, 5, 0, 2, 3, 1 ; 3, 2, 4, 1, 5, 6, 0];
i21 = [1, 3, 4, 2, 5, 7 ; 2, 0, 5, 1, 4, 6];
i22 = [0, 1, 0, 1, 0 ; 1, 1, 0, 0, 1];

pdsch = customPDSCHConfig(); 

% Table 5.1.3.1-2: MCS index table 2 for PDSCH - 138 214
% https://www.etsi.org/deliver/etsi_ts/138200_138299/138214/18.06.00_60/ts_138214v180600p.pdf
pdsch = pdsch.setMCS(21); 

pdsch.CodebookConfig = cfg;

pdsch.Indices.i1 = {i11, i12, i13, i14};
pdsch.Indices.i2 = {i21, i22};

pdsch.NumLayers = nlayers;
% 273 PRB
pdsch.PRBSet = 0:272;

[pdschInd, indinfo] = nrPDSCHIndices(carrier, pdsch);
G = indinfo.G;  

% -----------------------------------------------------------
% LDPC Coding Chain (3GPP TS 38.212)
% 1. CRC Attachment
% 2. Base Graph Selection
% 3. Code Block Segmentation
% 4. LDPC Encoding
% 5. Rate Matching
% -----------------------------------------------------------
crcEncoded = nrCRCEncode(inputBits,'24A');
bgn = baseGraphSelection(crcEncoded, pdsch.TargetCodeRate);
cbs = nrCodeBlockSegmentLDPC(crcEncoded, bgn);
codedcbs = nrLDPCEncode(cbs, bgn);

rv = 0;
ratematched = nrRateMatchLDPC(codedcbs, G, rv, pdsch.Modulation, nlayers);

% -----------------------------------------------------------
% Scrambling and Symbol Modulation
% Generating scrambled bits using NCellID and RNTI.
% -----------------------------------------------------------
if isempty(pdsch.NID)
    nid = carrier.NCellID;
else
    nid = pdsch.NID(1);
end
rnti = pdsch.RNTI;

c = nrPDSCHPRBS(nid, rnti, 0, length(ratematched));
scrambled = mod(ratematched + c, 2);

modulated = nrSymbolModulate(scrambled, pdsch.Modulation);

layerMappedSym = nrLayerMap(modulated, nlayers);

% -----------------------------------------------------------
% PRECODING MATRIX GENERATION
% Matrix W dimensions: [numberOfPorts x nLayers] -> [16 x 2]
% Type II Precoding creates a non-orthogonal matrix.
% -----------------------------------------------------------
W = generateTypeIIPrecoder(pdsch, pdsch.Indices.i1, pdsch.Indices.i2);

% The function nrPDSCHPrecode requires the W matrix format: [nLayers x nPorts].
W_transposed = W.';

% antsym = [NRE x P]
% NRE = NRB x 12 x nsymbol
[antsym, antind] = nrPDSCHPrecode(carrier, layerMappedSym, pdschInd, W_transposed);

pdsch.DMRS.DMRSConfigurationType = 1;
pdsch.DMRS.DMRSAdditionalPosition = 1;

% 2. Tạo DMRS Symbols và Indices
dmrsSym = nrPDSCHDMRS(carrier, pdsch);
dmrsInd = nrPDSCHDMRSIndices(carrier, pdsch);

% 3. Precode DMRS (Dùng chung ma trận W_transposed với Data)
% DMRS phải đi qua cùng precoder với data để Rx ước lượng được kênh hiệu dụng
[dmrsAntSym, dmrsAntInd] = nrPDSCHPrecode(carrier, dmrsSym, dmrsInd, W_transposed);

txGrid = nrResourceGrid(carrier, 2 * cfg.N1 * cfg.N2); 
txGrid(antind) = antsym;
txGrid(dmrsAntInd) = dmrsAntSym;  % Map DMRS vào lưới (Dòng này mới)

[txWaveform, waveformInfo] = nrOFDMModulate(carrier, txGrid);


%% ========================================================================
%%                    PHẦN THU (RX PROCESSING CHAIN)
%% ========================================================================
disp(' ');
disp('--- BẮT ĐẦU QUÁ TRÌNH GIẢI MÃ (RX) ---');

% 1. Giả lập kênh truyền (Channel Simulation)
% Thêm một chút nhiễu (SNR 40dB) để bộ giải mã Soft-bit hoạt động hiệu quả
% Nếu không có nhiễu, giá trị LLR sẽ tiến tới vô cùng, đôi khi gây lỗi tính toán.
%% ===================== KÊNH TRUYỀN (CHANNEL) =====================
% Cấu hình số anten thu thực tế (UE thường chỉ có 2 hoặc 4)
NRxAnt = 2; 
NumTxAnt = size(txWaveform, 2); % 16

% Tạo ma trận kênh Rayleigh (Flat Fading) [Rx x Tx]
H = (randn(NRxAnt, NumTxAnt) + 1j*randn(NRxAnt, NumTxAnt)) / sqrt(2);

% Nhân tín hiệu phát với kênh truyền: [Time x Tx] * [Tx x Rx]^T
rxWaveform_Fading = txWaveform * H.'; 

% Thêm nhiễu
rxWaveform = awgn(rxWaveform_Fading, SNR_dB, 'measured');



% 2. OFDM Demodulation (Chuyển từ miền Thời gian -> Tần số)
% Output: [Subcarriers x Symbols x Antennas]
rxGrid = nrOFDMDemodulate(carrier, rxWaveform);

% =========================================================
% [THAY ĐỔI] CHANNEL ESTIMATION & EQUALIZATION (Thay cho pinv(W))
% =========================================================
% 1. Tạo DMRS tham chiếu tại phía thu
refDmrsSym = nrPDSCHDMRS(carrier, pdsch);
refDmrsInd = nrPDSCHDMRSIndices(carrier, pdsch);

% 2. Ước lượng kênh truyền (H_eff = Channel * Precoder)
% Hàm này sẽ tự tìm DMRS trên rxGrid và so sánh với refDmrsSym
[Hest, nVar] = nrChannelEstimate(carrier, rxGrid, refDmrsInd, refDmrsSym);

% 3. Trích xuất dữ liệu và kênh truyền tại vị trí PDSCH
% Thay vì chỉ lấy rxSymbols, ta lấy cả Hest tương ứng tại vị trí đó
[pdschRx, pdschHest] = nrExtractResources(pdschInd, rxGrid, Hest);

% 4. Cân bằng MMSE (Thay thế đoạn nhân Inv_W cũ)
% Hàm này dùng Hest để gỡ bỏ tác động của kênh và Precoder
[eqSymbols, csi] = nrEqualizeMMSE(pdschRx, pdschHest, nVar);

% 5. Layer Demapping (Tách Layer về dạng Codeword)
% Kết quả trả về là Cell Array (do cấu trúc chuẩn 5G hỗ trợ 2 codewords)
demappedSym_Cell = nrLayerDemap(eqSymbols);
sym_to_demod = demappedSym_Cell{1}; % Lấy dữ liệu Codeword 0

% 6. Symbol Demodulation (Giải điều chế QAM -> Soft bits LLR)
noiseVar = 10^(-SNR_dB/10); % Tính phương sai nhiễu
rawLLR = nrSymbolDemodulate(sym_to_demod, pdsch.Modulation, noiseVar);

% 7. Descrambling (Giải mã xáo trộn)
if isempty(pdsch.NID), nid = carrier.NCellID; else, nid = pdsch.NID(1); end
c_seq_rx = nrPDSCHPRBS(nid, pdsch.RNTI, 0, length(rawLLR));

% Công thức giải scramble cho Soft-bit: LLR_out = LLR_in * (1 - 2*c)
descrambledBits = rawLLR .* (1 - 2*double(c_seq_rx));

% 8. LDPC Decoding Chain (Giải mã kênh)
% A. Rate Recovery (Khôi phục tốc độ)
TBS = length(inputBits); % Lấy kích thước gói tin gốc
rv = 0; 
% Lưu ý: Tham số rv đứng TRƯỚC modulation
raterecovered = nrRateRecoverLDPC(descrambledBits, TBS, pdsch.TargetCodeRate, ...
                                  rv, pdsch.Modulation, nlayers);

% B. Base Graph Selection (Chọn đồ thị cơ sở)
crcEnc_dummy = zeros(TBS + 24, 1); 
bgn_rx = baseGraphSelection(crcEnc_dummy, pdsch.TargetCodeRate);

% C. LDPC Decoding
% maxIter = 25 (Số vòng lặp tối đa)
[decBits, blkErr] = nrLDPCDecode(raterecovered, bgn_rx, 25);

% D. Code Block Desegmentation (Ghép đoạn - Bắt buộc nếu gói tin lớn)
[rxPart, segErr] = nrCodeBlockDesegmentLDPC(decBits, bgn_rx, TBS + 24);

% E. CRC Decoding (Kiểm tra lỗi)
[rxBits, hasError] = nrCRCDecode(rxPart, '24A');

%% ========================================================================
%%                    KIỂM TRA KẾT QUẢ
%% ========================================================================
% Ép kiểu về cột dọc (:) và double để tránh lỗi Dimension Mismatch
numErrors = biterr(double(inputBits(:)), double(rxBits(:)));
BER = numErrors / TBS;

disp(BER);