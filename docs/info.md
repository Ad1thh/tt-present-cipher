<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project implements the [PRESENT](https://en.wikipedia.org/wiki/PRESENT_(cipher)) block cipher, an ultra-lightweight encryption algorithm specifically designed for constrained hardware environments. It operates on a 64-bit data block and uses an 80-bit key. 

To fit the design within the constraints of a single 1x1 Tiny Tapeout tile and its 8-bit I/O boundaries, an FSM-based serial wrapper manages loading and unloading through internal shift registers. The design broadly follows these phases:
1. **Load Key**: shifting in 80 bits of the encryption key, 8 bits at a time.
2. **Load Data**: shifting in 64 bits of the plaintext data block, 8 bits at a time.
3. **Encrypt**: performing the 31-round PRESENT cipher logic via a minimal datapath core.
4. **Unload Data**: shifting out the resulting 64-bit ciphertext, 8 bits at a time.

## How to test

1. Ensure the chip is reset by driving `rst_n` low for at least 1 clock cycle.
2. Bring the chip out of reset (`rst_n` high).
3. **Load Key**: Set `uio_in[0]` (load_key_en) high. Provide the 80-bit key on `ui_in` in 8-bit chunks sequence, clocking 10 cycles.
4. **Load Data**: Pull `load_key_en` low, set `uio_in[1]` (load_data_en) high. Provide the 64-bit plaintext data on `ui_in` in 8-bit chunks, clocking 8 cycles.
5. **Encrypt**: Pull all load flags low. Pulse `uio_in[2]` (start_encrypt) high for at least 1 cycle to begin the encryption process. Wait for `uio_out[0]` (done_flag) to go high (~560 cycles for the nibble-serial datapath).
6. **Unload Data**: Drive `uio_in[3]` (unload_data_en) high. Read the resulting 64-bit ciphertext from `uo_out` over 8 clock cycles.

## External hardware

No specific external hardware is required. A generic microcontroller (Arduino, RP2040, etc.) or an FPGA board is recommended to automate the sequential loading, encrypting, and unloading phases via GPIO bit-banging.
