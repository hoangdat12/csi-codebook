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
* **`kmeansSOS.m`**
  * **Purpose:** The main execution script for the MU-MIMO scheduler.
  * **Description:** This script loads the generated PMI data and executes the hybrid scheduling algorithm. It operates in two main phases:
    1. **K-means Phase:** Applies the K-means clustering algorithm on the UEs' spatial signatures (PMI data) to group users with high spatial correlation.
    2. **SOS Phase:** Initializes the Symbiotic Organisms Search (SOS) ecosystem. It selects candidate UEs from different clusters to minimize Inter-User Interference (IUI) and iteratively applies Mutualism, Commensalism, and Parasitism phases to find the optimal user subset that maximizes the PDSCH sum-rate.
    3. **Test Phase (BER Simulation):** To validate the scheduling reliability, the script simulates a real PDSCH transmission using the selected precoding matrices (or a random PMI pair for baseline comparison). It passes the signal through the channel, performs receiver decoding, and measures the **Bit Error Rate (BER)**. This phase demonstrates the practical effectiveness of the scheduled PMIs in maintaining signal integrity under interference.

* **`computePrecodingMatrix.m`**
  * **Purpose:** To generate and construct the Precoding Matrix Indicator (PMI) dataset based on 3GPP TS 38.214 specifications for 5G NR Downlink.
  * **Key Parameters:** * `numberOfLayers`: Defines the number of spatial transmission layers (e.g., 4).
    * `numberOfPorts`: Defines the massive MIMO antenna configuration (e.g., 8, 16, or 32 ports).
  * **Detailed Workflow:**
    1. **Codebook Construction:** The script mathematically constructs the Type I Single-Panel precoding codebook specific to the configured antenna ports and layers, utilizing oversampled 2D-DFT beams and co-phasing factors.
    2. **User Spatial Signatures:** It simulates channel feedback by generating/selecting precoding matrices ($W$) that represent the spatial directions of various UEs within the cell.
    3. **Data Export:** The computed matrices are exported and saved as `.mat` files into the designated `pmiData` directory. This dataset acts as the foundational environment (the UEs' spatial locations) for the K-means clustering and SOS scheduling algorithms.


* **`sosMumimoscheduling.m`**
  * **Purpose:** Executes the Symbiotic Organisms Search to find the optimal MU-MIMO user pairing.
  * **Key Mechanism:** * **Smart Initialization:** Instead of a purely random population, the algorithm uses the `cluster_idx` (from K-means) to seed the ecosystem. It forces the selection of UEs from *different* spatial clusters, inherently reducing initial Inter-User Interference (IUI).
    * **Evolutionary Phases:** Iterates through Mutualism, Commensalism, and Parasitism phases to refine the selected UE subsets.
    * **Fast Fitness Function:** To keep computation times feasible, the objective function (`estimateSumRate`) calculates a linear SINR approximation based on the spatial signatures ($W^H W$), avoiding a full OFDM simulation during the search iterations.
  * **Output:** Returns the indices of the optimal UEs, the best achieved Sum-Rate, and data for the convergence curve.

* **`muMIMO2UE.m`**
  * **Purpose:** Performs a complete 5G NR baseband simulation for the scheduled UE pair to validate the theoretical sum-rate by measuring the actual Bit Error Rate (BER).
  * **Detailed Workflow:**
    1. **Configuration:** Sets up standard-compliant PDSCH and allocates orthogonal DMRS ports (e.g., ports 0-3 for UE1, ports 4-7 for UE2) to prevent pilot contamination.
    2. **Transmitter (TX):** Encodes the Transport Block Size (TBS), maps layers, applies the optimal precoding matrices (`W1`, `W2`) chosen by the SOS algorithm, and performs OFDM modulation.
    3. **Channel:** Transmits the waveform through an AWGN channel based on the specified `SNR_dB`.
    4. **Receiver (RX):** Performs OFDM demodulation, DMRS-based Least Squares (LS) channel estimation, and Minimum Mean Square Error (MMSE) equalization to suppress residual interference before final PDSCH decoding.
  * **Output:** Returns `BER1` and `BER2`, proving the practical reliability of the scheduled MU-MIMO pair.
  
---

## How to Run / Usage

To run the code and reproduce the MU-MIMO scheduling simulations, follow these steps:

### 1. Setup the Environment
First, clone the repository to your local machine:
```bash
git clone [https://github.com/yourusername/your-repo-name.git](https://github.com/yourusername/your-repo-name.git)
cd your-repo-name
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

### Output Example
