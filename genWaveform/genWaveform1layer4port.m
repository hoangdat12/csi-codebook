clear; clc; close all;

setupPath();

ALL_Case = [
    % Case 1: Default
    struct('desc', 'Case 1: Default', ...
           'NLAYERS', 1, 'MCS', 27, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 1, 'DMRS_ADDITIONAL_POSITION', 1, ...
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', 'Case0_PDSCH_Waveform_4P1V');
];

W = [
    0.6325 + 0.0000i;
    0.4472 + 0.4472i;
   -0.0000 - 0.3162i;
   -0.2236 + 0.2236i
];
vsa_normalize_matrix(W);

outWaveforms = cell(length(ALL_Case), 1);

for caseIdx = 1:length(ALL_Case) 
    baseConfig = ALL_Case(caseIdx);
    outWaveforms{caseIdx} = genWaveformSumimo(baseConfig, W);
end