function outBits = scrambling(inBits, c_init)
    N = length(inBits);

    c = GoldSequence(c_init, N);

    outBits = xor(logical(inBits(:)), c(:));
end

function c = GoldSequence(c_init, N)
    Nc = 1600;

    x1 = zeros(1,31);
    x2 = zeros(1,31);

    x1(1) = 1;

    for i = 1:31
        x2(i) = bitget(uint32(c_init), i);
    end

    for n = 1:Nc
        new_x1 = xor(x1(4), x1(1));
        new_x2 = xor(xor(x2(4), x2(3)), xor(x2(2), x2(1)));

        x1 = [x1(2:end), new_x1];
        x2 = [x2(2:end), new_x2];
    end

    c = zeros(N,1);

    for n = 1:N
        c(n) = xor(x1(1), x2(1));

        new_x1 = xor(x1(4), x1(1));
        new_x2 = xor(xor(x2(4), x2(3)), xor(x2(2), x2(1)));

        x1 = [x1(2:end), new_x1];
        x2 = [x2(2:end), new_x2];
    end

    c = logical(c);
end

