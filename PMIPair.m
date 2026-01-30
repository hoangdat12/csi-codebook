function C_mn = PMIPair(PMI_m, PMI_n)
    if any(size(PMI_m) ~= size(PMI_n))
        error('Invalid size!');
    end

    [numRows, numCols] = size(PMI_m);
    C_mn = 0;
    
    for i = 1:numRows
        for j = 1:numCols
            C_mn = C_mn + PMI_m(i,j) * conj(PMI_n(i,j));
        end
    end
end