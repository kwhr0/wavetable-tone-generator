module volume(clk, wr, data, l_in, r_in, l_out, r_out);
input clk, wr;
input [2:0] data;
input [15:0] l_in, r_in;
output reg [23:0] l_out, r_out;

reg [2:0] cnt, att;
reg [23:0] sr_l, sr_r;
always @(posedge clk) begin
	if (wr) att <= ~data;
	if (~|cnt) begin
		sr_l <= { l_in, 8'b0 };
		sr_r <= { r_in, 8'b0 };
		l_out <= sr_l;
		r_out <= sr_r;
	end
	else if (att >= cnt) begin
		sr_l <= { sr_l[23], sr_l[23:1] };
		sr_r <= { sr_r[23], sr_r[23:1] };
	end
	cnt <= cnt + 1'b1;
end

endmodule
