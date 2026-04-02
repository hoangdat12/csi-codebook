clear; clc; close all;

setupPath();

ALL_Case = [
    % Case 1: Default
    struct('desc', 'Case 1: Default', ...
           'NLAYERS', 4, 'MCS', 27, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 1, ...
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', 'CASE2_UE1_PDSCH_Waveform_4P4V');
];    

W = [
    0.0202 + 0.0093i  -0.0009 - 0.0178i   0.0202 + 0.0248i   0.0090 - 0.0318i;
   -0.0079 + 0.0053i  -0.0161 + 0.0100i   0.0170 - 0.0532i   0.0051 + 0.0202i;
    0.4037 - 0.1570i   0.3281 - 0.2936i   0.3908 + 0.0731i   0.2605 - 0.3098i;
    0.2296 - 0.0951i   0.2235 - 0.0743i   0.2924 + 0.0485i   0.2175 - 0.1932i
];

vsa_normalize_matrix(W);

outWaveforms = cell(length(ALL_Case), 1);

for caseIdx = 1:length(ALL_Case) 
    baseConfig = ALL_Case(caseIdx);
    outWaveforms{caseIdx} = genWaveformSumimo(baseConfig, W);
end

