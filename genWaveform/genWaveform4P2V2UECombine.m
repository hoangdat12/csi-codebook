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
           'FILE_NAME', '2UE_Combine_PDSCH_Waveform_4P2V');
];

% -----------------------------------------------------------------
% Ma trận Trực giao được chọn ra từ hàm (findOrthognalW)
% -----------------------------------------------------------------
% W1 = [
%      0.3536 + 0.0000i   0.3536 + 0.0000i;
%    0.0000 - 0.3536i   0.0000 + 0.3536i;
%    0.3536 + 0.0000i  -0.3536 + 0.0000i;
%    0.0000 - 0.3536i   0.0000 - 0.3536i
% ];

% W2 = [
%     0.3536 + 0.0000i   0.3536 + 0.0000i;
%    0.0000 + 0.3536i   0.0000 - 0.3536i;
%    0.3536 + 0.0000i  -0.3536 + 0.0000i;
%    0.0000 + 0.3536i   0.0000 + 0.3536i
% ];

% W1 = [
%     0.5714 - 0.0000i  -0.2857 + 0.0000i;
%   -0.0000 + 0.0000i  -0.2020 - 0.2020i;
%   -0.2857 - 0.0714i   0.4041 + 0.0714i;
%    0.2525 + 0.1515i   0.3362 + 0.2352i
% ];


% W2 = [
%      0.0000 + 0.0000i   0.2872 - 0.0000i;
%    0.4061 + 0.4061i   0.2031 + 0.2031i;
%    0.3380 + 0.0000i   0.4569 - 0.0000i;
%   -0.1672 - 0.1672i   0.2513 + 0.2513i
% ];

% best_W_Final = [
%   0.1374 + 0.3481i  -0.3033 - 0.2943i   0.4054 + 0.0584i  -0.0152 + 0.1308i;
%    0.3950 + 0.1432i   0.1403 - 0.9074i  -0.6095 + 0.0848i  -0.6112 + 0.6550i;
%    0.2135 - 0.0056i   0.2365 - 0.4218i  -0.0849 + 0.2483i   0.0113 + 0.4584i;
%   -0.2199 - 0.2198i   0.4676 + 0.1519i   0.0063 - 0.3049i  -0.5524 - 0.0127i
% ];
% 
% W1 = best_W_Final(:, 1:2); 
% 
% W2 = best_W_Final(:, 3:4);

W1 = [
    0.0199 - 0.0372i   0.3094 - 0.4426i;
   0.0220 + 0.0395i   0.3496 - 0.2810i;
   0.3949 - 0.4016i   0.0721 - 0.0329i;
   0.4230 + 0.0036i   0.0172 - 0.0243i
];

W2 = [
     0.3735 + 0.2146i   0.0272 - 0.0252i;
  -0.0292 - 0.1461i  -0.0147 + 0.0062i;
   0.2511 + 0.1638i   0.6491 - 0.1261i;
   0.1077 + 0.4367i  -0.2113 + 0.1285i
    ];

% vsa_normalize_matrix(W1, W2);

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