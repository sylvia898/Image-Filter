`timescale 1ns / 1ps

module testbench ( );

	parameter CLOCK_PERIOD = 20;

	reg CLOCK_50;
	reg resetn;
	wire [7:0] x;
	wire [6:0] y;
	wire [14:0] rom_address;
	wire [23:0] colour;
	wire plot, done;

	integer i;

	initial begin
		CLOCK_50 = 1'b0;
	end

	always #(CLOCK_PERIOD / 2) CLOCK_50 = ~CLOCK_50;

	initial begin
		resetn = 1'b0;
		#(CLOCK_PERIOD * 4) resetn = 1'b1;
	end

	initial begin
		for (i = 0; i < 32768; i = i + 1)
			U2.mem[i] = i;
	end

	pixel_reader #(.WIDTH(8), .HEIGHT(8)) U1 (CLOCK_50, resetn, x, y, rom_address, plot, done);

	image_rom U2 (CLOCK_50, rom_address, colour);

endmodule