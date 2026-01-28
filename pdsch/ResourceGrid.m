%% RESOURCE GRID GENERATION (PER SLOT)
% 3GPP TS 38.211 Section 4.3.2 (Resource Grid)
% -----------------------------------------------------------
% Generates an empty complex 3D resource grid for a single slot.
% The grid dimensions are mapped as: [K x L x P]
%   K (Rows)  : Number of subcarriers (N_grid_size * 12)
%   L (Cols)  : Number of OFDM symbols per slot (e.g., 14 for Normal CP)
%   P (Pages) : Number of antenna ports
% -----------------------------------------------------------
function grid = ResourceGrid(carrier, nPorts)

    % Calculate total number of subcarriers (K)
    % 1 Resource Block (RB) is fixed to 12 Subcarriers in 5G NR
    nSizeGrid = double(carrier.NSizeGrid) * 12; 

    % Retrieve number of OFDM symbols per slot (L)
    symbolsPerSlot = carrier.SymbolsPerSlot;

    % -----------------------------------------------------------
    % Initialize the grid with complex zeros.
    % Data type is explicitly set to complex double for high-precision IFFT.
    % -----------------------------------------------------------
    grid = complex(zeros([nSizeGrid, symbolsPerSlot, nPorts], 'double'));
end