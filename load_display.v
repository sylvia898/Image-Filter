module load_display();


endmodule

// ------------------------------------------------------------------------

module image_rom(clock, address, Q);

	input clock;
	input [14:0] address;
	output reg [23:0] Q;
	
	(* ram_init_file = "output_test_image.mif" *) reg [23:0] mem [0:32767];
	
	always@(posedge clock) begin
		q <= mem[address];	
	end

endmodule

// ------------------------------------------------------------------------

module pixel_reader(clock, resetn, x, y, rom_adder, plot, done);
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
		end
	
	end


endmodule

// ------------------------------------------------------------------------

module vga_display();


endmodule

