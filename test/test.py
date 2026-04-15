## SPDX-FileCopyrightText: © 2024 Tiny Tapeout
## SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

async def load_key(dut, key_hex):
    # key_hex is an 80-bit hex string e.g. "FFFFFFFFFFFFFFFFFFFF"
    val = int(key_hex, 16)
    dut.uio_in.value = 1 # load_key_en
    for i in range(10):
        shift = (9 - i) * 8
        b = (val >> shift) & 0xFF
        dut.ui_in.value = b
        await RisingEdge(dut.clk)
    dut.uio_in.value = 0
    await RisingEdge(dut.clk)

async def load_data(dut, data_hex):
    val = int(data_hex, 16)
    dut.uio_in.value = 2 # load_data_en
    for i in range(8):
        shift = (7 - i) * 8
        b = (val >> shift) & 0xFF
        dut.ui_in.value = b
        await RisingEdge(dut.clk)
    dut.uio_in.value = 0
    await RisingEdge(dut.clk)

async def get_data(dut):
    res = 0
    await Timer(2, units='us') # Let combinational uo_out settle
    res = (res << 8) | int(dut.uo_out.value)
    
    dut.uio_in.value = 8 # unload_data_en
    for i in range(7):
        await RisingEdge(dut.clk)
        await Timer(2, units='us')
        res = (res << 8) | int(dut.uo_out.value)
        
    dut.uio_in.value = 0
    await RisingEdge(dut.clk)
    return res

@cocotb.test()
async def test_present(dut):
    clock = Clock(dut.clk, 10, units="us") # 100 kHz for test
    cocotb.start_soon(clock.start())

    # Initialize
    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases: (key, plaintext, expected_cipher)
    tests = [
        ("00000000000000000000", "0000000000000000", 0x5579C1387B228445),
        ("FFFFFFFFFFFFFFFFFFFF", "0000000000000000", 0xE72C46C0F5945049),
        ("00000000000000000000", "FFFFFFFFFFFFFFFF", 0xA112FFC72F68417B),
        ("FFFFFFFFFFFFFFFFFFFF", "FFFFFFFFFFFFFFFF", 0x3333DCD3213210D2)
    ]

    for kt, pt, ext in tests:
        # Load Key and Plaintext
        await load_key(dut, kt)
        await load_data(dut, pt)
        
        # Start Encryption
        dut.uio_in.value = 4 # start_encrypt
        await RisingEdge(dut.clk)
        dut.uio_in.value = 0
        
        # Wait until done flag pulses on uio_out[0]
        while int(dut.uio_out.value) & 1 == 0:
            await RisingEdge(dut.clk)
            
        await RisingEdge(dut.clk) # Complete capture cycle in FSM
        
        # Retrieve and verify Output
        res = await get_data(dut)
        assert res == ext, f"Error: expected {hex(ext)}, got {hex(res)}"
        dut._log.info(f"Test passed for Key: {kt}, PT: {pt} -> CT: {hex(res)}")
