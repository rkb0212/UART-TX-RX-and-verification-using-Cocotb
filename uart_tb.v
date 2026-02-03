module uart_tb ();
  parameter c_clock_period_ns = 100;
  parameter c_CLKS_PER_BIT    = 87;

  reg  r_clock   = 0;
  reg  r_tx_dv   = 0;
  reg  [7:0] r_tx_byte = 8'h00;

  wire w_tx_done;
  wire w_tx_serial;
  wire w_rx_dv;
  wire [7:0] w_rx_byte;

  // LOOPBACK: TX serial -> RX serial
  assign w_loopback_serial = w_tx_serial;
  //wire w_loopback_serial;

  uart_rx #(.CLKS_PER_BIT(c_CLKS_PER_BIT)) UART_RX_INST
  (
    .i_clock     (r_clock),
    .i_rx_serial (w_loopback_serial),
    .o_rx_dv     (w_rx_dv),
    .o_rx_byte   (w_rx_byte)
  );

  uart_tx #(.CLKS_PER_BIT(c_CLKS_PER_BIT)) UART_TX_INST
  (
    .i_clock     (r_clock),
    .i_tx_dv     (r_tx_dv),
    .i_tx_byte   (r_tx_byte),
    .o_tx_active (),
    .o_tx_serial (w_tx_serial),
    .o_tx_done   (w_tx_done)
  );

  // clock
  always #(c_clock_period_ns/2) r_clock <= !r_clock;

  integer timeout_cnt;

  initial begin
    // settle
    repeat (2) @(posedge r_clock);

    // transmit one byte
    r_tx_byte <= 8'hAB;
    r_tx_dv   <= 1'b1;
    @(posedge r_clock);
    r_tx_dv   <= 1'b0;

    // wait for rx_dv with timeout (pure Verilog)
    timeout_cnt = 0;
    while (w_rx_dv !== 1'b1 && timeout_cnt < (c_CLKS_PER_BIT * 20)) begin
      @(posedge r_clock);
      timeout_cnt = timeout_cnt + 1;
    end

    if (w_rx_dv === 1'b1) begin
      if (w_rx_byte == 8'hAB)
        $display("LOOPBACK PASS - Sent %h, Received %h", 8'hAB, w_rx_byte);
      else
        $display("LOOPBACK FAIL - Sent %h, Received %h", 8'hAB, w_rx_byte);
    end else begin
      $display("LOOPBACK TIMEOUT - RX did not assert o_rx_dv");
    end

    $finish;
  end

endmodule

