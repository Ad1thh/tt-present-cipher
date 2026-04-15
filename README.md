![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Tiny Tapeout: PRESENT Block Cipher

This repository contains an implementation of the [PRESENT block cipher](https://en.wikipedia.org/wiki/PRESENT_(cipher)) designed for Tiny Tapeout.

- [Read the full documentation for the project](docs/info.md)

## Overview

PRESENT is an ultra-lightweight block cipher designed for power and area-constrained environments. 
This implementation operates on a 64-bit plaintext block and uses an 80-bit encryption key. To map the 64-bit datapath constraints onto the 8-bit Tiny Tapeout IO protocol, the top module features a Finite State Machine (FSM) wrapped around serial shift registers to sequentially load the data and key, then extract the ciphertext upon encryption completion.

### Key Features
- **Algorithm**: PRESENT-80 (64-bit block, 80-bit key, 31 rounds).
- **Target Platform**: Tiny Tapeout (1x2 tile).
- **IO Scheme**: 8-bit parallel, sequenced over multiple clock cycles via `uio_in` control flags.

## Testing

Comprehensive testing uses cocotb. 
Run the simulator tests locally by navigating to `test/` and executing `make`.

## Building

The ASIC design is automatically built and tested using GitHub Actions with LibreLane upon committing to this repository. See the Actions tab for logs and GDS artifacts.
