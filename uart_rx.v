module uart_rx
#(parameter CLKS_PER_BIT)
(
input i_clock,
input i_rx_serial,
output o_rx_dv, //goes "1" when data is valid
output [7:0] o_rx_byte );
parameter s_idle = 3'b000;
parameter s_rx_start_bit = 3'b001;
parameter s_rx_data_bits = 3'b010;
parameter s_rx_stop_bit = 3'b011;
parameter s_cleanup = 3'b100;
reg r_rx_data_r = 1'b1;
reg r_rx_data = 1'b1;

reg [7:0] r_clock_count = 0;
reg [2:0] r_bit_index = 0;
reg [7:0] r_rx_byte = 0;
reg  r_rx_dv = 0;
reg [2:0] r_sm_main = 0;

always@(posedge i_clock)
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