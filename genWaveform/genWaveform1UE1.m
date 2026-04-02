clear; clc; close all;

setupPath();

ALL_Case = [
    % Case 1: Default
    struct('desc', 'Case 1: Default', ...
           'NLAYERS', 2, 'MCS', 27, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 1, ...
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', 'UE1_PDSCH_Waveform_4P2V');
];    

W = [
    0.4619 - 0.1633i   0.4444 + 0.0000i;
    -0.4619 - 0.1633i  -0.4444 + 0.0000i;
    -0.0000 - 0.1394i   0.2222 - 0.0556i;
    0.0000 - 0.0239i  -0.2222 - 0.0556i
];

vsa_normalize_matrix(W);

outWaveforms = cell(length(ALL_Case), 1);

for caseIdx = 1:length(ALL_Case) 
    baseConfig = ALL_Case(caseIdx);
    outWaveforms{caseIdx} = genWaveformSumimo(baseConfig, W);
end
