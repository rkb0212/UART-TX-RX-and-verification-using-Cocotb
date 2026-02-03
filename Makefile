TOPLEVEL_LANG = verilog
SIM = icarus

PWD_ESC := $(shell pwd)

VERILOG_SOURCES = \
  $(PWD_ESC)/uart_tx.v \
  $(PWD_ESC)/uart_rx.v \
  $(PWD_ESC)/uart_loopback_top.v

TOPLEVEL = uart_loopback_top
COCOTB_TEST_MODULES = test_uart_loopback

IVERILOG_ARGS += -P uart_loopback_top.CLKS_PER_BIT=87

COCOTB_MAKEFILES := $(shell python -m cocotb_tools.config --makefiles)
include $(COCOTB_MAKEFILES)/Makefile.sim
