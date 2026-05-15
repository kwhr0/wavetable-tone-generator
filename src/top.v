module top(I_clk, cs, sclk, miso, mosi, pa_en, bclk, lrclk, sout, uart_rx, uart_tx);
input I_clk, miso, uart_rx;
output cs, sclk, mosi, pa_en, bclk, lrclk, sout, uart_tx;

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

wire [15:0] pc, adr, data_out;

// RAM: 32kBytes
wire [12:0] iadr = pc[14:2];
wire [12:0] iadr1 = pc[1] ? iadr + 1'b1 : iadr;
wire [31:0] insn;

wire [12:0] dadr = adr[14:2];
wire [12:0] dadr0 = &adr[1:0] ? dadr + 1'b1 : dadr;

wire we0 = wr_u & adr[1:0] == 2'b00 | wr_l & adr[1:0] == 2'b11;
wire we1 = wr_u & adr[1:0] == 2'b01 | wr_l & adr[1:0] == 2'b00;
wire we2 = wr_u & adr[1:0] == 2'b10 | wr_l & adr[1:0] == 2'b01;
wire we3 = wr_u & adr[1:0] == 2'b11 | wr_l & adr[1:0] == 2'b10;

wire [7:0] dl = data_out[7:0], du = data_out[15:8];
wire [7:0] ramd0, ramd1, ramd2, ramd3;

reg [15:0] sel_adr;
always @(posedge clk)
	sel_adr <= adr;

wire [7:0] rx_data, spi_data;
wire [7:0] pdata = sel_adr[2] ?
	sel_adr[0] ? spi_data : rx_data :
	{ 3'b0, spi_busy, rx_valid, timer_active, tx_rdy, 1'b0 };
wire [15:0] data_in = {
	sel_adr[14:4] == 'b111_1111_1110 ? pdata :
	sel4x8(sel_adr, { ramd3, ramd2, ramd1, ramd0 }),
	sel4x8(sel_adr, { ramd0, ramd3, ramd2, ramd1 })
};

ram #(.FILE("ram0.mem"))
	ram0(.clk(clk), .ada(iadr1), .douta(insn[7:0]),
	.adb(dadr0), .dinb(adr[0] ? dl : du), .doutb(ramd0), .wreb(we0));
ram #(.FILE("ram1.mem"))
	ram1(.clk(clk), .ada(iadr1), .douta(insn[15:8]),
	.adb(dadr),  .dinb(adr[0] ? du : dl), .doutb(ramd1), .wreb(we1));
ram #(.FILE("ram2.mem"))
	ram2(.clk(clk), .ada(iadr), .douta(insn[23:16]),
	.adb(dadr),  .dinb(adr[0] ? dl : du), .doutb(ramd2), .wreb(we2));
ram #(.FILE("ram3.mem"))
	ram3(.clk(clk), .ada(iadr), .douta(insn[31:24]),
	.adb(dadr),  .dinb(adr[0] ? du : dl), .doutb(ramd3), .wreb(we3));

f6800wide f6800wide(.clk(clk), .reset(~rst_n),
	.rd_l(), .rd_u(rd_u), .wr_l(wr_l), .wr_u(wr_u),
	.pc_out(pc), .insn_in(insn),
	.adr_out(adr), .data_in(data_in), .data_out(data_out),
	.intreq(1'b0), .intack(), .nmireq(1'b0), .nmiack());

pll pll(.clkin(I_clk), .mdclk(I_clk), .clkout0(clk), .lock(lock));
reg [17:0] lockcnt = 0;
assign rst_n = lockcnt[17]; // >2mS
always @(posedge clk)
	if (~lock) lockcnt <= 0;
	else if (~rst_n) lockcnt <= lockcnt + 1'b1;

reg [7:0] sgadr = 0;
reg [15:0] sgdata = 0;
reg write, cs;
always @(posedge clk) begin
	if (wr_u) begin
		case (adr)
			'hffe1: cs <= data_out[8];
			'hffec: sgadr = data_out[15:8];
			'hffe8: sgdata[7:0] = data_out[15:8];
			'hffe9: begin
				sgdata[15:8] = data_out[15:8];
				write <= 1;
			end
		endcase
	end
	else write <= 0;
end

localparam SYSCLK = 48000000;

spi #(.CLK(SYSCLK)) spi(.clk(clk), .wr(wr_u & adr == 'hffe5),
	.data_in(data_out[15:8]), .data_out(spi_data), .fast(~cs),
	.mosi(mosi), .sclk(sclk), .miso(miso), .busy(spi_busy));

timer #(.CLK(SYSCLK))
	timer(.clk(clk), .wr(wr_u & adr == 'hffe2), .active(timer_active));

rx #(.CLK(SYSCLK)) rx(.clk(clk), .rd(rd_u & adr == 'hffe4), .data(rx_data), .valid(rx_valid), .pin(uart_rx));

tx #(.CLK(SYSCLK)) tx(.clk(clk), .stb(wr_u & adr == 'hffe4), .data(data_out[15:8]), .rdy(tx_rdy), .pin(uart_tx));

wire [15:0] snd_l, snd_r;
wtsg wtsg(.clk(clk), .wr(write), .adr(sgadr), .data(sgdata), .snd_l(snd_l), .snd_r(snd_r));

wire [23:0] snd_l24, snd_r24;
volume volume_l(.clk(clk), .wr(wr_u & adr == 'hffe3), .data(data_out[10:8]),
	.l_in(snd_l), .r_in(snd_r), .l_out(snd_l24), .r_out(snd_r24));
i2s #(.CLK(SYSCLK)) i2s(.clk(clk), .sound_l(snd_l24), .sound_r(snd_r24), .bclk(bclk), .lrclk(lrclk), .sout(sout));
assign pa_en = 1;

endmodule
