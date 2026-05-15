module i2s #(parameter CLK = 3579545)(clk, sound_l, sound_r, bclk, lrclk, sout);
input clk;
input [23:0] sound_l, sound_r;
output bclk, lrclk, sout;

localparam FS = 48000;
localparam I2S_DIV = $ceil($itor(CLK) / (128 * FS));

reg [3:0] divcnt = 0;
reg [6:0] cnt = 0;
reg [31:0] data = 0;
assign bclk = cnt[0];
assign lrclk = cnt[6];
assign sout = data[31];

always @(posedge clk)
	if (|divcnt) divcnt <= divcnt - 1'b1;
	else begin
		divcnt <= I2S_DIV - 1'b1;
		if (cnt[0])
			data <= |cnt[5:1] ? { data[30:0], 1'b0 } :
				{ lrclk ? sound_r : sound_l, 8'b0 };
		cnt <= cnt + 1'b1;
	end

endmodule
