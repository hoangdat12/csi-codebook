function testTypeISinglePanel()
    clc; clear; close all;
    disp('==============================================');
    disp('      TESTING TYPE I SINGLE PANEL PRECODER    ');
    disp('==============================================');

    %% --- TEST CASE 1: 1 Layer ---
    % N1=2, N2=1, O1=4, O2=2, i11=0, i12=0, i2=0
    disp('>> CASE 1: 1 Layer');
    
    % 1. Config Structure
    cfg.CodebookConfig.nLayers = 1;
    cfg.CodebookConfig.N1 = 2;
    cfg.CodebookConfig.N2 = 1;
    cfg.CodebookConfig.O1 = 4;
    cfg.CodebookConfig.O2 = 2; 
    cfg.CodebookConfig.nPorts = 2 * cfg.CodebookConfig.N1 * cfg.CodebookConfig.N2; % 4 ports
    cfg.CodebookConfig.codebookMode = 1;

    % 2. Inputs (Cell array format as requested)
    % i1 = {i11, i12, i13, i14}
    i1 = {0, 0, 0, 0}; 
    i2 = 0;

    % 3. Call Function
    try
        W = generateTypeISinglePanelPrecoder(cfg, cfg.CodebookConfig.nLayers, i1, i2);
        disp('Result W (4x1):');
        disp(W);
    catch ME
        disp(['Error in Case 1: ' ME.message]);
    end

    %% --- TEST CASE 2: 2 Layers ---
    % N1=2, N2=1, O1=4, O2=1, i11=0, i12=0, i13=1, i2=1
    disp('----------------------------------------------');
    disp('>> CASE 2: 2 Layers');

    cfg.CodebookConfig.nLayers = 2;
    cfg.CodebookConfig.N1 = 2;
    cfg.CodebookConfig.N2 = 1;
    cfg.CodebookConfig.O1 = 4;
    cfg.CodebookConfig.O2 = 1;
    cfg.CodebookConfig.nPorts = 4;
    
    % i13 = 1
    i1 = {0, 0, 1, 0}; 
    i2 = 1;

    W = generateTypeISinglePanelPrecoder(cfg, cfg.CodebookConfig.nLayers, i1, i2);
    disp('Result W (4x2):');
    disp(W);

    %% --- TEST CASE 3: 1 Layer (High N1) ---
    % N1=8, N2=1, O1=4, O2=1, i11=4, i12=0, i2=2
    disp('----------------------------------------------');
    disp('>> CASE 3: 1 Layer (N1=8)');

    cfg.CodebookConfig.nLayers = 1;
    cfg.CodebookConfig.N1 = 8;
    cfg.CodebookConfig.N2 = 1;
    cfg.CodebookConfig.O1 = 4;
    cfg.CodebookConfig.O2 = 1;
    cfg.CodebookConfig.nPorts = 16; % 2*8*1
    
    i1 = {4, 0, 0, 0};
    i2 = 2;

    W = generateTypeISinglePanelPrecoder(cfg, cfg.CodebookConfig.nLayers, i1, i2);
    disp('Result W (First 8 rows):');
    disp(W(1:8, :));

    %% --- TEST CASE 4: 4 Layers ---
    % N1=4, N2=2, O1=4, O2=2, i11=2, i12=1, i13=0, i2=0
    disp('----------------------------------------------');
    disp('>> CASE 4: 4 Layers');

    cfg.CodebookConfig.nLayers = 4;
    cfg.CodebookConfig.N1 = 4;
    cfg.CodebookConfig.N2 = 2;
    cfg.CodebookConfig.O1 = 4;
    cfg.CodebookConfig.O2 = 2;
    cfg.CodebookConfig.nPorts = 16; % 2*4*2
    
    i1 = {2, 1, 0, 0};
    i2 = 0;

    W = generateTypeISinglePanelPrecoder(cfg, cfg.CodebookConfig.nLayers, i1, i2);
    
    disp('Result W (16x4) - First 4 rows shown:');
    disp(W(1:4, :));
    
    
end