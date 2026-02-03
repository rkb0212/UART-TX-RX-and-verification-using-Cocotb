import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

CLK_PERIOD_NS = 100  # match your uart_tb.v (10 MHz)
CLKS_PER_BIT = 87
async def send_byte(dut, value: int):
    """Send one byte only when TX is idle."""
    await wait_tx_idle(dut)              
    dut.i_tx_byte.value = value
    dut.i_tx_dv.value = 1
    await RisingEdge(dut.i_clock)
    dut.i_tx_dv.value = 0


# async def wait_for_rx_dv(dut, max_cycles: int = 5000):
#     """Wait until o_rx_dv == 1 (with timeout). Return received byte."""
#     for _ in range(max_cycles):
#         await RisingEdge(dut.i_clock)
#         if dut.o_rx_dv.value.integer == 1:
#             return dut.o_rx_byte.value.integer
#     raise cocotb.result.TestFailure("TIMEOUT: o_rx_dv never asserted")
async def wait_for_rx_dv(dut, max_cycles: int = 5000):
    if int(dut.o_rx_dv.value) == 1:
        return int(dut.o_rx_byte.value)
    for _ in range(max_cycles):
        await RisingEdge(dut.i_clock)
        if int(dut.o_rx_dv.value) == 1:
            return int(dut.o_rx_byte.value)
    raise TimeoutError("TIMEOUT: o_rx_dv never asserted")

async def wait_for_tx_done(dut, max_cycles: int = 200000):
    """Wait until o_tx_done pulses high (with timeout)."""
    for _ in range(max_cycles):
        await RisingEdge(dut.i_clock)
        if int(dut.o_tx_done.value) == 1:
            return
    raise TimeoutError("TIMEOUT: o_tx_done never asserted")

async def wait_tx_idle(dut, max_cycles: int = 200000):
    for _ in range(max_cycles):
        await RisingEdge(dut.i_clock)
        if int(dut.o_tx_active.value) == 0:
            return
    raise TimeoutError("TIMEOUT: TX never became idle")

async def idle_bits(dut, nbits: int = 2):
    """Wait n UART bit-times (line stays idle-high naturally via TX)."""
    for _ in range(nbits * CLKS_PER_BIT):
        await RisingEdge(dut.i_clock)

@cocotb.test()
async def test_single_byte_loopback(dut):
    # start clock
    cocotb.start_soon(Clock(dut.i_clock, CLK_PERIOD_NS, unit="ns").start())

    # default idle
    dut.i_tx_dv.value = 0
    dut.i_tx_byte.value = 0

    # settle a couple cycles
    await RisingEdge(dut.i_clock)
    await RisingEdge(dut.i_clock)

    sent = 0xAB
    await send_byte(dut, sent)

    got = await wait_for_rx_dv(dut, max_cycles=50000)
    assert got == sent, f"LOOPBACK FAIL: sent=0x{sent:02X}, got=0x{got:02X}"

# @cocotb.test()
# async def test_many_random_bytes(dut):
#     cocotb.start_soon(Clock(dut.i_clock, CLK_PERIOD_NS, unit="ns").start())

#     dut.i_tx_dv.value = 0
#     dut.i_tx_byte.value = 0
#     await RisingEdge(dut.i_clock)
#     await RisingEdge(dut.i_clock)

#     for i in range(20):
#         sent = random.randint(0, 255)
#         await send_byte(dut, sent)
#         got = await wait_for_rx_dv(dut, max_cycles=10000)
#         assert got == sent, f"[{i}] sent=0x{sent:02X}, got=0x{got:02X}"
@cocotb.test()
async def test_many_random_bytes(dut):
    cocotb.start_soon(Clock(dut.i_clock, CLK_PERIOD_NS, unit="ns").start())

    dut.i_tx_dv.value = 0
    dut.i_tx_byte.value = 0
    await RisingEdge(dut.i_clock)
    await RisingEdge(dut.i_clock)

    for i in range(20):
        sent = random.randint(0, 255)
        await send_byte(dut, sent)
        # Wait RX first (don't miss 1-cycle o_rx_dv pulse)
        got = await wait_for_rx_dv(dut, max_cycles=300000)
        # Also ensure TX finished (sanity)
        #await wait_for_tx_done(dut, max_cycles=300000)
        assert got == sent, f"[{i}] sent=0x{sent:02X}, got=0x{got:02X}"

        # Give UART a small idle gap before next start bit
        #await idle_bits(dut, nbits=2)

@cocotb.test()
async def test_back_to_back_bytes(dut):
    cocotb.start_soon(Clock(dut.i_clock, CLK_PERIOD_NS, unit="ns").start())
    dut.i_tx_dv.value = 0
    dut.i_tx_byte.value = 0
    await RisingEdge(dut.i_clock)
    await RisingEdge(dut.i_clock)

    # Send next byte right after previous completes (watch o_tx_done)
    values = [0x12, 0x34, 0xA5, 0x5A]

    for v in values:
        await send_byte(dut, v)
        got = await wait_for_rx_dv(dut, max_cycles=10000)
        assert got == v, f"sent=0x{v:02X}, got=0x{got:02X}"

        # optional: wait until TX done is seen (not required, but nice)
        for _ in range(2000):
            await RisingEdge(dut.i_clock)
            if int(dut.o_tx_done.value) == 1:
                break
