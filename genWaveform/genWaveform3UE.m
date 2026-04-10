clear; clc; close all;

setupPath();

ALL_Case = [
    % Case 1: Default
    struct('desc', 'Case 1: Default', ...
           'NLAYERS', 2, 'MCS', 27, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 2, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 2, 'DMRS_ADDITIONAL_POSITION', 1, ...
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', '3UE_Combine_PDSCH_Waveform_8P2V');
];    

% -----------------------------------------------------------------
% Ma trận Trực giao được chọn ra từ hàm (findOrthognalWTypeIIEnhanced)
% -----------------------------------------------------------------
W1 = [
   0.2500 + 0.0000i   0.2500 + 0.0000i;
   0.1768 + 0.1768i   0.1768 - 0.1768i;
   0.0000 + 0.2500i   0.0000 - 0.2500i;
  -0.1768 + 0.1768i  -0.1768 - 0.1768i;
   0.0000 + 0.2500i   0.0000 - 0.2500i;
  -0.1768 + 0.1768i  -0.1768 - 0.1768i;
  -0.2500 + 0.0000i  -0.2500 + 0.0000i;
  -0.1768 - 0.1768i  -0.1768 + 0.1768i
];

W2 = [
   0.2500 + 0.0000i   0.2500 + 0.0000i;
  -0.1768 + 0.1768i  -0.1768 + 0.1768i;
   0.0000 - 0.2500i   0.0000 - 0.2500i;
   0.1768 + 0.1768i   0.1768 + 0.1768i;
   0.0000 + 0.2500i   0.0000 - 0.2500i;
  -0.1768 - 0.1768i   0.1768 + 0.1768i;
   0.2500 + 0.0000i  -0.2500 + 0.0000i;
  -0.1768 + 0.1768i   0.1768 - 0.1768i
];

W3 = [
   0.2500 + 0.0000i   0.2500 + 0.0000i;
  -0.1768 - 0.1768i  -0.1768 - 0.1768i;
   0.0000 + 0.2500i   0.0000 + 0.2500i;
   0.1768 - 0.1768i   0.1768 - 0.1768i;
   0.2500 + 0.0000i  -0.2500 + 0.0000i;
  -0.1768 - 0.1768i   0.1768 + 0.1768i;
   0.0000 + 0.2500i   0.0000 - 0.2500i;
   0.1768 - 0.1768i  -0.1768 + 0.1768i
];

outWaveforms = cell(length(ALL_Case), 1);

for caseIdx = 1:length(ALL_Case)
    baseConfig = ALL_Case(caseIdx);
    nLayers = baseConfig.NLAYERS;
    numTxPorts = size(W1, 1);

    % -----------------------------------------------------------------
    % Carrier Configuration
    % -----------------------------------------------------------------
    carrier = nrCarrierConfig;
    
    % Lấy dữ liệu từ struct hiện tại bằng ALL_Case(caseIdx).
    carrier.SubcarrierSpacing = baseConfig.SUBCARRIER_SPACING;  
    carrier.NSizeGrid         = baseConfig.NSIZE_GRID;
    carrier.CyclicPrefix      = baseConfig.CYCLIC_PREFIX;
    carrier.NSlot             = baseConfig.NSLOT;
    carrier.NFrame            = baseConfig.NFRAME;
    carrier.NCellID           = baseConfig.NCELL_ID;

    % -----------------------------------------------------------------
    % PDSCH Configuration
    % -----------------------------------------------------------------
    % =================================================================
    % KHỞI TẠO PDSCH CHO UE 1
    % =================================================================
    pdsch1 = customPDSCHConfig(); 

    pdsch1.DMRS.DMRSConfigurationType   = baseConfig.DMRS_CONFIGURATION_TYPE; 
    pdsch1.DMRS.DMRSTypeAPosition       = baseConfig.DMRS_TYPEA_POSITION; 
    pdsch1.DMRS.NumCDMGroupsWithoutData = baseConfig.DMRS_NUMCDMGROUP_WITHOUT_DATA;
    pdsch1.DMRS.DMRSLength              = baseConfig.DMRS_LENGTH;
    pdsch1.DMRS.DMRSAdditionalPosition  = baseConfig.DMRS_ADDITIONAL_POSITION;

    pdsch1.NumLayers   = nLayers;
    pdsch1.MappingType = baseConfig.PDSCH_MAPPING_TYPE;
    pdsch1.RNTI        = baseConfig.PDSCH_RNTI;
    pdsch1.PRBSet      = baseConfig.PDSCH_PRBSET;
    pdsch1.SymbolAllocation = [baseConfig.PDSCH_START_SYMBOL, 14 - baseConfig.PDSCH_START_SYMBOL];
    pdsch1 = pdsch1.setMCS(baseConfig.MCS);

    % Phân bổ DMRS Port và Scrambling ID cho UE 1
    pdsch1.DMRS.DMRSPortSet = 0 : 1;
    pdsch1.DMRS.NSCID = 0;

    % =================================================================
    % KHỞI TẠO PDSCH CHO UE 2
    % =================================================================
    pdsch2 = customPDSCHConfig(); 

    pdsch2.DMRS.DMRSConfigurationType   = baseConfig.DMRS_CONFIGURATION_TYPE; 
    pdsch2.DMRS.DMRSTypeAPosition       = baseConfig.DMRS_TYPEA_POSITION; 
    pdsch2.DMRS.NumCDMGroupsWithoutData = baseConfig.DMRS_NUMCDMGROUP_WITHOUT_DATA;
    pdsch2.DMRS.DMRSLength              = baseConfig.DMRS_LENGTH;
    pdsch2.DMRS.DMRSAdditionalPosition  = baseConfig.DMRS_ADDITIONAL_POSITION;

    pdsch2.NumLayers   = nLayers;
    pdsch2.MappingType = baseConfig.PDSCH_MAPPING_TYPE;
    pdsch2.RNTI        = baseConfig.PDSCH_RNTI + 1; 
    pdsch2.PRBSet      = baseConfig.PDSCH_PRBSET;
    pdsch2.SymbolAllocation = [baseConfig.PDSCH_START_SYMBOL, 14 - baseConfig.PDSCH_START_SYMBOL];
    pdsch2 = pdsch2.setMCS(baseConfig.MCS);

    pdsch2.DMRS.DMRSPortSet = 2:3;
    pdsch2.DMRS.NSCID = 0;

     % =================================================================
    % KHỞI TẠO PDSCH CHO UE 3
    % =================================================================
    pdsch3 = customPDSCHConfig(); 

    pdsch3.DMRS.DMRSConfigurationType   = baseConfig.DMRS_CONFIGURATION_TYPE; 
    pdsch3.DMRS.DMRSTypeAPosition       = baseConfig.DMRS_TYPEA_POSITION; 
    pdsch3.DMRS.NumCDMGroupsWithoutData = baseConfig.DMRS_NUMCDMGROUP_WITHOUT_DATA;
    pdsch3.DMRS.DMRSLength              = baseConfig.DMRS_LENGTH;
    pdsch3.DMRS.DMRSAdditionalPosition  = baseConfig.DMRS_ADDITIONAL_POSITION;

    pdsch3.NumLayers   = nLayers;
    pdsch3.MappingType = baseConfig.PDSCH_MAPPING_TYPE;
    pdsch3.RNTI        = baseConfig.PDSCH_RNTI + 2; 
    pdsch3.PRBSet      = baseConfig.PDSCH_PRBSET;
    pdsch3.SymbolAllocation = [baseConfig.PDSCH_START_SYMBOL, 14 - baseConfig.PDSCH_START_SYMBOL];
    pdsch3 = pdsch3.setMCS(baseConfig.MCS);

    pdsch3.DMRS.DMRSPortSet = 4:5;
    pdsch3.DMRS.NSCID = 0;

    % =================================================================
    % TẠO BITS (GENERATE BITS)
    % =================================================================
    TBS1 = manualCalculateTBS(pdsch1);
    TBS2 = manualCalculateTBS(pdsch2);
    TBS3 = manualCalculateTBS(pdsch3);

    fprintf('Số lượng Bits đầu vào (TBS) của UE1::: %d bits\n', TBS1);
    fprintf('Số lượng Bits đầu vào (TBS) của UE2::: %d bits\n\n', TBS2);
    fprintf('Số lượng Bits đầu vào (TBS) của UE2::: %d bits\n\n', TBS3);

    inputBits1 = ones(TBS1, 1);
    inputBits2 = zeros(TBS2, 1);
    inputBits3 = ones(TBS3, 1);

    % =================================================================
    % ĐIỀU CHẾ PDSCH VÀ DMRS (MODULATION)
    % =================================================================
    [layerMappedSym1, pdschInd1] = myPDSCHEncode(pdsch1, carrier, inputBits1);
    [layerMappedSym2, pdschInd2] = myPDSCHEncode(pdsch2, carrier, inputBits2);
    [layerMappedSym3, pdschInd3] = myPDSCHEncode(pdsch3, carrier, inputBits3);

    fprintf('Kích thước Symbols sau Layer Mapping của UE1 [REs x Layers]::: %d x %d\n', size(layerMappedSym1, 1), size(layerMappedSym1, 2));
    fprintf('Kích thước Symbols sau Layer Mapping của UE2 [REs x Layers]::: %d x %d\n\n', size(layerMappedSym2, 1), size(layerMappedSym2, 2));

    dmrsSym1 = genDMRS(carrier, pdsch1);
    dmrsInd1 = DMRSIndices(pdsch1, carrier);

    dmrsSym2 = genDMRS(carrier, pdsch2);
    dmrsInd2 = DMRSIndices(pdsch2, carrier);

    dmrsSym3 = genDMRS(carrier, pdsch3);
    dmrsInd3 = DMRSIndices(pdsch3, carrier);

    fprintf('Kích thước DMRS Symbols của UE1 [REs x Layers]::: %d x %d\n', size(dmrsSym1, 1), size(dmrsSym1, 2));
    fprintf('Kích thước DMRS Symbols của UE2 [REs x Layers]::: %d x %d\n\n', size(dmrsSym2, 1), size(dmrsSym2, 2));

    % =========================================================================
    % Precoding + Mapping cho Slot chứa data
    % =========================================================================
    nPorts = size(W1, 1); 
    nLayers1 = pdsch1.NumLayers;
    nLayers2 = pdsch2.NumLayers;
    nLayers3 = pdsch3.NumLayers;
    K = carrier.NSizeGrid * 12;
    symbolsPerSlot = carrier.SymbolsPerSlot;
    currentSlotIdx = carrier.NSlot; 

    layerGrid_UE1 = zeros(K, symbolsPerSlot, nLayers1);
    layerGrid_UE2 = zeros(K, symbolsPerSlot, nLayers2);
    layerGrid_UE3 = zeros(K, symbolsPerSlot, nLayers3);

    % Map PDSCH và DMRS cho UE 1 
    for layer = 1:nLayers1
        layerGrid_UE1(pdschInd1(:, layer)) = layerMappedSym1(:, layer);
        layerGrid_UE1(dmrsInd1(:, layer))  = dmrsSym1(:, layer);
    end

    % Map PDSCH và DMRS cho UE 2
    for layer = 1:nLayers2
        layerGrid_UE2(pdschInd2(:, layer)) = layerMappedSym2(:, layer);
        layerGrid_UE2(dmrsInd2(:, layer))  = dmrsSym2(:, layer);
    end

    % Map PDSCH và DMRS cho UE 3
    for layer = 1:nLayers3
        layerGrid_UE3(pdschInd3(:, layer)) = layerMappedSym3(:, layer);
        layerGrid_UE3(dmrsInd3(:, layer))  = dmrsSym3(:, layer);
    end

    % Chuyển Layer Grid thành mảng 2D [(K*14) x nLayers] để nhân Precoding matrix
    layerGrid_flat_UE1 = reshape(layerGrid_UE1, K * symbolsPerSlot, nLayers1);
    layerGrid_flat_UE2 = reshape(layerGrid_UE2, K * symbolsPerSlot, nLayers2);
    layerGrid_flat_UE3 = reshape(layerGrid_UE3, K * symbolsPerSlot, nLayers3);

    % Precoding
    % Output size: [(K*14) x nPorts]
    portGrid_flat_UE1 = layerGrid_flat_UE1 * (W1.'); 
    portGrid_flat_UE2 = layerGrid_flat_UE2 * (W2.'); 
    portGrid_flat_UE3 = layerGrid_flat_UE3 * (W3.'); 

    % Chuyển về Grid 3D cho 2 UE
    portGrid_UE1 = reshape(portGrid_flat_UE1, K, symbolsPerSlot, nPorts);
    portGrid_UE2 = reshape(portGrid_flat_UE2, K, symbolsPerSlot, nPorts);
    portGrid_UE3 = reshape(portGrid_flat_UE3, K, symbolsPerSlot, nPorts);

    % Cộng dồn dữ liệu cho 2 UE trên cùng 1 Grid
    portGrid_Combined = portGrid_UE1 + portGrid_UE2 + portGrid_UE3;

    fprintf('[Slot %d] Kích thước [Subcarriers x Symbols x Ports]::: %d x %d x %d\n', ...
        currentSlotIdx, size(portGrid_Combined, 1), size(portGrid_Combined, 2), size(portGrid_Combined, 3));
    fprintf('[Slot %d] Số lượng RE mang dữ liệu (khác 0)::: %d REs\n\n', ...
        currentSlotIdx, nnz(portGrid_Combined));

    % =========================================================================
    % Mapping từ slot chứa data lên Toàn bộ Frame
    % =========================================================================
    frameGrid    = zeros(K, 280, nPorts); 

    startSym = currentSlotIdx * symbolsPerSlot + 1;
    endSym   = (currentSlotIdx + 1) * symbolsPerSlot;

    frameGrid(:, startSym:endSym, :)    = portGrid_Combined;

    fprintf('[Toàn Frame] Kích thước [Subcarriers x Symbols x Ports]::: %d x %d x %d\n', ...
        size(frameGrid, 1), size(frameGrid, 2), size(frameGrid, 3));
    fprintf('[Toàn Frame] Số lượng RE mang dữ liệu (khác 0)::: %d REs\n', ...
        nnz(frameGrid));
    fprintf('[Toàn Frame] Tổng số RE trên Frame::: %d REs\n\n', ...
        numel(frameGrid));

    % =========================================================================
    % 4. Export waveform
    % =========================================================================
    outWaveform = ofdmModulationAndWaveformExport(frameGrid, baseConfig.FILE_NAME, W1);
end
