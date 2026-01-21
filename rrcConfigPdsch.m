% =========================================================================
% RRC CONFIGURATION STRUCTURE
% Ref: 3GPP TS 38.331, 38.214, 38.211
% This structure contains all RRC parameters required for
% PDSCH transmission and CSI-based precoding.
% =========================================================================
%
% rrcConfig
% {

% -------------------------------------------------------------------------
% 1. CELL IDENTITY (ServingCellConfigCommon)
% Used as default scrambling identity for PDSCH and DMRS
% when no dedicated ID is configured.
% -------------------------------------------------------------------------
%
% NID : int
%   Physical Cell ID (PCI), range 0..1007
%   Used as fallback scrambling ID for PDSCH and DMRS.


% -------------------------------------------------------------------------
% 2. PDSCH CONFIGURATION (IE: PDSCH-Config)
% Defines how PDSCH symbols are generated at PHY layer.
% -------------------------------------------------------------------------
%
% PDSCH : struct
% {

% --- A. PDSCH Scrambling -----------------------------------------------
% TS 38.211 Section 7.3.1.1
%
% dataScramblingIdentityPDSCH : int
%   Scrambling identity n_ID used for PDSCH data scrambling.
%   Range 0..1023.
%   If not configured, UE uses NID (PCI).


% --- B. DMRS Configuration for PDSCH -----------------------------------
% TS 38.211 Section 7.4.1.1
%
% DMRS : struct
% {
%   dmrs_Type : int
%       DMRS Type (1 or 2).
%
%   dmrs_AdditionalPosition : int
%       Number of additional DMRS symbols (0..3).
%
%   maxLength : int
%       DMRS length: 1 = single symbol, 2 = double symbol.
%
%   scramblingID0 : int
%       DMRS scrambling identity n_ID^0 (optional).
%
%   scramblingID1 : int
%       DMRS scrambling identity n_ID^1 (optional, for CDM groups).
% }


% --- C. PDSCH Resource Allocation --------------------------------------
% TS 38.214 Section 5.1.2.2
%
% resourceAllocation : string
%   'type0'  → RBG bitmap based allocation
%   'type1'  → RIV based allocation
%
% rbg_Size : string
%   'config1' or 'config2' (only applicable for type0 allocation)


% --- D. Modulation and Coding ------------------------------------------
%
% mcs_Table : string
%   'qam64', 'qam256', or 'qam64LowSE'
%   Selects the MCS table used for PDSCH.


% --- E. Rate Matching / Overhead ---------------------------------------
% TS 38.214 Section 5.1.4
%
% RateMatch : struct
% {
%   xOverhead : int
%       Overhead (0, 6, 12, or 18) used for TBS and G calculation
%       to account for CSI-RS and other punctured REs.
% }


% --- F. TCI States (Beam Association) -----------------------------------
% Links CSI-RS beams to PDSCH transmission beams.
%
% TCI_States : struct
% {
%   tciStatesToAdd
%   tciStatesToRelease
% }

% }   % End of PDSCH



% -------------------------------------------------------------------------
% 3. CSI MEASUREMENT AND CODEBOOK CONFIGURATION
% Defines how UE measures the channel and reports PMI used
% to generate the PDSCH precoding matrix.
% -------------------------------------------------------------------------
%
% CSI : struct
% {

% --- A. CSI-RS Resources ------------------------------------------------
% Defines the CSI-RS beams that UE can measure.
%
% CSI_RS : struct
% {
%   resourceSets
%   resourceMapping
% }


% --- B. CSI Report Configuration --------------------------------------
%
% CSI_Report : struct
% {
%   reportQuantity
%       (e.g. CRI, RI, PMI, CQI)


% --- C. CSI Codebook Configuration ------------------------------------
% TS 38.214 Section 5.2
% This selects the PMI structure used for PDSCH precoding.
%
% CodebookConfig : struct
% {

%   codebookType : string
%       'type1SinglePanel'
%       'type1MultiPanel'
%       'type2'
%       'type2-PortSelection'


%   n1 : int
%       Number of horizontal CSI-RS ports.
%
%   n2 : int
%       Number of vertical CSI-RS ports.
%
%       Total number of CSI-RS ports = 2 * n1 * n2 (dual polarization).


%   o1 : int
%       Horizontal oversampling factor (Type II only).
%
%   o2 : int
%       Vertical oversampling factor (Type II only).


%   codebookMode : int
%       1 or 2.
%       Selects PMI parameter structure
%       (enables/disables i11, i12, i2, i15, i16, etc).


%   maxNumberOfLayers : int
%       Maximum number of PDSCH transmission layers supported.
% }

% }   % End of CSI
% }
