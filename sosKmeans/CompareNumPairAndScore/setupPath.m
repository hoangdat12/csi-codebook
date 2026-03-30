function setupPath()
    currentFile = mfilename('fullpath');
    
    % Lấy đường dẫn thư mục C (nơi chứa file hiện tại)
    [dirC, ~, ~] = fileparts(currentFile); 
    
    % Lùi lên 1 cấp để lấy thư mục B (cha của C)
    [dirB, ~, ~] = fileparts(dirC);        
    
    % Lùi thêm 1 cấp nữa để lấy thư mục A (cha của B)
    [dirA, ~, ~] = fileparts(dirB);        
    
    % Thêm thư mục A và toàn bộ thư mục con (bao gồm cả B và C) vào Path của MATLAB
    addpath(genpath(dirA));
end