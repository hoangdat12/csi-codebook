function setupPath()
    currentFile = mfilename('fullpath');
    
    [testDir, ~, ~] = fileparts(currentFile);
    
    projectDir = fileparts(testDir);
    
    addpath(projectDir);
end