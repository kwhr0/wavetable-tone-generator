module tx #(parameter CLK = 27000000)(clk, stb, data, rdy, pin);
input clk, stb;
input [7:0] data;
output reg rdy;
output pin;

localparam BR = 115200;
localparam UART_DIV = (CLK + BR / 2) / BR;

reg [8:0] data_n = 0;
reg [3:0] cnt = 0;
reg [8:0] timer = 0;

always @(posedge clk) begin
	if (rdy & stb) begin
		data_n <= { ~data, 1'b1 };
		cnt <= 9;
		timer <= UART_DIV - 1;
	end
	if (|timer) timer <= timer - 1'b1;
	else if (|cnt) begin
		data_n <= { 1'b0, data_n[8:1] };
		cnt <= cnt - 1'b1;
		timer <= UART_DIV - 1;
	end
	rdy <= ~|cnt & ~|timer;
end

assign pin = ~data_n[0];

endmodule
