module uart_tx
#(parameter CLKS_PER_BIT)
(
input i_clock,
input i_tx_dv,
input [7:0] i_tx_byte,
output o_tx_active,
output reg o_tx_serial,
output o_tx_done );

parameter s_idle = 3'b000;
parameter s_tx_start_bit = 3'b001;
parameter s_tx_data_bits = 3'b010;
parameter s_tx_stop_bit = 3'b011;
parameter s_cleanup = 3'b100;

reg [2:0] r_sm_main = 0;   
reg [7:0] r_clock_count = 0;
reg [2:0] r_bit_index = 0;
reg [7:0] r_tx_data = 0;
reg r_tx_done = 0;
reg r_tx_active = 0;

always @(posedge i_clock)
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

