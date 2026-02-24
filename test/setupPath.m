function setupPath()
    currentFile = mfilename('fullpath');
    [testDir, ~, ~] = fileparts(currentFile);
    projectDir = fileparts(testDir);
    
    pdschDir = fullfile(projectDir, 'pdsch');
    addpath(pdschDir);

    internalDir = fullfile(projectDir, 'internal');
    addpath(internalDir);
end