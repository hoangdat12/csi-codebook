%% --- MAIN TEST SCRIPT (FULL CORRECTION) ---
clc; clear; close all;

fprintf('=== KIỂM TRA HÀM VỚI INPUT CELL ARRAY {} ===\n\n');

% =========================================================================
% TEST CASE 1: 2 Panel, Rank 1 (Mode 1)
% Input: i1 = {i11, i12, i13, i14}
% =========================================================================
fprintf('--- Test Case 1: 2 Panel, Rank 1 ---\n');
cfg1.CodebookConfig.N1 = 4;
cfg1.CodebookConfig.N2 = 1;
% BỔ SUNG O1, O2 ĐỂ HÀM KHÔNG BỊ LỖI
cfg1.CodebookConfig.O1 = 4; 
cfg1.CodebookConfig.O2 = 1;
cfg1.CodebookConfig.nPorts = 16;
cfg1.CodebookConfig.codebookMode = 1;

nLayers_1 = 1;
n_g_1 = 2;

i1_input_1 = {1, 0, [], 1}; 
i2_input_1 = 0;

try
    W1 = generateTypeIMultiPanelPrecoder(cfg1, nLayers_1, n_g_1, i1_input_1, i2_input_1)
    fprintf('=> Kết quả: OK\n\n');
catch ME
    fprintf('=> Kết quả: LỖI (%s)\n\n', ME.message);
    fprintf('   (Line: %d)\n', ME.stack(1).line);
end

% =========================================================================
% TEST CASE 2: 4 Panel, Rank 2 (Mode 1)
% Input: i1 = {2, 0, 0, [1, 0, 2]}
% =========================================================================
fprintf('--- Test Case 2: 4 Panel, Rank 2 ---\n');
cfg2.CodebookConfig.N1 = 2;
cfg2.CodebookConfig.N2 = 1;
% BỔ SUNG O1, O2
cfg2.CodebookConfig.O1 = 4;
cfg2.CodebookConfig.O2 = 1;
cfg2.CodebookConfig.nPorts = 16;
cfg2.CodebookConfig.codebookMode = 1;

nLayers_2 = 2;
n_g_2 = 4;

i1_input_2 = {2, 0, 0, [1, 0, 2]}; 
i2_input_2 = 1;

try
    W2 = generateTypeIMultiPanelPrecoder(cfg2, nLayers_2, n_g_2, i1_input_2, i2_input_2)
    fprintf('=> Kết quả: OK\n\n');
catch ME
    fprintf('=> Kết quả: LỖI (%s)\n\n', ME.message);
end

% =========================================================================
% TEST CASE 3: 2 Panel, Rank 2 (Mode 2)
% Input: i1 = {3, 0, 1, [1, 2]}
% =========================================================================
fprintf('--- Test Case 3: 2 Panel, Rank 2 (Mode 2) ---\n');
cfg3.CodebookConfig.N1 = 4;
cfg3.CodebookConfig.N2 = 1;
% BỔ SUNG O1, O2
cfg3.CodebookConfig.O1 = 4;
cfg3.CodebookConfig.O2 = 1;
cfg3.CodebookConfig.nPorts = 16;
cfg3.CodebookConfig.codebookMode = 2;

nLayers_3 = 2;
n_g_3 = 2;

i1_input_3 = {3, 0, 1, [1, 2]}; 
i2_input_3 = [0, 1, 0];

try
    W3 = generateTypeIMultiPanelPrecoder(cfg3, nLayers_3, n_g_3, i1_input_3, i2_input_3)
    fprintf('=> Kết quả: OK\n\n');
catch ME
    fprintf('=> Kết quả: LỖI (%s)\n\n', ME.message);
end
