setupPath();

% 1. Tạo chuỗi bit nhị phân ngẫu nhiên (dạng vector cột)
inputLen = 1000;
inputBits = randi([0 1], inputLen, 1, 'int8'); 

pdsch = nrPDSCHConfig;
carrier = nrCarrierConfig;

% Precoding Matrix Parameters
cfg = struct();

cfg.CodebookConfig.N1 = 4;
cfg.CodebookConfig.N2 = 2;
cfg.CodebookConfig.O1 = 4;
cfg.CodebookConfig.O2 = 4;

cfg.CodebookConfig.NumberOfBeams = 4;     % L
cfg.CodebookConfig.PhaseAlphabetSize = 8; % NPSK
cfg.CodebookConfig.SubbandAmplitude = true;
cfg.CodebookConfig.numLayers = 2;         % nLayers

i11 = [2, 1];
i12 = [55];
i13 = [4];
i14 = [4, 5, 6, 0, 2, 1, 0];
i21 = [4, 6, 1, 2];
i22 = [1, 1, 0, 0];

i1 = {i11, i12, i13, i14};
i2 = {i21, i22};

W = generateTypeIIPrecoder(cfg, i1, i2);

bitRates = 1/3;

crcEncoded = nrCRCEncode(inputBits, '16');

bgn = 2; 

cbs = nrCodeBlockSegmentLDPC(crcEncoded, bgn);

codedcbs = nrLDPCEncode(cbs, bgn);

outlen = pdsch.calculateManualG(pdsch);
rv = 0;                 % Redundancy version
modulation = 'QPSK';    % Modulation type
nlayers = 2;            % Number of layers

% Rate Matching
ratematched = nrRateMatchLDPC(codedcbs, outlen, rv, modulation, nlayers);

% Number of codewords
ncw = 1 + (nlayers > 4);

scrambled = coder.nullcopy(cell(1, ncw));
modulated = coder.nullcopy(cell(1, ncw));

% Xác định NID và RNTI
if isempty(pdsch.NID)
    nid = carrier.NCellID;
else
    nid = pdsch.NID(1);
end

rnti = pdsch.RNTI;   

if ncw==1 && numel(ratematched)==2 && isempty(ratematched{2})
    cellcws = {ratematched{1}};
else
    cellcws = ratematched;
end

% Scrambling và Modulation
for q = 1:ncw
    % Tạo chuỗi giả ngẫu nhiên PRBS
    c = nrPDSCHPRBS(nid, rnti, q-1, length(cellcws{q}));
    % Scrambling: XOR chuỗi bit với chuỗi PRBS
    scrambled{q} = bitxor(cellcws{q}, c); % Dùng bitxor chuẩn hơn cho dữ liệu số

    % Symbol Modulation (QPSK)
    modulated{q} = nrSymbolModulate(scrambled{q}, modulation);
end

% Layer Mapping
portsym = nrLayerMap(modulated, nlayers); 

disp('Quá trình xử lý PDSCH hoàn tất. Kích thước symbol đầu ra:');
disp(size(sym));

[portind,indinfo] = nrPDSCHIndices(carrier,pdsch);
[antsym,antind] = nrPDSCHPrecode(carrier,portsym,portind,W);
