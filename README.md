# FPGA-Accelerated Crypto HFT System

This project is a real-time system that tracks cryptocurrency markets and drives trading decisions from an **online linear-regression model updated on an FPGA**. The regression's core matrix arithmetic is offloaded to a fixed-point RTL datapath on a PYNQ-Z1 board, with the host managing market data and control from the processing system.

> **Fork / attribution:** this repository is a fork of a group project ([`Information-Processing/trading_indicators`](https://github.com/Information-Processing/trading_indicators)). The commit history is largely inherited from upstream. **My contribution is the hardware side: the SystemVerilog RTL for the fixed-point matrix multiplier used by the linear-regression model.** The rest of the system (data loading, controller logic, Python tooling) is team-authored. I have forked this repository for cleanup, future updates to my side of the project, and for a front-end README for recruiting purposes.

## What was built

- **Fixed-point matrix-multiply datapath (my work)** — an outer-product accumulation pipeline that computes the matrix products behind the linear-regression update. Designed with an initiation interval of 1 (one accumulation issued per cycle) at an Fmax of ~100 MHz on the Zynq-7020.
- **Fixed-point numeric path** — IEEE-754 floating-point was replaced with a fixed-point representation to remove floating-point resource and latency overhead on the FPGA and to avoid routing congestion, at the cost of a small, bounded quantisation error (see *Results* below).
- **Host/controller side (team)** — market data ingestion, model orchestration, and switching of market and leverage, run from the PYNQ processing system.

## Results


- **End-to-End Latency:** ~18x mean / ~68x peak vs a NumPy baseline for 17x17 ATA matrices (including AXI DMA transfer between the PS and PL - which was a critical path).
- **Accuracy:** mean quantisation error of 1.25%. Deemed negligible due to the high number of samples

## Repository layout

| Directory | Contents |
| --- | --- |
| `linear_regression` | RTL and model logic for the regression datapath |
| `Controller Code` | Controller / orchestration logic |
| `cpp` | C++ components |
| `pynq_jupyter_notebook` | PYNQ notebooks driving the overlay from the PS |
| `tests` | Test programs |
| `Real-Time FPGA-Accelerated Crypto High Frequency Trading System.pdf` | Full technical report — architecture and results |


## Further reading

Full architecture and measured results are in the [technical report](Real-Time%20FPGA-Accelerated%20Crypto%20High%20Frequency%20Trading%20System.pdf).
