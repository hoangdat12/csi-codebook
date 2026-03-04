clear; clc; close all;

setupPath();

% -----------------------------------------------------------------
% Configuration Parameters
% -----------------------------------------------------------------
nLayers = 2;
SNR_dB = 20;
NumUEs = 20;
% The value in the range = {8, 16, 32}, because of the related RowNumber.
nTxAnts = 8;                
nRxAnts = 4;                 
sampleRate = 61440000;

N1 = 4; N2 = 1; O1 = 4; O2 = 1;
codebookMode = 1;

% Channel for test
% AWGN || Ideal || TDL
% With Ideal channel, we can't choose the PMI orthogonal 
% Because of all channel use the same PMI
channelType = "AWGN";

% Threadhold for identify PMI Pair
THREAD_HOLD = 1e-15;


% -----------------------------------------------------------------
% Carrier Configuration
% -----------------------------------------------------------------
carrier = nrCarrierConfig;
carrier.SubcarrierSpacing = 30;
% With 273 RB, we need scs 30 
carrier.NSizeGrid = 273;

% -----------------------------------------------------------------
% Find the orthogonal PMI
% -----------------------------------------------------------------
% Because of nrCQIReport function just only use 
% DMRSLength, DMRSAdditionalPosition and DMRSEnhancedR18 from PDSCH DM-RS configuration
% So the pdsch for both use in the aspect of prepareData function
pdsch = customPDSCHConfig;
pdsch.DMRS.DMRSConfigurationType = 1;
pdsch.DMRS.DMRSAdditionalPosition = 1;
pdsch.NumLayers = nLayers;

% 273 PRB
% The PDSCH channel occupies the entire bandwidth
pdsch.PRBSet = 0:272;

%--------------------------------------------------------------
% TYPE I
%--------------------------------------------------------------

% Loop from 1 to 4 layers
port = 2 * N1 * N2;
all_W = generatePrecodingMatrix(N1, N2, O1, O2, nLayers, codebookMode);

totalPmi = length(all_W);
scoreMatrix = zeros(totalPmi);

for m = 1:totalPmi
    for n = m+1:totalPmi
        score = chordalDistance(all_W{m}, all_W{n});
        scoreMatrix(m,n) = score;
        scoreMatrix(n,m) = score;
    end
end

upperScores = scoreMatrix(triu(true(size(scoreMatrix)),1));

thresholdList = 0:0.1:1;
pairCount = zeros(length(thresholdList),1);

for t = 1:length(thresholdList)
    th = thresholdList(t);
    pairCount(t) = sum(upperScores > th);
end

plot(thresholdList, pairCount, '-o')
xlabel('Chordal Distance Threshold')
ylabel('Number of Valid MU Pairs')
grid on

function W = generatePrecodingMatrix(N1, N2, O1, O2, nLayers, codebookMode)
    % Create lookup table
    [i11_lookup, i12_lookup, i13_lookup, i2_lookup] = lookupPMITable(N1, N2, O1, O2, nLayers, codebookMode);

    % Get total PMI. Because of lookup table [PMI_length x 1]
    totalPmi = length(i2_lookup);

    W = cell(totalPmi, 1);

    for pmi_value = 0:totalPmi-1
        % Matlab index start from 1.
        pmi_idx = pmi_value + 1;

        % Mapping from PMI to i11, i12, i2
        i11 = i11_lookup(pmi_idx);
        i12 = i12_lookup(pmi_idx);
        i13 = i13_lookup(pmi_idx);
        i2  = i2_lookup(pmi_idx);

        cfg = getCfigVariable(N1, N2, O1, O2, codebookMode);

        i1 = {i11, i12, i13};

        W_raw = generateTypeISinglePanelPrecoder(cfg, nLayers, i1, i2);
        W{pmi_idx} = complex(W_raw);
    end
end

function cfg = getCfigVariable(N1, N2, O1, O2, codebookMode)
    cfg.CodebookConfig.N1 = N1;
    cfg.CodebookConfig.N2 = N2;
    cfg.CodebookConfig.O1 = O1;
    cfg.CodebookConfig.O2 = O2;
    cfg.CodebookConfig.nPorts = 2*N1*N2;
    cfg.CodebookConfig.codebookMode = codebookMode;
end

function [i11_lookup, ...
    i12_lookup, ...
    i13_lookup, ...
    i2_lookup ...
] = lookupPMITable(N1, N2, O1, O2, nLayers, codebookMode)
    % Find the end value of each range of each value [i11, i12, i13, 14]
    % Because of they all start at the 0 value and end with X value
    % X will be returned at this function
    [idx11_end, idx12_end, idx13_end, idx2_end] = findRangeValues(N1, N2, O1, O2, nLayers, codebookMode);

    % After determined range values of i11, i12, i13, i2
    % Create Lookup table.
    [i11_lookup, i12_lookup, i13_lookup, i2_lookup] = genLookupTable(idx11_end, idx12_end, idx13_end, idx2_end);
end

function [i11_lookup, i12_lookup, i13_lookup, i2_lookup] = genLookupTable(idx11_end, idx12_end, idx13_end, idx2_end)
    % The number of PMI index
    N = (idx11_end+1) * (idx12_end+1) * ...
        (idx13_end+1) * (idx2_end+1);

    % Preallocate
    i11_lookup = zeros(N,1);
    i12_lookup = zeros(N,1);
    i13_lookup = zeros(N,1);
    i2_lookup  = zeros(N,1);

    n = 1;
    for idx11 = 0:idx11_end
        for idx12 = 0:idx12_end
            for idx13 = 0:idx13_end
                for idx2 = 0:idx2_end
                    i11_lookup(n) = idx11;
                    i12_lookup(n) = idx12;
                    i13_lookup(n) = idx13;
                    i2_lookup(n)  = idx2;
                    n = n + 1;
                end
            end
        end
    end
end
