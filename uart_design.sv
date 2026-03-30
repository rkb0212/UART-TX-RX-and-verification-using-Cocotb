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

  // wire w_loopback_serial;
  logic w_loopback_serial;
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

module uart_tx
#(parameter CLKS_PER_BIT)
(
input i_clock,
input i_tx_dv,
input [7:0] i_tx_byte,
output logic o_tx_active,
//output reg o_tx_serial,
output logic o_tx_serial,
output logic o_tx_done );

/*parameter s_idle = 3'b000;
parameter s_tx_start_bit = 3'b001;
parameter s_tx_data_bits = 3'b010;
parameter s_tx_stop_bit = 3'b011;
parameter s_cleanup = 3'b100; */

  typedef enum logic [2:0] {
 s_idle,
 s_tx_start_bit,
 s_tx_data_bits,
 s_tx_stop_bit,
 s_cleanup } tx_state_t;
  tx_state_t r_sm_main = s_idle;
  
/*reg [2:0] r_sm_main = 0;   
reg [7:0] r_clock_count = 0;
reg [2:0] r_bit_index = 0;
reg [7:0] r_tx_data = 0;
reg r_tx_done = 0;
reg r_tx_active = 0; */
  
//logic [2:0] r_sm_main = 0;   
logic [7:0] r_clock_count = 0;
logic [2:0] r_bit_index = 0;
logic [7:0] r_tx_data = 0;
logic r_tx_done;
logic r_tx_active = 0;
  
//always @(posedge i_clock)
always_ff @(posedge i_clock)

begin
case (r_sm_main)
s_idle :                                //case-1
begin
o_tx_serial <= 1'b1;
r_tx_done <= 1'b0;
r_clock_count <= 0;
r_bit_index <= 0;
if (i_tx_dv == 1'b1)
begin
r_tx_active <= 1'b1;
r_tx_data <= i_tx_byte;
r_sm_main <= s_tx_start_bit;
end
else
r_sm_main <= s_idle;
end

s_tx_start_bit :                         //case-2
begin
o_tx_serial <= 1'b0;
if (r_clock_count < CLKS_PER_BIT-1)
begin
r_clock_count <= r_clock_count +1;
r_sm_main <= s_tx_start_bit;
end
else
begin
r_clock_count <= 0;
r_sm_main <= s_tx_data_bits;
end
end

s_tx_data_bits :                        //case-3
begin
    o_tx_serial <= r_tx_data[r_bit_index];

    if (r_clock_count < CLKS_PER_BIT-1)
    begin
        r_clock_count <= r_clock_count + 1;
    end
    else
    begin
        r_clock_count <= 0;
        if (r_bit_index < 7)
        begin
            r_bit_index <= r_bit_index + 1;
        end
        else
        begin
            r_bit_index <= 0;
            r_sm_main <= s_tx_stop_bit;
        end
    end
end

s_tx_stop_bit :  //case-4
begin
o_tx_serial <= 1'b1;
if (r_clock_count < CLKS_PER_BIT-1)
begin
r_clock_count <= r_clock_count + 1;
r_sm_main <= s_tx_stop_bit;
end
else
begin
r_tx_done <= 1'b1;
r_clock_count <= 0;
r_sm_main <= s_cleanup;
r_tx_active <= 1'b0;
end
end

s_cleanup :
begin
r_tx_done <= 1'b1;
r_sm_main <= s_idle;
end

default:
r_sm_main <= s_idle;
endcase
end

assign o_tx_active = r_tx_active;
assign o_tx_done = r_tx_done;
endmodule

module uart_rx
#(parameter CLKS_PER_BIT)
(
input i_clock,
input i_rx_serial,
output logic o_rx_dv, //goes "1" when data is valid
output logic [7:0] o_rx_byte );
  
/*parameter s_idle = 3'b000;
parameter s_rx_start_bit = 3'b001;
parameter s_rx_data_bits = 3'b010;
parameter s_rx_stop_bit = 3'b011;
parameter s_cleanup = 3'b100; */
  
    typedef enum logic [2:0] {
 s_idle,
 s_rx_start_bit,
 s_rx_data_bits,
 s_rx_stop_bit,
      s_cleanup } rx_state_t;
  rx_state_t r_sm_main = s_idle;
  
/*reg r_rx_data_r = 1'b1;
reg r_rx_data = 1'b1;

reg [7:0] r_clock_count = 0;
reg [2:0] r_bit_index = 0;
reg [7:0] r_rx_byte = 0;
reg  r_rx_dv = 0;
  reg [2:0] r_sm_main = 0;  */

logic r_rx_data_r = 1'b1;
logic r_rx_data = 1'b1;

logic [7:0] r_clock_count = 0;
logic [2:0] r_bit_index = 0;
logic [7:0] r_rx_byte = 0;
logic  r_rx_dv = 0;
//logic [2:0] r_sm_main = 0;
  
//always @(posedge i_clock)
always_ff @(posedge i_clock)
begin
r_rx_data_r <= i_rx_serial;
r_rx_data   <= r_rx_data_r;
case (r_sm_main)
s_idle:               // case-1
begin
r_rx_dv <= 1'b0;
r_clock_count <= 0;
r_bit_index <= 0;
if (r_rx_data == 1'b0)
r_sm_main <= s_rx_start_bit;
else
r_sm_main <= s_idle;
end

s_rx_start_bit:      // case-2
begin
if (r_clock_count == (CLKS_PER_BIT-1)/2)
   begin
if (r_rx_data == 1'b0)
 begin
r_clock_count <= 0;
r_sm_main <= s_rx_data_bits;
 end
else
r_sm_main <= s_idle;
   end
else
    begin
r_clock_count <= r_clock_count +1;
r_sm_main <= s_rx_start_bit;
    end
end

s_rx_data_bits:   //case-3
begin
if (r_clock_count < CLKS_PER_BIT-1)
begin 
r_clock_count <= r_clock_count +1;
r_sm_main <= s_rx_data_bits;
end
else
begin
r_clock_count <= 0;
r_rx_byte[r_bit_index] <= r_rx_data;

if (r_bit_index < 7)
begin
r_bit_index <= r_bit_index +1;
r_sm_main <= s_rx_data_bits;
end
else
begin
r_bit_index <= 0;
r_sm_main <= s_rx_stop_bit;
end
end
end

s_rx_stop_bit :   //case-4
begin
if (r_clock_count < CLKS_PER_BIT-1)
begin
r_clock_count <= r_clock_count + 1;
r_sm_main <= s_rx_stop_bit;
end
else
begin
r_rx_dv <= 1'b1;
r_clock_count <= 0;
r_sm_main <= s_cleanup;
end
end

s_cleanup :
begin
r_sm_main <= s_idle;
r_rx_dv <= 1'b0;
end

default :
r_sm_main <= s_idle;
endcase
end
assign o_rx_dv = r_rx_dv;
assign o_rx_byte = r_rx_byte;
endmodule

interface uart_if;
  logic i_clock;
  
  logic i_tx_dv;
  logic [7:0] i_tx_byte;
  logic o_tx_active;
  logic o_tx_serial;
  logic o_tx_done;
  
  logic o_rx_dv;
  logic [7:0] o_rx_byte;
  
  //start bit check
  property p_start_bit;
    @(posedge i_clock)
    (i_tx_dv && !o_tx_active) |=> ##1 (o_tx_active && (o_tx_serial == 0));
  endproperty
  assert property(p_start_bit)
    else $error("Start bit violation detected");
    
  //tx done check
    property p_tx_done;
  @(posedge i_clock)
    o_tx_done |-> !o_tx_active;
  endproperty
  assert property(p_tx_done)
    else $error("TX done violation detected");
endinterface
