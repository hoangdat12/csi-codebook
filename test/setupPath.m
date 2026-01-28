function setupPath()
    currentFile = mfilename('fullpath');
    [testDir, ~, ~] = fileparts(currentFile);
    projectDir = fileparts(testDir);
    
    pdschDir = fullfile(projectDir, 'pdsch');
    addpath(pdschDir);
    
    disp('Đã thêm thư mục "pdsch" vào đường dẫn MATLAB.');
end