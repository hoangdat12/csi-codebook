setupPath();

%% -------- Test 1 - Pi/2-BPSK ---------
bits = randi([0 1], N, 1);

my = modulation(bits, 'PI/2-BPSK');
ref = nrSymbolModulate(bits, 'pi/2-BPSK');

assert(max(abs(my - ref)) < 1e-12, 'PI/2-BPSK mismatch');

disp('TEST PI/2-BPSK PASSED');

%% -------- Test 2 - BPSK ---------
bits = randi([0 1], N, 1);

my = modulation(bits, 'BPSK');
ref = nrSymbolModulate(bits, 'BPSK');

assert(max(abs(my - ref)) < 1e-12, 'BPSK mismatch');

disp('TEST BPSK PASSED');

%% -------- Test 3 - QPSK ---------
bits = randi([0 1], 2*floor(N/2), 1);

my = modulation(bits, 'QPSK');
ref = nrSymbolModulate(bits, 'QPSK');

assert(max(abs(my - ref)) < 1e-12, 'QPSK mismatch');

disp('TEST QPSK PASSED');

%% -------- Test 4 - 16QAM ---------
bits = randi([0 1], 4*floor(N/4), 1);

my = modulation(bits, '16QAM');
ref = nrSymbolModulate(bits, '16QAM');

assert(max(abs(my - ref)) < 1e-12, '16QAM mismatch');

disp('TEST 16QAM PASSED');

%% -------- Test 5 - 64QAM ---------
bits = randi([0 1], 6*floor(N/6), 1);

my = modulation(bits, '64QAM');
ref = nrSymbolModulate(bits, '64QAM');

assert(max(abs(my - ref)) < 1e-12, '64QAM mismatch');

disp('TEST 64QAM PASSED');

%% -------- Test 6 - 256QAM ---------
bits = randi([0 1], 8*floor(N/8), 1);

my = modulation(bits, '256QAM');
ref = nrSymbolModulate(bits, '256QAM');

assert(max(abs(my - ref)) < 1e-12, '256QAM mismatch');

disp('TEST 256QAM PASSED');
