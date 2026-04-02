clear; clc; close all;

setupPath();

ALL_Case = [
    % Case 1: Default
    struct('desc', 'Case 1: Default', ...
           'NLAYERS', 4, 'MCS', 27, ...
           'SUBCARRIER_SPACING', 30, 'NSIZE_GRID', 273, 'CYCLIC_PREFIX', "normal", ...
           'NSLOT', 0, 'NFRAME', 0, 'NCELL_ID', 20, ...
           'DMRS_CONFIGURATION_TYPE', 1, 'DMRS_TYPEA_POSITION', 2, 'DMRS_NUMCDMGROUP_WITHOUT_DATA', 2, ...
           'DMRS_LENGTH', 2, 'DMRS_ADDITIONAL_POSITION', 1, ...
           'PDSCH_MAPPING_TYPE', 'A', 'PDSCH_RNTI', 20000, 'PDSCH_PRBSET', 0:272, 'PDSCH_START_SYMBOL', 0, ...
           'FILE_NAME', '2UE_Combine_PDSCH_Waveform_8P4V');
];    

% -----------------------------------------------------------------
% Ma trận Trực giao được chọn ra từ hàm (findOrthognalWTypeIIEnhanced)
% -----------------------------------------------------------------
W1 = [
   0.0081 + 0.0134i  -0.0228 + 0.0187i  -0.0283 + 0.0292i   0.3313 + 0.0434i;
   0.0102 - 0.0089i  -0.1025 + 0.2243i   0.0302 - 0.0076i  -0.0580 - 0.2032i;
  -0.0020 - 0.0048i   0.3456 + 0.0419i  -0.0257 + 0.0053i   0.0308 - 0.0179i;
  -0.0042 - 0.0084i  -0.0462 - 0.2432i   0.0368 + 0.0039i  -0.2247 - 0.1333i;
   0.0888 - 0.1581i   0.0540 + 0.0003i   0.2999 + 0.0303i   0.0224 + 0.0696i;
   0.0820 - 0.0608i  -0.0144 - 0.0353i  -0.1850 - 0.1795i   0.0577 - 0.0886i;
  -0.1729 - 0.2489i   0.0000 - 0.0000i   0.0991 + 0.1483i  -0.0819 + 0.0059i;
  -0.2166 + 0.2596i  -0.0352 - 0.0148i  -0.1176 - 0.2058i   0.0302 + 0.0004i
];

W2 = [
   0.0161 + 0.0011i   0.0080 + 0.0026i   0.2460 + 0.0777i  -0.0036 - 0.0824i;
  -0.0060 - 0.0084i  -0.0028 - 0.0027i  -0.1851 - 0.2016i   0.0237 + 0.0155i;
   0.0043 + 0.0018i   0.0054 + 0.0012i   0.0657 + 0.2319i  -0.0533 - 0.0951i;
  -0.0102 - 0.0084i  -0.0052 - 0.0077i  -0.0060 - 0.2230i  -0.0676 + 0.1153i;
   0.3046 + 0.1405i   0.2244 - 0.2018i   0.0159 - 0.0072i   0.2621 + 0.0342i;
  -0.0083 - 0.1608i  -0.1427 - 0.2122i  -0.0127 - 0.0054i  -0.1785 - 0.1437i;
   0.1090 - 0.0182i  -0.1839 - 0.0000i   0.0059 + 0.0031i   0.1184 + 0.1498i;
  -0.2023 - 0.2405i  -0.1515 + 0.1912i  -0.0120 - 0.0043i  -0.0961 - 0.2111i
];

vsa_normalize_matrix(W1, W2);

% -----------------------------------------------------------------
% Tính lại điểm trực giao của 2 Ma trận dựa vào thuật toán
% -----------------------------------------------------------------
score = PMIPair(W1, W2);
fprintf(' * Giá trị phức (Complex)::: %8.4f %+.4fi\n', real(score), imag(score));
fprintf(' * Biên độ tuyệt đối (Abs)::: %8.4f\n\n', abs(score));

outWaveforms = cell(length(ALL_Case), 1);

for caseIdx = 1:length(ALL_Case)
    baseConfig = ALL_Case(caseIdx);
    outWaveforms{caseIdx} = genWaveformMumimo2UESameLayer(baseConfig, W1, W2);
end
