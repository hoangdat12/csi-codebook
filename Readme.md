# MUMIMO with PDSCH channels in 5G NR using CSI-RS Codebook
This project presents a simulation framework for PDSCH transmission in 5G NR systems, 
with a focus on PMI (Precoding Matrix Indicator) calculation using CSI-RS-based codebooks.

A MU-MIMO system model is considered, where multiple users are scheduled and grouped 
using different algorithms, including Particle Swarm Optimization (PSO), 
Symbiotic Organisms Search (SOS), and K-means clustering.

The study evaluates and compares the performance of these scheduling approaches 
based on several key metrics:
- Bit Error Rate (BER)
- Execution time and computational complexity
- Trade-offs between system performance and algorithm efficiency

The goal is to investigate the impact of advanced optimization algorithms on 
user scheduling, precoding accuracy, and overall system throughput in 5G NR systems.

## Table of Contents
- [Overview](#overview)
- [System Model](#system-model)
- [Key Concepts](#key-concepts)
  - [PDSCH Channel](#pdsch-channel)
  - [CSI-RS and Codebook](#csi-rs-and-codebook)
  - [PMI Calculation](#pmi-calculation)
- [Algorithms](#algorithms)
  - [K-means Clustering](#k-means-clustering)
  - [Particle Swarm Optimization (PSO)](#particle-swarm-optimization-pso)
  - [Symbiotic Organisms Search (SOS)](#symbiotic-organisms-search-sos)
- [Simulation Setup](#simulation-setup)
- [Performance Evaluation](#performance-evaluation)
  - [Bit Error Rate (BER)](#bit-error-rate-ber)
  - [Execution Time](#execution-time)
  - [Trade-offs Analysis](#trade-offs-analysis)
- [Project Structure](#project-structure)
- [How to Run](#how-to-run)
- [Results](#results)
- [References](#references)

## Introduction
The rapid growth of wireless data traffic has driven the development of advanced 
technologies in 5G New Radio (NR) systems, among which Multi-User Multiple-Input 
Multiple-Output (MU-MIMO) plays a key role in improving spectral efficiency and 
system capacity. By allowing simultaneous transmission to multiple users over 
the same time-frequency resources, MU-MIMO significantly enhances network performance.

In 5G NR, the Physical Downlink Shared Channel (PDSCH) is the primary channel 
for downlink data transmission. Efficient precoding for PDSCH relies heavily on 
accurate Channel State Information (CSI), which is typically obtained through 
CSI Reference Signals (CSI-RS) and fed back in the form of codebook-based indicators, 
such as the Precoding Matrix Indicator (PMI).

This project focuses on simulating the PDSCH transmission process in a MU-MIMO 
5G NR system, with an emphasis on PMI computation using CSI-RS-based codebooks. 
In multi-user scenarios, user scheduling and grouping become critical challenges, 
as they directly affect interference management and overall system performance.

To address this, different scheduling algorithms are investigated, including 
K-means clustering, Particle Swarm Optimization (PSO), and Symbiotic Organisms 
Search (SOS). These approaches are compared in terms of Bit Error Rate (BER), 
execution time, and the trade-off between computational complexity and performance.

The objective of this work is to analyze how advanced optimization techniques 
impact MU-MIMO scheduling efficiency, precoding accuracy, and overall system 
performance in 5G NR networks.

## Project Structure

```bash
csi-codebook/
├── channel/                  # Mã nguồn chính của ứng dụng
│   ├── components/       # Các UI components dùng chung (Button, Header...)
│   ├── pages/            # Các trang giao diện (Home, About...)
│   ├── utils/            # Các hàm tiện ích (helpers)
│   └── App.js            # Entry point của ứng dụng
├── public/               # Tài nguyên tĩnh (images, favicon, index.html)
├── tests/                # Chứa các file unit test
├── .gitignore            # Khai báo các file bỏ qua khi push lên Git
├── package.json          # Khai báo thư viện và scripts (Node.js)
└── README.md             # Tài liệu dự án
```