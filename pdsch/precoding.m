function outPorts = precoding(inLayers, W_matrix)
    outPorts = inLayers * W_matrix.';
end