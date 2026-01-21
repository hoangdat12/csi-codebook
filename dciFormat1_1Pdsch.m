% =========================================================================
% DCI FORMAT 1_1  (Downlink scheduling for PDSCH)
% Ref: 3GPP TS 38.212, 38.214
%
% This DCI provides all dynamic parameters needed by the UE
% to receive and decode one PDSCH transmission in a slot.
% =========================================================================
%
% DCI_1_1
% {

% -------------------------------------------------------------------------
% 1. DCI format identifier
% -------------------------------------------------------------------------
% 1 bit
% 0 -> DCI format 0_1 (UL grant)
% 1 -> DCI format 1_1 (DL grant, PDSCH)
%
% formatIdentifier


% -------------------------------------------------------------------------
% 2. Carrier indicator
% -------------------------------------------------------------------------
% 0 or 3 bits
% Used when cross-carrier scheduling is configured.
% Selects which serving cell this PDSCH belongs to.
%
% carrierIndicator


% -------------------------------------------------------------------------
% 3. Bandwidth part (BWP) indicator
% -------------------------------------------------------------------------
% 0, 1, or 2 bits
% Selects the active DL BWP in which the PDSCH is scheduled.
%
% bwpIndicator


% -------------------------------------------------------------------------
% 4. Frequency-domain resource assignment
% -------------------------------------------------------------------------
% N bits
% Indicates PRB allocation for the PDSCH within the active BWP.
% Encoded as RBG bitmap (Type 0) or RIV (Type 1) depending on RRC config.
%
% freqDomainResource


% -------------------------------------------------------------------------
% 5. Time-domain resource assignment
% -------------------------------------------------------------------------
% 0 to 4 bits
% Index into the PDSCH time-domain allocation table configured by RRC.
% Selects the start symbol and length of the PDSCH in the slot.
%
% timeDomainResource


% -------------------------------------------------------------------------
% 6. VRB-to-PRB mapping
% -------------------------------------------------------------------------
% 0 or 1 bit
% Selects localized or distributed VRB-to-PRB mapping.
%
% vrbToPrbMapping


% -------------------------------------------------------------------------
% 7. PRB bundling size indicator
% -------------------------------------------------------------------------
% 0 or 1 bit
% Used when dynamic PRB bundling is enabled.
% Selects bundleSizeSet1 or bundleSizeSet2.
%
% prbBundlingSize


% -------------------------------------------------------------------------
% 8. Rate matching indicator
% -------------------------------------------------------------------------
% 0, 1, or 2 bits
% Selects the rate matching pattern group configured by RRC.
% Used to avoid CSI-RS, SSB, etc.
%
% rateMatchingIndicator


% -------------------------------------------------------------------------
% 9. ZP CSI-RS trigger
% -------------------------------------------------------------------------
% log2(n_zp + 1) bits
% Triggers transmission of one of the aperiodic ZP CSI-RS resource sets.
%
% zpCsiRsTrigger


% -------------------------------------------------------------------------
% 10. Transport Block 1 (TB1)
% -------------------------------------------------------------------------
% Modulation and coding
%
% mcs1      : 5 bits  -> MCS index into selected MCS table
% ndi1      : 1 bit   -> New Data Indicator (new TB or retransmission)
% rv1       : 2 bits  -> Redundancy Version (0,1,2,3)
%
% TB1_mcs
% TB1_ndi
% TB1_rv


% -------------------------------------------------------------------------
% 11. Transport Block 2 (TB2)
% (Only present if two codewords are configured)
%
% mcs2      : 5 bits
% ndi2      : 1 bit
% rv2       : 2 bits
%
% TB2_mcs
% TB2_ndi
% TB2_rv


% -------------------------------------------------------------------------
% 12. HARQ process number
% -------------------------------------------------------------------------
% 4 bits
% Selects one of 16 downlink HARQ processes.
%
% harqProcessNumber


% -------------------------------------------------------------------------
% 13. Downlink assignment index
% -------------------------------------------------------------------------
% 0, 2, or 4 bits
% Used for DL/UL timing consistency and slot alignment.
%
% dlAssignmentIndex


% -------------------------------------------------------------------------
% 14. TPC command for PUCCH
% -------------------------------------------------------------------------
% 2 bits
% Power control command for PUCCH carrying HARQ-ACK.
%
% tpcForPucch


% -------------------------------------------------------------------------
% 15. PUCCH resource indicator
% -------------------------------------------------------------------------
% 3 bits
% Selects which PUCCH resource the UE uses to send HARQ-ACK.
%
% pucchResource


% -------------------------------------------------------------------------
% 16. PDSCH-to-HARQ feedback timing
% -------------------------------------------------------------------------
% log2(K) bits
% Selects which k value is used for HARQ-ACK timing,
% where K is the number of dl-DataToUL-ACK entries configured by RRC.
%
% pdschToHarqTiming


% -------------------------------------------------------------------------
% 17. Antenna ports
% -------------------------------------------------------------------------
% 4, 5, or 6 bits
% Indicates which DMRS ports and number of layers are used for PDSCH.
%
% antennaPorts


% -------------------------------------------------------------------------
% 18. Transmission Configuration Indicator (TCI)
% -------------------------------------------------------------------------
% 0 or 3 bits
% Selects the TCI state, which defines the beam / QCL for this PDSCH.
%
% tci


% -------------------------------------------------------------------------
% 19. SRS request
% -------------------------------------------------------------------------
% 2 or 3 bits
% Triggers uplink SRS transmission.
%
% srsRequest


% -------------------------------------------------------------------------
% 20. Code Block Group transmission (CBGTI)
% -------------------------------------------------------------------------
% 0, 2, 4, 6, or 8 bits
% Indicates which code block groups are transmitted.
%
% cbgTransmissionInfo


% -------------------------------------------------------------------------
% 21. Code Block Group flush (CBGFI)
% -------------------------------------------------------------------------
% 0 or 1 bit
% Indicates which CBGs should be flushed for HARQ.
%
% cbgFlushInfo


% -------------------------------------------------------------------------
% 22. DMRS sequence initialization
% -------------------------------------------------------------------------
% 1 bit
% Selects which DMRS scrambling sequence is used.
%
% dmrsSeqInit

% }
