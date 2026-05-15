// wavetable tone generator
// Copyright 2026 © Yasuo Kuwahara

// MIT License

module wtg(clk, wr, adr, data, snd_l, snd_r);
input clk, wr;
input [7:0] adr;
input [15:0] data;
output reg [15:0] snd_l, snd_r;

localparam WAVE = 3;	// 0: PSG 1: 64waves 2: 128waves 3: 256waves
localparam ATT = 3;

function [7:0] sel4x8;
	input [1:0] sel;
	input [31:0] a;
	begin
		case (sel)
			2'b00: sel4x8 = a[7:0];
			2'b01: sel4x8 = a[15:8];
			2'b10: sel4x8 = a[23:16];
			2'b11: sel4x8 = a[31:24];
		endcase
	end
endfunction

reg [2:0] scnt = 7;
always @(posedge clk)
	scnt <= scnt + 1'b1;
wire [7:0] s = 8'b1 << scnt;

reg [7:0] radr = 0;
always @(posedge clk)
	if (s[1] | s[4] | s[6] | s[7]) radr <= radr + 1'b1;

reg [15:0] ram[0:'hff];
reg [15:0] ram_dout = 0, ram_dout1 = 0;
always @(posedge clk) begin
	if (wr) ram[adr] <= data;
	if (s[0] | s[1]) ram_dout1 <= ram_dout;
	if (s[1]) ram[radr] <= ram_dout + ram_dout1;
	else ram_dout <= ram[radr];
end

wire [4:0] widx = ram_dout1[15:11] + s[4];
reg [7:0] wave_dout = 0;
generate if (WAVE >= 1 && WAVE <= 3) begin
	wire [12:0] wave_adr = { ram_dout[7:0], widx };
	reg [7:0] wave[0:('h400<<WAVE)-1];
	initial $readmemh("_wave", wave);
	always @(posedge clk)
		wave_dout <= wave[wave_adr];
end
else begin
	wire [4:0] triangle = { &widx[4:3], widx[3], 2'b00, ^widx[4:3] } +
		(^widx[4:3] ? ~widx[2:0] : widx[2:0]);
	wire [4:0] square = {
		{2{ widx[4] & (widx[3] | ~|ram_dout[1:0]) & (widx[2] | ~ram_dout[1]) }},
		3'b100 };
	always @(posedge clk)
		wave_dout <= { &ram_dout[1:0] ? triangle : square, 3'b000 };
end
endgenerate

reg [14:0] noise_sr = 1;
reg isnoise = 0;
always @(posedge clk) begin
	noise_sr <= { noise_sr[13:0], noise_sr[14] ^ noise_sr[0] };
	if (s[3]) isnoise <= &ram_dout[7:0];
end
wire [8:0] noise = noise_sr[0] ? 9'h010 : 9'h1f0;

reg [22:0] acc_l = 0, acc_r = 0;
reg [14:0] intp = 0;
wire [7:0] idx_inv = 'h80 - ram_dout1[10:4];
wire signed [8:0] mult_a = sel4x8(scnt[1:0],
	{ ram_dout, 1'b0, ram_dout1[10:4], idx_inv });
wire signed [8:0] mult_b = s[4] | s[5] ?
	isnoise ? noise : { wave_dout[7], wave_dout } :
	intp[14:6];
wire [17:0] mult_y = mult_a * mult_b;
wire [22:0] add_a = s[4] | s[5] ? intp : s[6] ? acc_l : acc_r;
wire [22:0] add_y = add_a + { {5{ mult_y[17] }}, mult_y };
always @(posedge clk)
	if (s[3]) intp <= 0;
	else if (s[4] | s[5]) intp <= add_y[14:0];

always @(posedge clk)
	if (~|radr) begin
		snd_l <= ~acc_l[22] & |acc_l[21:15+ATT] ? 16'h7fff :
			acc_l[22] & ~&acc_l[21:15+ATT] ? 16'h8000 :
			acc_l[15+ATT:ATT];
		snd_r <= ~acc_r[22] & |acc_r[21:15+ATT] ? 16'h7fff :
			acc_r[22] & ~&acc_r[21:15+ATT] ? 16'h8000 :
			acc_r[15+ATT:ATT];
		acc_l <= 0;
		acc_r <= 0;
	end
	else begin
		if (s[6]) acc_l <= add_y;
		if (s[7]) acc_r <= add_y;
	end

integer c;
initial begin
	for (c = 0; c <= 'hff; c = c + 1)
		ram[c] = 0;
end

endmodule
