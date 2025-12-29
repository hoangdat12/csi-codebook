%% ------- Test 1 --------
clc; clear;

N = 1000;
c_init = 42;

inBits = randi([0 1], N, 1);

out_my = scrambling(inBits, c_init);

c_nr = nrPRBS(c_init, N);

out_ref = xor(inBits, c_nr);

assert(isequal(out_my, logical(out_ref)), 'FAIL');

disp('TEST 1 PASSED');

%% ------- Test 2 --------
clc; clear;

N = 512;
c_init = 999;

bits = randi([0 1], N, 1);

y = scrambling(bits, c_init);
z = scrambling(y, c_init);

assert(isequal(logical(bits), logical(z)), 'FAIL');

disp('TEST 2 PASSED');

