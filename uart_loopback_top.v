module uart_loopback_top #(
  parameter CLKS_PER_BIT = 87
)(
  input        i_clock,
  input        i_tx_dv,
  input  [7:0] i_tx_byte,
  output       o_tx_active,   
  output       o_tx_serial,
  output       o_tx_done,
  output       o_rx_dv,
  output [7:0] o_rx_byte
);

  wire w_loopback_serial;
  assign w_loopback_serial = o_tx_serial;  // loopback

  uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_tx (
    .i_clock     (i_clock),
    .i_tx_dv     (i_tx_dv),
    .i_tx_byte   (i_tx_byte),
    .o_tx_active (o_tx_active), 
    .o_tx_serial (o_tx_serial),
    .o_tx_done   (o_tx_done)
  );

  uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_rx (
    .i_clock     (i_clock),
    .i_rx_serial (w_loopback_serial),
    .o_rx_dv     (o_rx_dv),
    .o_rx_byte   (o_rx_byte)
  );

endmodule

