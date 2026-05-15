// 6800 MPU binary compatible soft core
// 32-bit instruction bus & 16-bit data bus
// Copyright 2026 © Yasuo Kuwahara

// MIT License

// not implemented: DAA, H flag

module f6800wide(clk, reset, pc_out, insn_in, adr_out, data_in, data_out,
	rd_l, rd_u, wr_l, wr_u, intreq, intack, nmireq, nmiack);
input clk, reset, intreq, nmireq;
input [31:0] insn_in;
input [15:0] data_in;
output [15:0] pc_out, adr_out, data_out;
output rd_l, rd_u, wr_l, wr_u, intack, nmiack;

localparam C = 0;
localparam V = 1;
localparam Z = 2;
localparam N = 3;
localparam I = 4;

reg [7:0] a, b;
reg [5:0] ccr;
reg [15:0] pc, sp, x;

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

//
// DECODE
//

wire [7:0] o = sel4x8(pc[1:0], insn_in) & {8{ ~force_nop }};
wire [23:0] insn = {
	o,
	sel4x8(pc[1:0], { insn_in[7:0], insn_in[31:8] }),
	sel4x8(pc[1:0], { insn_in[15:0], insn_in[31:16] })
};

localparam CPX = 0;
localparam DEX = 1;
localparam LDS = 2;
localparam LDX = 3;
localparam SEV = 4;
localparam TAP = 5;
localparam TSX = 6;
localparam TXS = 7;
localparam I1MAX = 7;
//
localparam ABA = 8;
localparam ADC = 9;
localparam ADD = 10;
localparam BR = 11;
localparam BSR = 12;
localparam CLCSEC = 13;
localparam CLISEI = 14;
localparam CLR = 15;
localparam CLVSEV = 16;
localparam CMP = 17;
localparam COM = 18;
localparam DEC = 19;
localparam DES = 20;
localparam INC = 21;
localparam INS = 22;
localparam INXDEX = 23;
localparam JMP = 24;
localparam JSR = 25;
localparam NEG = 26;
localparam PSHPUL = 27;
localparam PSH = 28;
localparam PUL = 29;
localparam SBACBA = 30;
localparam SBC = 31;
localparam SUB = 32;
localparam STA = 33;
localparam STS = 34;
localparam STX = 35;
localparam TAB = 36;
localparam TBA = 37;
localparam TPA = 38;
localparam TST = 39;
localparam RTI = 40;
localparam RTS = 41;
localparam SWIWAI = 42;
localparam ACC = 43;
localparam IMAX = 43;

wire [IMAX:0] i;
assign i[SUB] = o[7] & o[3:0] == 4'b0000;
assign i[CMP] = o[7] & o[3:0] == 4'b0001;
assign i[SBC] = o[7] & o[3:0] == 4'b0010;
assign i[STA] = o[7] & o[3:0] == 4'b0111;
assign i[ADC] = o[7] & o[3:0] == 4'b1001;
assign i[ADD] = o[7] & o[3:0] == 4'b1011;
assign i[NEG] = o[7:6] == 2'b01 & o[3:0] == 4'b0000;
assign i[DEC] = o[7:6] == 2'b01 & o[3:0] == 4'b1010;
assign i[INC] = o[7:6] == 2'b01 & o[3:0] == 4'b1100;
assign i[TST] = o[7:6] == 2'b01 & o[3:0] == 4'b1101;
assign i[CLR] = o[7:6] == 2'b01 & o[3:0] == 4'b1111;
assign i[COM] = o[7:6] == 2'b01 & o[3:0] == 4'b0011;
assign i[CPX] = o[7:6] == 2'b10 & o[3:0] == 4'b1100;
assign i[LDS] = o[7:6] == 2'b10 & o[3:0] == 4'b1110;
assign i[STS] = o[7:6] == 2'b10 & o[3:0] == 4'b1111;
assign i[LDX] = o[7:6] == 2'b11 & o[3:0] == 4'b1110;
assign i[STX] = o[7:6] == 2'b11 & o[3:0] == 4'b1111;
assign i[ACC] = o[7:5] == 3'b010;
assign i[JMP] = o[7:5] == 3'b011 & o[3:0] == 4'b1110;
assign i[JSR] = o[7:5] == 3'b101 & o[3:0] == 4'b1101;
assign i[BR] = o[7:4] == 4'b0010;
assign i[PSHPUL] = o[7:4] == 4'b0011 & ~o[3] & o[1];
assign i[PSH] = i[PSHPUL] & o[2];
assign i[PUL] = i[PSHPUL] & ~o[2];
assign i[INXDEX] = o[7:1] == 7'b0000100;
assign i[CLVSEV] = o[7:1] == 7'b0000101;
assign i[SEV] = i[CLVSEV] & o[0];
assign i[CLCSEC] = o[7:1] == 7'b0000110;
assign i[CLISEI] = o[7:1] == 7'b0000111;
assign i[SBACBA] = o[7:1] == 7'b0001000;
assign i[SWIWAI] = o[7:1] == 7'b0011111;
assign i[TPA] = o == 8'h07;
assign i[DEX] = o == 8'h09;
assign i[TAB] = o == 8'h16;
assign i[TBA] = o == 8'h17;
assign i[ABA] = o == 8'h1b;
assign i[TSX] = o == 8'h30;
assign i[INS] = o == 8'h31;
assign i[DES] = o == 8'h34;
assign i[TXS] = o == 8'h35;
assign i[TAP] = o == 8'h06;
assign i[RTS] = o == 8'h39;
assign i[RTI] = o == 8'h3b;
assign i[BSR] = o == 8'h8d;

// instruction byte count

wire byte1 = ~o[7] & (~o[5] | o[6:4] == 3'b011);
wire byte3 = o[7] & o[5:2] == 4'b0011 & ~o[0] | |o[7:6] & &o[5:4];
wire [1:0] bytes = { ~byte1 | byte3, byte1 | byte3 };

// state

wire dbl_state = o[7:5] == 3'b011 & o[3:0] <= 4'b1100; // read modify write
reg state;
always @(posedge clk)
	if (reset | state) state <= 1'b0;
	else if (dbl_state) state <= 1'b1;

// interrupt

reg [2:0] rcnt, wcnt;
reg [1:0] vect_n;
wire accept = active & ~(dbl_state & ~state) & ~i[RTS] & ~i[RTI];
wire valid_intr = intreq & ~ccr[I] | nmireq;
wire wcnt_dbl = wcnt >= 1 & wcnt <= 3;
wire wcnt_sngl = wcnt == 4;
wire wcnt_wai = wcnt == 5;
always @(posedge clk)
	if (reset) rcnt <= 0;
	else if (|rcnt) rcnt <= rcnt - 1'b1;
	else if (i[RTI]) rcnt <= 4; // start pull
always @(posedge clk)
	if (reset) begin
		wcnt <= 0;
		vect_n <= 0;
	end
	else if (wcnt[2] & |vect_n) wcnt <= 0;
	else if (wcnt_sngl | wcnt_dbl) wcnt <= wcnt + 1'b1;
	else if (wcnt_wai & valid_intr) begin
		wcnt <= 6; // exit WAI
		vect_n <= { ~nmireq, 1'b1 };
	end
	else if (accept & (valid_intr | i[SWIWAI])) begin
		wcnt <= 1; // start push
		vect_n <= valid_intr ? { ~nmireq, 1'b1 } : { o[0], 1'b0 };
	end
assign intack = vect_n == 2'b11 & |wcnt;
assign nmiack = vect_n == 2'b01 & |wcnt;

reg [2:0] active_sr;
always @(posedge clk)
	if (reset | wcnt_sngl & |vect_n | wcnt_wai & valid_intr) active_sr <= 0;
	else active_sr <= { active_sr[1:0], 1'b1 };
wire active = active_sr[2];

// EA

wire dir = o[7] & o[5:4] == 2'b01;
wire idx = o[7] & o[5:4] == 2'b10 | o[7:4] == 4'b0110;
wire [15:0] xofs = fwd_x + insn[15:8];
wire [15:0] ea = idx ? xofs : dir ? { 8'h00, insn[15:8] } : insn[15:0];

// PC

reg exec_ret1;
always @(posedge clk)
	if (reset) exec_ret1 <= 0;
	else exec_ret1 <= i[RTS] | i[RTI] & rcnt[1:0] == 2'b10;
wire force_nop = ~active | exec_ret1 | |wcnt;

wire bcs = fwd_ccr[C], bvs = fwd_ccr[V], beq = fwd_ccr[Z], bmi = fwd_ccr[N];
wire bls = fwd_ccr[C] | fwd_ccr[Z];
wire blt = fwd_ccr[N] ^ fwd_ccr[V], ble = blt | fwd_ccr[Z];
wire [7:0] cond = { ble, blt, bmi, bvs, beq, bcs, bls, 1'b0 };
wire cond_ok = cond[o[3:1]] ~^ o[0];
wire [15:0] nextpc_normal = pc + bytes;
wire [15:0] nextpc_rel = nextpc_normal + { {8{ insn[15] }}, insn[15:8] };
wire [15:0] nextpc = i[BR] & cond_ok | i[BSR] ? nextpc_rel :
	i[JMP] | i[JSR] ? ea : exec_ret1 ? data_in : nextpc_normal;

assign pc_out = active & ~(dbl_state & ~state) &
	~|wcnt & (~i[RTI] | rcnt[1:0] == 2'b01) ? nextpc : pc;
always @(posedge clk)
	pc <= active ? pc_out : data_in;

// address selector

wire [15:0] sp_adr = fwd_sp +
	{ {15{ i[BSR] | i[JSR] | wcnt_dbl }},
	~(i[PSH] | wcnt[2]) };
assign adr_out = active ?
	i[PSHPUL] | i[BSR] | i[JSR] | i[RTS] | |wcnt | i[RTI] ? sp_adr : ea :
	{ 13'b1111_1111_1111_1, ~vect_n, 1'b0 };

// write data (write only)

wire [7:0] wd_ab = (o[7] ? o[6] : o[0]) ? fwd_b : fwd_a;
wire [7:0] wd8 = |wcnt ? { 2'b11, /*fwd_*/ccr } :
	o[7:6] == 2'b01 ? 8'h00 : wd_ab;
wire [15:0] wd_r = wcnt[1] | ~|wcnt ? wcnt[0] ? { fwd_b, fwd_a } : fwd_x : pc;
wire [15:0] wd16 = o[1] | |wcnt ? o[6] | |wcnt ? wd_r : fwd_sp : nextpc_normal;
wire wr_s0_l = ~state & (i[BSR] | i[JSR] | i[STS] | i[STX]) | wcnt_dbl;
wire wr_s0_u = ~state & (i[PSH] | i[STA] | i[CLR] & o[5]) | wcnt_sngl;
wire [15:0] wd_s0 = { wr_s0_l ? wd16[15:8] : wd8, wd16[7:0] };
assign rd_l = ~state & o[7] & |o[5:4] & o[3:0] == 4'b1110;
assign rd_u = ~state &
	(o[7] & |o[5:4] & ~&o[2:0] | o[7:5] == 3'b011 & ~&o[3:0]);

//
// EXEC
//

wire [15:0] sft_lut = 16'h03d0;
wire [15:0] add4_lut = 16'hb409, add8_lut = 16'h1a07;
wire [15:0] wr_lut = 16'h97d9;
reg [15:0] imm1;
reg [7:0] o1;
reg [I1MAX:0] i1;
reg dbl_state1;
reg sel_s_a, sel_ab_b, sel_s_b, a_and, a_or, b_and, b_xor, c_and, c_xor;
reg sel_sft, sel_sfttpa, sel_add, sel_logic, wr;
always @(posedge clk) begin
	imm1 <= insn[15:0];
	i1 <= i[I1MAX:0];
	o1 <= o;
	dbl_state1 <= dbl_state;
	sel_s_a <= &o[7:6] | i[PSH] & o[0];
	sel_ab_b <= ~o[7] & o[5:4] == 2'b01;
	sel_s_b <= o[7:4] == 4'b0001 | i[ACC];
	a_and <= ~(i[INC] | i[NEG] | i[TBA] | i[CLR] | i[TST]);
	a_or <= i[COM] | i[DEC];
	b_and <= ~(i[STA] | i[PSH] | i[TAB] | i[CLR]);
	b_xor <= csub;
	c_and <= i[ADC] | i[SBC];
	c_xor <= csub | i[INC];
	sel_sft <= o[7:6] == 2'b01 & sft_lut[o[3:0]];
	sel_sfttpa <= o[7:6] == 2'b01 & sft_lut[o[3:0]] | i[TPA];
	sel_add <= o[7:4] == 4'b0001 | o[7:4] == 4'b0011 & &o[2:1] |
		o[7:6] == 2'b01 & add4_lut[o[3:0]] | o[7] & add8_lut[o[3:0]];
	sel_logic <= o[2] | i[PUL];
	wr <= (o[7:5] == 3'b011 & wr_lut[o[3:0]] | i[STA]);
end

wire [7:0] din = o1[7] & ~|o1[5:4] ? imm1[15:8] : data_in[15:8];
wire [7:0] s_a = sel_s_a ? b : a;
wire [7:0] ab_b = sel_ab_b ? b : a;
wire [7:0] s_b = sel_s_b ? ab_b : din;
wire [7:0] add_a = s_a & {8{ a_and }} | {8{ a_or }};
wire [7:0] add_b = s_b & {8{ b_and }} ^ {8{ b_xor }};
wire add_c = ccr[C] & c_and ^ c_xor;
wire [8:0] add_y = add_a + add_b + add_c;
wire [7:0] sft_y = o1[3] ? { s_b[6:0], o1[0] & ccr[C] } :
	{ o1[1] & (o1[0] ? s_b[7] : ccr[C]), s_b[7:1] };
wire [7:0] logic_y = sel_logic ? o1[1] ? din : din & s_a :
	o1[1] ? din | s_a : din ^ s_a;
wire [7:0] alu_y = sel_add ? add_y[7:0] :
	sel_sfttpa ? sel_sft ? sft_y : { 2'b11, ccr } : logic_y;

// write data (after read)

reg t_wr_s1_u;
always @(posedge clk)
	t_wr_s1_u <= dbl_state;
wire wr_s1_u = state & t_wr_s1_u;
assign wr_l = wr_s0_l;
assign wr_u = wr_s0_u | wr_s1_u | wr_s0_l;
assign data_out = wr_s1_u ? { alu_y, 8'h00 } : wd_s0;

//
// UPDATE
//

wire ren = ~dbl_state1 | state;
wire [15:0] ld_ab4_lut = 16'h97d9, ld_ab8_lut = 16'h0f55;
wire [15:0] d16 = |o1[5:4] ? data_in : imm1;

// A register

reg load_a1;
always @(posedge clk)
	load_a1 <= i[TPA] | i[ABA] | i[SBACBA] & ~o[0] | i[TBA] |
		i[PUL] & ~o[0] | o[7:4] == 4'b0100 & ld_ab4_lut[o[3:0]] |
		o[7:6] == 2'b10 & ld_ab8_lut[o[3:0]];
wire [7:0] fwd_a = load_a1 ? alu_y : a;
always @(posedge clk)
	if (ren & load_a1) a <= fwd_a;
	else if (&rcnt[1:0]) a <= data_in[7:0];

// B register

reg load_b1;
always @(posedge clk)
	load_b1 <= i[TAB] | i[PUL] & o[0] |
		o[7:4] == 4'b0101 & ld_ab4_lut[o[3:0]] |
		&o[7:6] & ld_ab8_lut[o[3:0]];
wire [7:0] fwd_b = load_b1 ? alu_y : b;
always @(posedge clk)
	if (ren & load_b1) b <= fwd_b;
	else if (&rcnt[1:0]) b <= data_in[15:8];

// X register

reg load_x1;
always @(posedge clk)
	load_x1 <= i[INXDEX] | i[LDX] | i[TSX];
wire [15:0] fwd_x = load_x1 ? i1[LDX] ? d16 :
	(i1[TSX] ? sp : x) + { {15{ i1[DEX] }}, 1'b1 } :
	x;
always @(posedge clk)
	if (ren & load_x1) x <= fwd_x;
	else if (rcnt[1:0] == 2'b10) x <= data_in;

// SP register

reg load_sp1;
reg [2:0] sp_add1;
wire sp_plus1 = i[INS] | i[PUL] | i[RTI] & ~|rcnt;
wire sp_plus2 = i[RTS] | rcnt >= 2;
wire sp_minus1 = i[DES] | i[PSH] | i[TXS] | wcnt_sngl;
wire sp_minus2 = i[BSR] | i[JSR] | wcnt_dbl;
always @(posedge clk) begin
	load_sp1 <= i[LDS] | sp_plus1 | sp_plus2 | sp_minus1 | sp_minus2;
	sp_add1 <= { sp_minus1 | sp_minus2, ~sp_plus1, sp_plus1 | sp_minus1 };
end
wire [15:0] fwd_sp = load_sp1 ? i1[LDS] ? d16 :
	(i1[TXS] ? x : sp) + { {13{ sp_add1[2] }}, sp_add1 } :
	sp;
always @(posedge clk)
	if (ren & load_sp1) sp <= fwd_sp;

// CCR register

wire cadd = i[ABA] | i[ADD] | i[ADC];
wire csub = i[SBACBA] | i[NEG] | i[COM] | o[7] & ~|o[3:2];
wire cvl = o[7:6] == 2'b01 & o[3:1] == 3'b100;
wire cvr = o[7:6] == 2'b01 & o[3:2] == 2'b01;
wire c0 = o[7:6] == 2'b01 & o[3:0] == 4'b1111 | i[CLCSEC] & ~o[0];
wire c1 = o[7:6] == 2'b01 & o[3:0] == 4'b0011 | i[CLCSEC] & o[0];
wire v0 = o[7] & &o[2:1];
wire vadd = cadd | i[INC];
wire vsub = csub | i[DEC];
wire zn8 = o[7] & ~&o[3:2] & o[3:0] != 4'b0111 |
	o[7:6] == 2'b01 & o[3:0] != 4'b1110 | o[7:4] == 4'b0001;
wire zn8st = o[7] & o[3:0] == 4'b0111;
wire zn16 = o[7] & &o[3:1];
wire zx16 = o[7:1] == 7'b0000100;
reg cadd1, csub1, cvl1, cvr1, c1_1, vadd1, vsub1, zn8_1, zn8st1, zn16_1, zx16_1;
reg t_z_st1, t_n_st1, t_i;
always @(posedge clk) begin
	cadd1 <= cadd;
	csub1 <= csub;
	cvl1 <= cvl;
	cvr1 <= cvr;
	c1_1 <= c1;
	vadd1 <= vadd;
	vsub1 <= vsub;
	zn8_1 <= zn8;
	zn8st1 <= zn8st;
	zn16_1 <= zn16;
	zx16_1 <= zx16;
	t_z_st1 <= ~|wd_ab;
	t_n_st1 <= wd_ab[7];
	t_i <= i[CLISEI] & o[0] | |wcnt;
end

wire t_c = cadd1 & add_y[8] | csub1 & ~add_y[8] |
	cvl1 & s_b[7] | cvr1 & s_b[0] | c1_1;
wire [15:0] cpx_t = { x[15:8] - d16[15:8], x[7:0] - d16[7:0] };
wire t_v = (vadd1 | vsub1) & (add_a[7] & add_b[7] & ~add_y[7] |
	~add_a[7] & ~add_b[7] & add_y[7]) |
	i1[CPX] & (~x[15] & d16[15] & ~cpx_t[15] |
	x[15] & ~d16[15] & cpx_t[15]) |
	cvl1 & (s_b[6] ^ s_b[7]) | cvr1 & (s_b[0] ^ s_b[7]) | i1[SEV];
wire t_z = zn8_1 & ~|alu_y | zn8st1 & t_z_st1 |
	(zn16_1 | zx16_1) & ~|fwd_x | i1[CPX] & ~|cpx_t;
wire t_n = zn8_1 & alu_y[7] | zn8st1 & t_n_st1 |
	zn16_1 & fwd_x[15] | i1[CPX] & cpx_t[15];

reg update_c, update_v, update_z, update_n, update_i;
always @(posedge clk) begin
	update_c <= cadd | csub | cvl | cvr | c0 | c1;
	update_v <= vadd | vsub | cvl | cvr | v0 | i[CLVSEV] | i[CPX];
	update_z <= zn8 | zn8st | zn16 | zx16 | i[CPX];
	update_n <= zn8 | zn8st | zn16 | i[CPX];
	update_i <= i[CLISEI] | wcnt[2] & (wcnt[1] | |vect_n);
end

wire [5:0] fwd_ccr = rcnt[2] ? data_in[13:8] : i1[TAP] ? a[5:0] : {
	ccr[5],
	ren & update_i ? t_i : ccr[4],
	ren & update_n ? t_n : ccr[3],
	ren & update_z ? t_z : ccr[2],
	ren & update_v ? t_v : ccr[1],
	ren & update_c ? t_c : ccr[0]
};
always @(posedge clk)
	ccr <= fwd_ccr;


wire [7:0] cc = fwd_ccr[C] === 1 ? "C" : fwd_ccr[C] === 0 ? "-" : "?";
wire [7:0] vc = fwd_ccr[V] === 1 ? "V" : fwd_ccr[V] === 0 ? "-" : "?";
wire [7:0] zc = fwd_ccr[Z] === 1 ? "Z" : fwd_ccr[Z] === 0 ? "-" : "?";
wire [7:0] nc = fwd_ccr[N] === 1 ? "N" : fwd_ccr[N] === 0 ? "-" : "?";
wire [7:0] ic = fwd_ccr[I] === 1 ? "I" : fwd_ccr[I] === 0 ? "-" : "?";
initial $monitor("%x %x %x %x %x %x %x %s%s%s%s%s %x%xM %x %x %x",
	pc, force_nop, o, fwd_a, fwd_b, fwd_x, fwd_sp, ic, nc, zc, vc, cc,
	wr_u, wr_l, adr_out, data_out, data_in);
endmodule
