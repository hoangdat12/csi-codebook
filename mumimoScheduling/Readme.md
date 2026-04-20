# Scheduling for MUMIMO using SOS and Kmeans

## Mục lục
- [Introduction]
- [System Model & Methodology]

---

## Introduction
In the 5G New Radio (NR) era, **Multi-User MIMO (MU-MIMO)** is a fundamental technology for boosting spectral efficiency and system capacity by allowing multiple users (UEs) to share the same time-frequency resources. However, mitigating **Inter-User Interference (IUI)** remains a critical challenge, requiring highly precise and efficient scheduling algorithms at the base station (gNB).

This project focuses on designing and simulating a **PDSCH** scheduler using a hybrid approach that combines two distinct algorithms:

1. **K-means Clustering:** This unsupervised machine learning algorithm is used to group UEs based on their spatial correlation, derived from Precoding Matrices or Channel State Information (e.g., 3GPP Type II CSI-RS Codebooks). Clustering helps narrow down the search space and ensures that we can identify UEs with highly orthogonal spatial signatures.
2. **Symbiotic Organisms Search (SOS):** A robust, meta-heuristic optimization algorithm inspired by the symbiotic interactions of organisms in nature. SOS is applied to efficiently search through the clustered UEs to find the optimal user subset that maximizes the system's **Sum-rate** while maintaining scheduling **Fairness**.

**Why this approach?**
Finding the absolute optimal MU-MIMO user pairing using exhaustive search is computationally prohibitive, especially in Massive MIMO setups (e.g., 16 or 32 antenna ports). By leveraging K-means to pre-group users, we significantly reduce the computational complexity for the SOS algorithm. This hybrid method aims to optimize Physical Layer (PHY) performance, delivering near-optimal throughput while keeping processing times realistic for 5G environments.

---

## System Model & Methodology
The simulation workflow is designed strictly around the 5G NR physical layer, focusing on the Downlink (DL) PDSCH transmission. The scheduling process follows these core steps:

1. **CSI Feedback & Precoding Matrix:**
   - Base station (gNB) configures CSI-RS for multiple UEs.
   - UEs report Channel State Information (CSI) back to the gNB, utilizing **3GPP TS 38.214 Type I Codebook** to accurately represent the spatial channel characteristics.
   - The system reconstructs the Precoding Matrix Indicator (PMI) for massive MIMO configurations (currently support 32 Ports).

2. **User Grouping (K-means):**
   - The extracted precoding matrices or spatial covariance matrices are used as input features.
   - K-means clusters UEs into distinct groups based on spatial correlation, effectively isolating UEs with highly overlapping beams.

3. **MU-MIMO Scheduling (SOS):**
   - The Symbiotic Organisms Search algorithm evaluates combinations of UEs (picking candidates from different K-means clusters) to form the final MU-MIMO scheduling set.
   - The fitness function of SOS evaluates the estimated PDSCH Sum-rate and Signal-to-Interference-plus-Noise Ratio (SINR), ensuring minimal IUI.

---

## Key Features

* **3GPP Compliant:** Simulation parameters and channel models align with 5G NR specifications (TS 38.211, TS 38.214).
* **Advanced CSI-RS Support:** Full handling of high-resolution Type I CSI reporting.
* **Scalable Antenna Configurations:** Robust testing and precoding matrix generation for 8-port, 16-port, and 32-port setups.
* **Hybrid Optimization:** Seamless integration of machine learning (K-means) with meta-heuristic optimization (SOS) for resource allocation.
* **Performance Visualizations:** Automated plotting of user spatial distributions, convergence curves of the SOS algorithm, and sum-rate comparisons against baseline schedulers (e.g., Round Robin, Proportional Fair).

---

## Prerequisites

To run these simulations locally, you will need the following environment:

* **MATLAB:** Recommended R2023a or newer.
* **Toolboxes Required:**
  * 5G Toolbox
  * Communications Toolbox
  * Phased Array System Toolbox
  * Statistics and Machine Learning Toolbox (for K-means)

---

## Code Architecture & Main Functions 

This section provides a brief overview of the core MATLAB scripts and functions used in this simulation.

### 1. Data Generation (CSI-RS & PMI)
* **`computePrecodingMatrix.m`**
  * **Purpose:** Generates the Precoding Matrix Indicator (PMI) data for the UEs. 
  * **Description:** This script simulates the base station (gNB) configuring CSI-RS and computes the precoding matrices based on the defined number of antenna ports (e.g., 32-port) and transmission layers. It outputs the spatial data into `.mat` files stored in the `pmiData` folder, which acts as the channel state feedback for the scheduling phase.

### 2. Scheduling & Optimization

* **`sosMumimoscheduling.m`**
  * **Purpose:** Executes the Symbiotic Organisms Search to find the optimal MU-MIMO user pairing.
  * **Key Mechanism:** * **Smart Initialization:** Instead of a purely random population, the algorithm uses the `cluster_idx` (from K-means) to seed the ecosystem. It forces the selection of UEs from *different* spatial clusters, inherently reducing initial Inter-User Interference (IUI).
    * **Evolutionary Phases:** Iterates through Mutualism, Commensalism, and Parasitism phases to refine the selected UE subsets.
    * **Fast Fitness Function:** To keep computation times feasible, the objective function (`estimateSumRate`) calculates a linear SINR approximation based on the spatial signatures ($W^H W$), avoiding a full OFDM simulation during the search iterations.
  * **Output:** Returns the indices of the optimal UEs, the best achieved Sum-Rate, and data for the convergence curve.

* **`psoMUMIMOScheduling.m`**
  * **Purpose:** Executes a Discrete Particle Swarm Optimization (PSO) to find the optimal MU-MIMO user grouping that maximizes spatial separation between simultaneously served users.
  * **Key Mechanism:**
    * **Discrete Permutation Encoding:** Each particle is represented as a permutation of UE indices, where consecutive blocks of `groupSize` elements define a group. This allows PSO — originally designed for continuous spaces — to operate over combinatorial grouping assignments.
    * **Swap Sequence Velocity:** Velocity is represented not as a numeric vector but as a sequence of pairwise swaps. The standard PSO update (`w·V + c1·r1·(PBest−X) + c2·r2·(GBest−X)`) is reinterpreted via `getSwapSequence` and `multiplySwapSequence`, where scalar multiplication stochastically retains each swap with probability equal to the coefficient.
    * **Chordal Distance Fitness:** The objective function (`computeFitnessPrecomputed`) maximizes the average chordal distance between all UE pairs within each group, using a precomputed `distMat`. Higher chordal distance implies more orthogonal beamforming directions, directly reducing Inter-User Interference (IUI).
    * **Precomputed Pair Indices:** All intra-group pair combinations are computed once via `precomputePairIndices` (using `nchoosek`) at initialization and reused across all iterations, avoiding redundant computation inside the fitness evaluation loop.
    * **Adaptive Inertia & Early Stopping:** The inertia weight `w` decays linearly from `w_start = 0.9` to `w_end = 0.4` over iterations. A `no_improve_counter` triggers early termination after `max_no_improve = 15` consecutive iterations without GBest improvement.
  * **Output:** Returns `bestGroups` (a cell array of UE index groups) and `bestScore` (the best average chordal distance achieved across all groups).

* **`muMIMO2UE.m`**
  * **Purpose:** Performs a full physical-layer MU-MIMO simulation for exactly two simultaneous UEs, executing the complete transmit-and-receive chain from bit generation through OFDM modulation, channel emulation, and LDPC decoding to produce a final BER for each user.
  * **Key Mechanism:**
    * **Dual PDSCH Configuration:** Two independent `customPDSCHConfig` objects are constructed from a shared `baseConfig`, differentiated by RNTI offset (`+1` for UE2) and non-overlapping DMRS port sets (`0:3` for UE1, `4:7` for UE2), enabling orthogonal pilot-based channel estimation per user in the same time-frequency resources.
    * **Manual Multi-Port Resource Grid:** Rather than relying on a toolbox grid object, the function builds layer grids of shape `[K × symbolsPerSlot × nLayers]` manually for each UE, then applies the respective precoding matrix via `layerFlat * W.'` to produce per-port signals. The two users' port signals are superimposed before OFDM modulation, faithfully replicating MU-MIMO spatial multiplexing at the transmitter.
    * **OFDM Chain:** Subcarrier mapping (`subcarrierMap`) places data onto the correct positive/negative frequency bins of an `NFFT`-point grid, computed dynamically from the subcarrier spacing via `computeNFFT`. OFDM modulation and demodulation account for numerology-dependent cyclic prefix lengths (extended first-symbol CP vs. normal CP).
    * **DMRS-Based Channel Estimation & MMSE Equalization:** The receiver (`rxPDSCHDecode`) extracts received DMRS pilots, computes a least-squares per-port-per-layer channel estimate via `estimateChannelFromDMRS`, and passes the resulting `Hest` tensor along with a calibrated `noiseVar` (derived from the input `SNR_dB`) into `nrEqualizeMMSE`, ensuring the equalizer operates with accurate noise statistics rather than a fixed epsilon.
    * **Controlled Test Vectors:** UE1 transmits an all-ones bit sequence and UE2 an all-zeros sequence, making BER verification straightforward and cross-user interference immediately visible as bit flips in the decoded output.
  * **Output:** Returns `BER1` and `BER2`, the raw bit error rates for UE1 and UE2 respectively, computed via `biterr` against the known transmitted bit sequences.

* **`simulateRandomMUMIMOScheduling.m`**
  * **Purpose:** Top-level orchestration script that wires together the full MU-MIMO user scheduling and BER evaluation pipeline — from codebook loading and UE pool construction, through PSO-based orthogonal group search, to SNR-swept BER measurement and waterfall curve plotting.
  * **Key Mechanism:**
    * **Data Preparation (`prepareData`):** Loads all precoding matrices from a structured text codebook file into a pool, then draws `numberOfUE = 20,000` random samples (with replacement) via `randi`, producing `W_all` — a large synthetic UE population that reflects realistic PMI report diversity without requiring distinct physical UEs.
    * **Representative Pool via K-Means (`buildRepresentativePool`):** Flattens the complex precoding matrices into real-valued feature vectors `[real(W), imag(W)]` and runs K-means with cosine distance to partition the UE population into up to 500 spatial clusters. A fixed quota of UEs is then drawn from each cluster to form a compact `targetPoolSize = 2000` representative pool, ensuring broad codebook coverage while keeping the downstream scheduling search tractable.
    * **PSO Orthogonal Group Search (`findFeasibleOrthogonalGroups`):** Invokes `psoMUMIMOScheduling` on the representative pool to generate candidate user groups. Each returned group is then post-validated: the minimum pairwise chordal distance among all members is computed, and only groups exceeding `threshold = 0.9999` are retained as feasible. This two-stage design separates combinatorial optimization from hard feasibility enforcement.
    * **SNR-Swept BER Evaluation:** The first feasible group's precoding matrices are extracted and passed to `muMIMO2UE` across a sweep of `snrRange = 0:5:30` dB. Results are collected into `ber1_results` and `ber2_results` arrays and printed in a formatted table for inspection.
    * **Waterfall Plot:** BER curves for both UEs are rendered on a `semilogy` axis with minor grid lines enabled, providing a standard link-level performance view for the selected orthogonal pair.
  * **Output:** Command-window table of per-UE BER at each SNR point, and a figure showing the MU-MIMO BER waterfall curves for the best orthogonally scheduled UE pair.

* **`compareBerThroughput.m`**
  * **Purpose:** Benchmarking script that evaluates the BER and effective throughput of a fixed MU-MIMO pair (W1, W2) across multiple MCS indices and SNR levels, producing a 2×2 subplot figure comparing both UEs simultaneously.
  * **Key Mechanism:**
    * **Hardcoded Orthogonal Pair:** W1 and W2 are defined as literal 32×4 complex matrices directly in the script, representing a pre-selected, spatially orthogonal UE pair from the Type-II codebook. This bypasses the scheduling search entirely, isolating the physical-layer link performance evaluation from the pairing optimization.
    * **MCS Sweep:** Four MCS indices (`[0, 5, 11, 27]`) are swept in the outer loop. For each MCS, `pdsch.setMCS()` reconfigures the modulation order and target code rate, and `calculateThroughput` derives the theoretical peak throughput for a single UE under that configuration using the numerology `mu = log2(SCS/15)`.
    * **Effective Throughput Estimation:** Since the simulation produces raw BER rather than HARQ block error rates, effective throughput is approximated as `MaxTP × max(0, 1 − BER×100)`. This aggressive penalty factor causes throughput to collapse rapidly at high BER, qualitatively mimicking packet-level failure without running a full HARQ retransmission model.
    * **2×2 Result Grid:** Results are rendered into a four-panel figure — BER vs. SNR for UE1 and UE2 (top row, `semilogy` scale), and effective throughput vs. SNR for UE1 and UE2 (bottom row, linear scale) — with per-MCS curves distinguished by distinct markers, enabling direct visual comparison of the BER–throughput trade-off across modulation-coding choices.
  * **Output:** A 2×2 subplot figure showing BER waterfall curves and effective throughput curves for both UEs across all MCS values, and a console log of per-SNR BER and throughput values for each MCS iteration.
  
* **`benchmark_sos_vs_pso.m`**
  * **Purpose:** Head-to-head benchmarking script that runs both `sosMUMIMOScheduling` and `psoMUMIMOScheduling` on the same representative UE pool under identical conditions, then quantitatively compares execution time, average chordal distance score, and the number of valid orthogonal pairs produced by each algorithm.
  * **Key Mechanism:**
    * **Controlled Experimental Setup:** Both algorithms receive the exact same `W_pool` (built from an identical K-Means pipeline with `targetPoolSize = 2000`), `numberOfUeToGroup = 2`, `maxIter = 50`, and `threshold = 0.90`, eliminating all confounding variables so that measured differences are attributable solely to each algorithm's search strategy.
    * **Wall-Clock Timing via `tic`/`toc`:** Each algorithm call is individually bracketed by `tic`/`toc`, capturing total scheduling time including all internal initialization, fitness evaluations, and convergence logic — giving a fair end-to-end latency comparison representative of real deployment overhead.
    * **Post-Hoc Feasibility Counting (`countValidPairs`):** After each algorithm returns its groups, `countValidPairs` iterates over all returned groups and recomputes `chordalDistance` for each UE pair, counting only those that meet or exceed the orthogonality threshold. This decouples solution quality measurement from the optimizer's internal scoring, ensuring both algorithms are judged by the same external criterion.
    * **Tabular Console Summary:** Results are printed in an aligned three-column table covering execution time, average score, and valid pair count for SOS and PSO side-by-side, enabling immediate numerical comparison without inspecting figures.
    * **Two-Panel Bar Chart:** A figure with two subplots visualizes the comparison — execution time (lower is better, blue/red) and valid pair count at the given threshold (higher is better, green/orange) — with data labels rendered directly on each bar for readability.
  * **Output:** A formatted benchmark table in the console and a two-panel bar chart figure comparing SOS and PSO across runtime efficiency and orthogonal pairing quality.

---

## How to Run / Usage

To run the code and reproduce the MU-MIMO scheduling simulations, follow these steps:

### 1. Setup the Environment
First, clone the repository to your local machine:
```bash
git clone [https://github.com/hoangdat12/csi-codebook.git](https://github.com/hoangdat12/csi-codebook.git)
cd csi-codebook
```

### 2. Prepare Data
Before scheduling, we need to generate the spatial data (random PMIs) for the UEs. Navigate to the Type I single-panel CSI-RS directory:

```bash 
cd csi-rs/typeI/single-panel
```

Open and run the *computePrecodingMatrix.m* script in MATLAB. You can adjust the following parameters inside the script to modify the output data:
```code
numberOfLayers = 4;
numberOfPorts = 32;
folderName = 'pmiData';
```

Once the data generation is complete, copy the newly created pmiData folder into the mumimoScheduling directory, and navigate there:

```bash
cp -r pmiData ../../../mumimoScheduling
cd ../../../mumimoScheduling
```

### Run the Simulations & Examples.

To execute the core functionalities of this repository, run the following commands in the MATLAB command window.

#### A. Core Simulation
To execute the overall scheduling algorithm and test with random MU-MIMO pairings, 
run *simulateRandomMUMIMOScheduling*.

##### Example Output:
![Example Output of simulateRandomMUMIMOScheduling](./images/simulateRandomMUMIMOSchedulingResults.png)

The results show the scheduled UE pairs and their corresponding sum rate. UEs with 
insufficient SNR for the selected MCS will experience decoding errors, leading to 
reduced effective throughput.

#### B. Trade-off between MCS
To analyze the trade-off between MCS, BER, and throughput, run *compareBerThroughput*.

##### Example Output:
![Example Output of compareBerThroughput](./images/compareBerThroughputResults.png)

The results illustrate the trade-off between BER and cell throughput across different 
MCS levels. Higher MCS achieves greater peak throughput but degrades rapidly at low 
SNR, while lower MCS remains robust at the cost of reduced maximum throughput.

#### C. Execution Time Comparison
To evaluate the computational performance and execution time, run *compareExecutionTime*.

##### Example Output:
![Example Output of compareExecutionTime](./images/compareExecutionTimeResults.png)

The results compare the execution time between PSO-based and SOS-based scheduling 
algorithms across different numbers of UE pairs, demonstrating the computational 
trade-off between the two approaches.