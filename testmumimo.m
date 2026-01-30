clear; clc; close all;

setupPath();

Num_UEs = 100; 
nlayers_per_ue = 2; 
Max_Total_Layers = 4; 

gNB_Params.NumAntennas = 16;
Target_Num_Users = Max_Total_Layers / nlayers_per_ue; 

pdsch_cfg = customPDSCHConfig(); 
cfg_base = struct('N1',4, 'N2',2, 'O1',4, 'O2',4, 'NumberOfBeams',4, ...
                  'PhaseAlphabetSize',8, 'SubbandAmplitude',true, 'numLayers',nlayers_per_ue);
pdsch_cfg.CodebookConfig = cfg_base;
pdsch_cfg.PRBSet = 0:51;

All_UE_Feedback = cell(1, Num_UEs);

fprintf('--- Đang sinh Type II Feedback cho %d UEs (Mỗi UE %d Layers) ---\n', Num_UEs, nlayers_per_ue);

for u = 1:Num_UEs
    rand_i11 = [randi([0 15]), randi([0 7])];
    rand_i12 = randi([0 3]); 
    pdsch_cfg.Indices.i1 = {rand_i11, rand_i12, [3, 1], [4 6 5 0 2 3 1; 3 2 4 1 5 6 0]};
    pdsch_cfg.Indices.i2 = {[1 3 4 2 5 7; 2 0 5 1 4 6], [0 1 0 1 0; 1 1 0 0 1]};
    
    try
        W = generateTypeIIPrecoder(pdsch_cfg, pdsch_cfg.Indices.i1, pdsch_cfg.Indices.i2);
    catch
        W = randn(16, nlayers_per_ue) + 1i*randn(16, nlayers_per_ue);
    end
    
    W = W ./ vecnorm(W);
    All_UE_Feedback{u} = W;
end

fprintf('\n--- Đang chạy Block SUS (Function của bạn) ---\n');

par.Us = Target_Num_Users; 
par.B  = gNB_Params.NumAntennas;
var.H  = All_UE_Feedback;  

[Selected_UE_IDs, W_Total] = Block_SUS(par, var);

if isempty(Selected_UE_IDs)
    error('Block SUS không chọn được User nào. Thử tăng số lượng mẫu hoặc kiểm tra Epsilon trong hàm.');
end

fprintf('\n--- Bắt đầu tính toán Precoding (ZF) ---\n');

W_Selected_List = [];
UE_Layer_Map = []; 

for i = 1:length(Selected_UE_IDs)
    u_id = Selected_UE_IDs(i);
    W_ue = All_UE_Feedback{u_id}; 
    
    W_Selected_List = [W_Selected_List, W_ue];
    UE_Layer_Map = [UE_Layer_Map; u_id, nlayers_per_ue];
end

H_est_Total = W_Selected_List'; 

W_ZF = pinv(H_est_Total); 

Num_Streams_Total = size(W_ZF, 2);
Scaling_Factor = 1 / sqrt(Num_Streams_Total); 
W_Final = W_ZF .* Scaling_Factor;

fprintf('Đã tạo ma trận Precoding kích thước: %d x %d\n', size(W_Final));

fprintf('\n--- Bắt đầu phát dữ liệu (Tx) ---\n');

carrier = nrCarrierConfig;
carrier.SubcarrierSpacing = 15;
carrier.NSizeGrid = 52; 

txGrid = nrResourceGrid(carrier, gNB_Params.NumAntennas);

Tx_Log = struct('UE_ID', [], 'Bits', [], 'PDSCH_Cfg', []);

current_stream_idx = 1;

for i = 1:length(Selected_UE_IDs)
    u_id = Selected_UE_IDs(i);
    if exist('UE_Layer_Map', 'var')
        num_layers = UE_Layer_Map(i, 2);
    else
        num_layers = nlayers_per_ue;
    end
    
    range_idx = current_stream_idx : (current_stream_idx + num_layers - 1);
    W_For_This_UE = W_Final(:, range_idx); 
    
    pdsch_current = pdsch_cfg;
    pdsch_current.RNTI = u_id; 
    pdsch_current.NumLayers = num_layers;
    
    [pdschInd, indinfo] = nrPDSCHIndices(carrier, pdsch_current);
    TBS = 5000; 
    inputBits = randi([0 1], TBS, 1);
    
    [antsym, antind] = PDSCHToolbox(pdsch_current, carrier, inputBits, W_For_This_UE);
    
    txGrid(antind) = txGrid(antind) + antsym;
    
    Tx_Log(i).UE_ID = u_id;
    Tx_Log(i).Bits = inputBits;
    Tx_Log(i).PDSCH_Cfg = pdsch_current;
    
    current_stream_idx = current_stream_idx + num_layers;
    
    fprintf('   + UE %d: Đã map vào Grid (Dùng cột Precoding %d-%d)\n', u_id, range_idx(1), range_idx(end));
end

[txWaveform, waveformInfo] = nrOFDMModulate(carrier, txGrid);

fprintf('\n--- Bắt đầu thu và giải mã (Rx) ---\n');

SNR_dB = 40; 

for i = 1:length(Selected_UE_IDs)
    u_id = Selected_UE_IDs(i);
    fprintf('UE %d đang giải mã... ', u_id);
    
    H_ue = All_UE_Feedback{u_id}'; 
    
    rxWave = txWaveform * H_ue.'; 
    rxWave = awgn(rxWave, SNR_dB, 'measured');
    
    rxGrid = nrOFDMDemodulate(carrier, rxWave);
    [K_rx, L_rx, R_rx] = size(rxGrid);
    
    H_eff_total = H_ue * W_Final; 
    
    if exist('UE_Layer_Map', 'var')
        num_L = UE_Layer_Map(i, 2);
        my_stream_start = sum(UE_Layer_Map(1:i-1, 2));
    else
        num_L = nlayers_per_ue;
        my_stream_start = (i-1) * num_L;
    end
    my_range = (my_stream_start + 1) : (my_stream_start + num_L);
    
    H_eff_desired = H_eff_total(:, my_range);
    
    W_eq = pinv(H_eff_desired); 
    
    pdsch_rx = Tx_Log(i).PDSCH_Cfg;
    
    pdsch_temp = pdsch_rx;
    pdsch_temp.NumLayers = 1; 
    
    [ind_1layer, ~] = nrPDSCHIndices(carrier, pdsch_temp);
    
    [sub_k, sub_l, ~] = ind2sub([carrier.NSizeGrid*12, carrier.SymbolsPerSlot, 1], double(ind_1layer));
    
    num_REs = length(ind_1layer);
    rx_raw = zeros(num_REs, R_rx);
    
    for r = 1:R_rx
        try
            idx_r = sub2ind([K_rx, L_rx], sub_k, sub_l);
            rx_raw(:, r) = rxGrid(idx_r + (r-1)*K_rx*L_rx);
        catch
            error('Lỗi kích thước Grid. Kiểm tra lại cấu hình Carrier ở Tx và Rx.');
        end
    end
    
    eq_syms = rx_raw * W_eq.';
    
    rxLLR = nrLayerDemap(eq_syms); 
    rxLLR = rxLLR{1}; 
    
    scaling_factor = mean(vecnorm(W_eq').^2); 
    noiseVar = 10^(-SNR_dB/10) * scaling_factor;
    
    rxLLR = nrSymbolDemodulate(rxLLR, pdsch_rx.Modulation, noiseVar);
    
    if isempty(pdsch_rx.NID), nid = carrier.NCellID; else, nid = pdsch_rx.NID(1); end
    c_seq = nrPDSCHPRBS(nid, pdsch_rx.RNTI, 0, length(rxLLR));
    rxLLR = rxLLR .* (1 - 2*double(c_seq));
    
    TBS = length(Tx_Log(i).Bits);
    rate_recovered = nrRateRecoverLDPC(rxLLR, TBS, pdsch_rx.TargetCodeRate, 0, pdsch_rx.Modulation, num_L);
    
    [decBits, blkErr] = nrLDPCDecode(rate_recovered, baseGraphSelection(zeros(TBS+24,1), pdsch_rx.TargetCodeRate), 25);
    [rxBits, err] = nrCRCDecode(nrCodeBlockDesegmentLDPC(decBits, baseGraphSelection(zeros(TBS+24,1), pdsch_rx.TargetCodeRate), TBS+24), '24A');
    
    numErr = biterr(double(Tx_Log(i).Bits), double(rxBits));
    if numErr == 0
        fprintf('PASS (Clean!)\n');
    else
        fprintf('FAIL (Errors: %d / %d)\n', numErr, TBS);
        fprintf('   -> Debug: Kích thước LLR: %d. NoiseVar: %.4f\n', length(rxLLR), noiseVar);
    end
end

function [antsym, antind] = PDSCHToolbox(pdschConfig, carrier, inputBits, W)
    setupPath();   

    nlayers = pdschConfig.NumLayers;

    [pdschInd, indinfo] = nrPDSCHIndices(carrier, pdschConfig);
    G = indinfo.G;  

    crcEncoded = nrCRCEncode(inputBits,'24A');
    bgn = baseGraphSelection(crcEncoded, pdschConfig.TargetCodeRate);
    cbs = nrCodeBlockSegmentLDPC(crcEncoded, bgn);
    codedcbs = nrLDPCEncode(cbs, bgn);

    rv = 0;
    ratematched = nrRateMatchLDPC(codedcbs, G, rv, pdschConfig.Modulation, nlayers);

    if isempty(pdschConfig.NID)
        nid = carrier.NCellID;
    else
        nid = pdschConfig.NID(1);
    end
    rnti = pdschConfig.RNTI;

    c = nrPDSCHPRBS(nid, rnti, 0, length(ratematched));
    scrambled = mod(ratematched + c, 2);

    modulated = nrSymbolModulate(scrambled, pdschConfig.Modulation);

    layerMappedSym = nrLayerMap(modulated, nlayers);
    fprintf('Layer Mapping ::::: %d x %d \n\n', size(layerMappedSym));

    W_transposed = W.';

    [antsym, antind] = nrPDSCHPrecode(carrier, layerMappedSym, pdschInd, W_transposed);
end