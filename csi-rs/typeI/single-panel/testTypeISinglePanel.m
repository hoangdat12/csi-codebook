function testTypeISinglePanel()
    clc; clear; close all;
    disp('==============================================');
    disp('      TESTING TYPE I SINGLE PANEL PRECODER    ');
    disp('==============================================');

    %% --- TEST CASE 1: 1 Layer (4 Ports) ---
    % Correction: Per Table 5.2.2.2.1-2, if N1=2, N2=1, then O2 must be 1.
    disp('>> CASE 1: 1 Layer (4 Ports)');
    
    cfg.CodebookConfig.nLayers = 1;
    cfg.CodebookConfig.N1 = 2;
    cfg.CodebookConfig.N2 = 1;
    cfg.CodebookConfig.O1 = 4;
    cfg.CodebookConfig.O2 = 1; % FIXED: Changed from 2 to 1
    cfg.CodebookConfig.nPorts = 4;
    cfg.CodebookConfig.codebookMode = 1;

    % Removed redundant 4th element. i1 structure is {i1_1, i1_2, i1_3}
    i1 = {0, 0, 0}; 
    i2 = 0;

    % Call your existing function
    try
        W = generateTypeISinglePanelPrecoder(cfg, cfg.CodebookConfig.nLayers, i1, i2);
        disp('Result W (4x1):');
        disp(W);
    catch ME
        disp(['Error in Case 1: ' ME.message]);
    end

    %% --- TEST CASE 2: 2 Layers (4 Ports) ---
    % Valid config: 4 Ports, N1=2, N2=1, O2=1
    disp('----------------------------------------------');
    disp('>> CASE 2: 2 Layers');

    cfg.CodebookConfig.nLayers = 2;
    % Reuse N1, N2, O1, O2, nPorts from Case 1
    
    i1 = {0, 0, 1}; 
    i2 = 1;

    try
        W = generateTypeISinglePanelPrecoder(cfg, cfg.CodebookConfig.nLayers, i1, i2);
        disp('Result W (4x2):');
        disp(W);
    catch ME
        disp(['Error in Case 2: ' ME.message]);
    end

    %% --- TEST CASE 3: 1 Layer (16 Ports - High N1) ---
    % Valid config: 16 Ports, N1=8, N2=1 -> O2=1
    disp('----------------------------------------------');
    disp('>> CASE 3: 1 Layer (N1=8)');

    cfg.CodebookConfig.nLayers = 1;
    cfg.CodebookConfig.N1 = 8;
    cfg.CodebookConfig.N2 = 1;
    cfg.CodebookConfig.O1 = 4;
    cfg.CodebookConfig.O2 = 1;
    cfg.CodebookConfig.nPorts = 16; 
    
    i1 = {4, 0, 0};
    i2 = 2;

    try
        W = generateTypeISinglePanelPrecoder(cfg, cfg.CodebookConfig.nLayers, i1, i2);
        disp('Result W (First 8 rows):');
        if ~isempty(W)
            disp(W(1:8, :));
        end
    catch ME
        disp(['Error in Case 3: ' ME.message]);
    end

    %% --- TEST CASE 4: 4 Layers (16 Ports - Grid) ---
    % Correction: Per Table 5.2.2.2.1-2, if N1=4, N2=2 (16 ports), O2 must be 4.
    disp('----------------------------------------------');
    disp('>> CASE 4: 4 Layers');

    cfg.CodebookConfig.nLayers = 4;
    cfg.CodebookConfig.N1 = 4;
    cfg.CodebookConfig.N2 = 2;
    cfg.CodebookConfig.O1 = 4;
    cfg.CodebookConfig.O2 = 4; % FIXED: Changed from 2 to 4
    cfg.CodebookConfig.nPorts = 16; 
    
    i1 = {2, 1, 0}; 
    i2 = 0;

    try
        W = generateTypeISinglePanelPrecoder(cfg, cfg.CodebookConfig.nLayers, i1, i2);
        disp('Result W (16x4) - First 4 rows shown:');
        if ~isempty(W)
            disp(W(1:4, :));
        end
    catch ME
        disp(['Error in Case 4: ' ME.message]);
    end
end