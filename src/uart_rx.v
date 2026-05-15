module rx #(parameter CLK = 27000000)(clk, rd, data, valid, pin);
input clk, rd, pin;
output valid;
output [7:0] data;

localparam BR = 115200;
localparam FULL = (CLK + BR / 2) / BR;
localparam HALF = FULL >> 1;

reg [8:0] timer = 0;
reg [9:0] data_sr = 0;
reg [2:0] pin_sr = 0;
reg valid = 0;
reg [7:0] data = 0;

always @(posedge clk) begin
	pin_sr <= { pin_sr[1:0], pin };
	if (|timer) timer <= timer - 1'b1;
	else if (data_sr[0]) begin
		data_sr <= { pin_sr[1], data_sr[9:1] };
		if (pin_sr[1] & ~data_sr[1]) begin
			valid <= 1;
			data <= data_sr[9:2];
		end
		else timer <= FULL - 1'b1;
	end
	else begin
		if (pin_sr[2:1] == 2'b10) begin
			data_sr <= 10'h3ff;
			timer <= HALF - 1'b1;
		end
		if (rd) valid <= 0;
	end
end

endmodule
