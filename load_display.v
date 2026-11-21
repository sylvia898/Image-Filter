module load_display(CLOCK_50, KEY, VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);
	
	input CLOCK_50;
	input [3:0] KEY;
	output [7:0] VGA_R, VGA_G, VGA_B;
	output VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK;
	
	wire resetn = KEY[0];
	wire [7:0] x;
	wire [6:0] y;
	wire [14:0] rom_address;
	wire [23:0] colour;
	wire plot, done;
	
	pixel_reader PR (CLOCK_50, resetn, x, y, rom_address, plot, done);
	
	image_rom IR(CLOCK_50, rom_address, colour);
	
	vga_adapter VGA (resetn, CLOCK_50, colour, x, y, plot, VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);
	
	defparam VGA.RESOLUTION = "160x120";
	defparam VGA.COLOR_DEPTH = 24;


endmodule

// ------------------------------------------------------------------------

module image_rom(clock, address, colour);

	input clock;
	input [14:0] address;
	output reg [23:0] colour;
	
	(* ram_init_file = "output_test_image.mif" *) reg [23:0] mem [0:32767];
	
	always@(posedge clock) begin
		colour <= mem[address];	
	end

endmodule

// ------------------------------------------------------------------------

module pixel_reader(clock, resetn, x, y, rom_address, plot, done);
//                    i      i    or7 or8   o14      or   or   
	parameter WIDTH = 160;
	parameter HEIGHT = 120;
	
	input clock, resetn;
	output reg [7:0] x;
	output reg [6:0] y;
	output [14:0] rom_address;
	output reg plot, done;
	
	reg [2:0] state, next_state;
	
	assign rom_address = {y, x};
	
	parameter S_ADDR = 3'b000;
	parameter S_WAIT = 3'b001;
	parameter S_PLOT = 3'b010;
	parameter S_NEXT = 3'b011;
	parameter S_DONE = 3'b100;
	// adder, wait, plot, next, done
	
	
	always@ (*) begin
		next_state = state;
		plot = 1'b0;
		done = 1'b0;
		
		case (state)
			S_ADDR: next_state = S_WAIT;
			S_WAIT: next_state = S_PLOT;
			S_PLOT: begin
				plot = 1;
				next_state = S_NEXT;
			end
			S_NEXT: begin
				if ((x == WIDTH - 1) && (y == HEIGHT - 1)) next_state = S_DONE;
				else next_state = S_ADDR;
			end
			S_DONE: begin
				done = 1;
				next_state = S_DONE;
			end
			default: next_state = S_ADDR;
		endcase
	
	end
	
	always@ (posedge clock) begin
		if (!resetn) begin
			state <= S_ADDR;
			x <= 0;
			y <= 0;
		end
		
		else begin
			state <= next_state;
			if (state == S_NEXT) begin
				if (x == WIDTH - 1) begin
					x <= 0;
					if (!(y == HEIGHT - 1)) y <= y + 1;
				end
				else x <= x + 1;
			end
			else if (state == S_DONE) begin
				x <= 0;
				y <= 0;
			end
		end
	
	end


endmodule

// ------------------------------------------------------------------------

