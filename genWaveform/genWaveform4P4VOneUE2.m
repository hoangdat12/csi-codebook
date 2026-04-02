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
    0.2321 - 0.3309i   0.3774 + 0.1391i   0.4134 - 0.0309i   0.1292 - 0.0777i;
    0.0583 + 0.2800i   0.2942 + 0.0220i  -0.1680 + 0.2178i   0.0313 - 0.4716i;
    0.0239 - 0.0324i   0.0125 - 0.0317i   0.0006 - 0.0337i   0.0464 - 0.0228i;
    0.0525 + 0.0216i   0.0068 + 0.0031i   0.0362 + 0.0050i  -0.0274 - 0.0224i
];

vsa_normalize_matrix(W);

outWaveforms = cell(length(ALL_Case), 1);

for caseIdx = 1:length(ALL_Case) 
    baseConfig = ALL_Case(caseIdx);
    outWaveforms{caseIdx} = genWaveformSumimo(baseConfig, W);
end