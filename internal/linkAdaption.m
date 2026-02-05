function pdsch = linkAdaption(pdschConfig, MCS, SystemSNR)
    current_MCS = MCS;

    while current_MCS >= 0
        pdschConfig = pdschConfig.setMCS(current_MCS);
        
        switch pdschConfig.Modulation
            case 'QPSK'
                expected_SNR = 10;   
            case '16QAM'
                expected_SNR = 20;  
            case '64QAM'
                expected_SNR = 30;  
            case '256QAM'
                expected_SNR = 40; 
        end
        
        if expected_SNR <= SystemSNR
            break;
        else
            current_MCS = current_MCS - 1;
        end
    end

    pdsch = pdschConfig;
end