% ------------------------------------------------------------------
% This function use to generate a CRC sequence.
% The length of this sequence depended on the TYPE parameters.
% The output format: [1 x L]
% Reference: 5.1 TS 138 212
% ------------------------------------------------------------------
function crc_bits = createCRC(data_bits, type)
    % CRC generator polynomials (binary vector form, MSB-first)
    poly_CRC24A = [1 1 0 0 0 0 1 1 0 0 1 0 0 1 1 0 0 1 1 1 1 1 0 1 1];
    poly_CRC24B = [1 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 1 0 0 0 1 1]; 
    poly_CRC24C = [1 1 0 1 1 0 0  1 0 1 0 1 1 0 0 0 1 0 0 0 1 0 1 1 1];
    poly_CRC16  = [1 0 0 0 1 0 0 0 0 0 0 1 0 0 0 0 1];                
    poly_CRC11  = [1 1 1 0 0 0 1 0 0 0 0 1];                        
    poly_CRC6   = [1 1 0 0 0 0 1];                                 

    % Select polynomial and CRC length
    switch upper(type)
        case '24A'
            crc_len = 24; poly_val = poly_CRC24A;
        case '24B'
            crc_len = 24; poly_val = poly_CRC24B;
        case '24C'
            crc_len = 24; poly_val = poly_CRC24C;
        case '16'
            crc_len = 16; poly_val = poly_CRC16;
        case '11'
            crc_len = 11; poly_val = poly_CRC11;
        case '6'
            crc_len = 6;  poly_val = poly_CRC6;
        otherwise
            error("Invalid CRC type. Choose from: '24A', '24B', '24C', '16', '11', or '6'.");
    end

    % Ensure row vector, logical for speed
    data_bits = logical(data_bits(:)');  

    % Append m zeros for division
    data_padded = [data_bits, false(1, crc_len)];

    % Perform modulo-2 division
    for i = 1:length(data_bits)
        if data_padded(i) == 1
            data_padded(i:i+crc_len) = xor(data_padded(i:i+crc_len), poly_val);
        end
    end

    % Extract CRC sequence
    crc_bits = double(data_padded(end-crc_len+1:end)).';
end
