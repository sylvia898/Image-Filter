module load_display(CLOCK_50, KEY, VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK, SW, PS2_CLK, PS2_DAT, HEX0, HEX1, HEX2, HEX3, HEX4, HEX5);
	
	input CLOCK_50;
	input [3:0] KEY;
	input [9:0] SW;
	input PS2_CLK, PS2_DAT;
	
	output [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
	output [7:0] VGA_R, VGA_G, VGA_B;
	output VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK;
	
	wire resetn = KEY[0];
	
	// Start pulse for custom weight entry (KEY[1])
   wire start_weight_entry;
	
   key_pulse KP_START (CLOCK_50, resetn, KEY[1], start_weight_entry);

   // PS/2 Keyboard Decoder (Partner A)
   wire key_valid;
   wire [3:0] key_value;
	
   ps2_keyboard_decoder KBD (CLOCK_50, resetn, PS2_CLK, PS2_DAT, key_valid, key_value);
	 
	
	wire [7:0] x;
	wire [6:0] y;
	wire [14:0] rom_address;
	wire [23:0] colour;
	wire [3:0] k;
	wire win_start, pix_valid, filter_valid, plot, done;
	wire [23:0] vga_colour, filter_pix, filter_result;
	
	image_rom IR(CLOCK_50, rom_address, colour);
	
	neighbourhood_reader NR (CLOCK_50, resetn, filter_valid, colour, filter_result, x, y, rom_address, k, win_start, pix_valid, plot, done, vga_colour, filter_pix);
	
	wire signed [7:0] custom_weight, signed_number;
	wire [3:0] custom_shift, entry;
	wire weights_changed;
	
	weight_entry WE (CLOCK_50, resetn, start_weight_entry, key_valid, key_value, k, custom_weight, custom_shift, entry, signed_number, weights_changed);
	
	signed_hex_display HEX_WEIGHT (signed_number, HEX0, HEX1, HEX2);
	
	hex_decoder HEX_ENTRY (entry, HEX4);
	
	assign HEX3 = 7'b1111111;
	assign HEX5 = 7'b1111111;
	
	filter_core_rgb FC (CLOCK_50, resetn, win_start, filter_pix, pix_valid, k, SW[2:0], custom_weight, custom_shift, filter_result, filter_valid);
	 
	vga_adapter VGA (resetn, CLOCK_50, vga_colour, x, y, plot, VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);
	
	defparam VGA.RESOLUTION = "160x120";
	defparam VGA.COLOR_DEPTH = 24;
	defparam VGA.BACKGROUND_IMAGE = "black.mif";


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

module neighbourhood_reader (clock, resetn, filter_valid, rom_data, filter_result, x, y, rom_address, k, win_start, pix_valid, plot, done, vga_colour, filter_pix);
	input clock, resetn, filter_valid;
	input [23:0] rom_data, filter_result;
	output reg [7:0] x;
	output reg [6:0] y;
	output reg [14:0] rom_address;
	output reg [3:0] k; // 0-8 neighbour index
	output reg win_start, pix_valid, plot, done;
	output reg [23:0] vga_colour;
	output [23:0] filter_pix;
	
	parameter WIDTH  = 160;
   parameter HEIGHT = 120;
	
	assign filter_pix = rom_data;
	
	wire is_border = (x == 8'd0) || (x == WIDTH - 1) || (y == 7'd0) || (y == HEIGHT - 1);
	
	reg [7:0] neighbour_x;
	reg [6:0] neighbour_y;
	
	always@(*) begin
		case (k)
			4'b0000: begin // top left
				neighbour_x = x - 1;
				neighbour_y = y - 1;
			end
			4'b0001: begin // top middle
				neighbour_x = x;
				neighbour_y = y - 1;
			end
			4'b0010: begin // top right
				neighbour_x = x + 1;
				neighbour_y = y - 1;
			end
			4'b0011: begin // middle left
				neighbour_x = x - 1;
				neighbour_y = y;
			end
			4'b0100: begin // middle middle -> the pixel we're on
				neighbour_x = x;
				neighbour_y = y;
			end
			4'b0101: begin // middle right
				neighbour_x = x + 1;
				neighbour_y = y;
			end
			4'b0110: begin // bottom left
				neighbour_x = x - 1;
				neighbour_y = y + 1;
			end
			4'b0111: begin // bottom middle
				neighbour_x = x;
				neighbour_y = y + 1;
			end
			4'b1000: begin // bottom right
				neighbour_x = x + 1;
				neighbour_y = y + 1;
			end
			default: begin
				neighbour_x = x;
				neighbour_y = y;
			end
		endcase
	end
	
	// FSM STATES ------------------
	parameter S_CHECK = 4'b0000;
	parameter S_BORD_ADDR = 4'b0001;
	parameter S_BORD_WAIT = 4'b0010;
	parameter S_BORD_PLOT = 4'b0011;
	parameter S_WIN_START = 4'b0100; 
	parameter S_NEIGH_ADDR = 4'b0101;
	parameter S_NEIGH_WAIT = 4'b0110;
	parameter S_NEIGH_FEED = 4'b0111;
	parameter S_FILT_WAIT = 4'b1000;
	parameter S_FILT_PLOT = 4'b1001; 
	parameter S_NEXT = 4'b1010;
	parameter S_DONE = 4'b1011; 
	
	reg [3:0] state, next_state;
	
	always@(*) begin
		next_state = state;
		win_start = 0;
		pix_valid = 0;
		plot = 0;
		done = 0;
		rom_address = {y, x};
		vga_colour = rom_data;
		
		case (state)
			S_CHECK: begin
				if (is_border)
					next_state = S_BORD_ADDR;
				else
					next_state = S_WIN_START;
			end
			S_BORD_ADDR: begin
				rom_address = {y, x};
            next_state  = S_BORD_WAIT;
			end
			S_BORD_WAIT: begin
				rom_address = {y, x};
            next_state  = S_BORD_PLOT;
			end
			S_BORD_PLOT: begin
				vga_colour = rom_data;
            plot = 1;
            next_state = S_NEXT;
			end
			S_WIN_START: begin
				win_start  = 1'b1;
            next_state = S_NEIGH_ADDR;
			end
			S_NEIGH_ADDR: begin
				rom_address = {neighbour_y, neighbour_x};
            next_state  = S_NEIGH_WAIT;
			end
			S_NEIGH_WAIT: begin
				rom_address = {neighbour_y, neighbour_x};
            next_state  = S_NEIGH_FEED;
			end
			S_NEIGH_FEED: begin
				rom_address = {neighbour_y, neighbour_x};
            pix_valid = 1;
				if (k == 4'd8)
					next_state = S_FILT_WAIT;
            else
					next_state = S_NEIGH_ADDR;
			end
			S_FILT_WAIT: begin
				if (filter_valid)
					next_state = S_FILT_PLOT;
            else
					next_state = S_FILT_WAIT;
			end
			S_FILT_PLOT: begin
				vga_colour = filter_result;
            plot = 1;
            next_state = S_NEXT;
			end
			S_NEXT: begin
				if ((x == WIDTH - 1) && (y == HEIGHT - 1))
					next_state = S_DONE;
            else
               next_state = S_CHECK;
			end
			S_DONE: begin
				done = 1'b1;
            next_state = S_CHECK;
			end
			default: next_state = S_CHECK;
		endcase
	end
	
	always@(posedge clock) begin
		if (!resetn) begin
			state <= S_CHECK;
			x <= 0;
			y <= 0;
			k <= 0;
		end
		else begin
			state <= next_state;
			
			if (state == S_WIN_START) begin
				k <= 0;
			end
			else if (state == S_NEIGH_FEED && k < 4'd8) begin
				k <= k + 1;
			end
			
			if (state == S_NEXT) begin
				if (x == WIDTH - 1) begin
					x <= 0;
					if (y == HEIGHT - 1)
						y <= 0;
					else 
						y <= y + 1;
				end
				else
					x <= x + 1;
			end
		end
	end


endmodule

// ------------------------------------------------------------------------

module ps2_keyboard_decoder (clock, resetn, PS2_CLK, PS2_DAT, key_valid, key_value);

	input clock, resetn, PS2_CLK, PS2_DAT;
	output reg key_valid;
	output reg [3:0] key_value;
	
	reg [2:0] clck_sync;
	
	reg [3:0] bit_count;
	reg [10:0] shift_reg;
	reg byte_done;
	
	parameter KEY_MINUS = 4'd10;
	parameter KEY_ENTER = 4'd11;
	
	always@(posedge clock) begin
		if (!resetn)
			clck_sync <= 3'b111;
		else
			clck_sync <= {clck_sync[1:0], PS2_CLK};
	end
	
	wire clck_fall = (clck_sync[2:1] == 2'b10);
	
	always@(posedge clock) begin
		if (!resetn) begin
			bit_count <= 0;
			shift_reg <= 0;
			byte_done <= 0;
		end
		else begin
			byte_done <= 0;
			if (clck_fall) begin
				shift_reg <= {PS2_DAT, shift_reg[10:1]};
				if (bit_count == 4'd10) begin
					bit_count <= 0;
					byte_done <= 1;
				end
				else begin
					bit_count <= bit_count + 1;
				end
			end
		end
	end
	
	wire [7:0] scan_code = shift_reg[8:1];
	
	reg is_break;
	
	always@(posedge clock) begin
		if (!resetn) begin
			is_break <= 0;
			key_valid <= 0;
			key_value <= 0;
		end
		else begin
			key_valid <= 0;
			if (byte_done) begin
				if (scan_code == 8'd240) begin
					is_break <= 1;
				end
				else begin
					if (!is_break) begin
						case (scan_code)
							8'd69: begin // input key = 0
								key_value <= 0;
								key_valid <= 1;
							end
							8'd22: begin // input key = 1
								key_value <= 4'd1;
								key_valid <= 1;
							end
							8'd30: begin // input key = 2
								key_value <= 4'd2;
								key_valid <= 1;
							end
							8'd38: begin // input key = 3
								key_value <= 4'd3;
								key_valid <= 1;
							end
							8'd37: begin // input key = 4
								key_value <= 4'd4;
								key_valid <= 1;
							end
							8'd46: begin // input key = 5
								key_value <= 4'd5;
								key_valid <= 1;
							end
							8'd54: begin // input key = 6
								key_value <= 4'd6;
								key_valid <= 1;
							end
							8'd61: begin // input key = 7
								key_value <= 4'd7;
								key_valid <= 1;
							end
							8'd62: begin // input key = 8
								key_value <= 4'd8;
								key_valid <= 1;
							end
							8'd70: begin // input key = 9
								key_value <= 4'd9;
								key_valid <= 1;
							end
							8'd78: begin // input key = -
								key_value <= KEY_MINUS;
								key_valid <= 1;
							end
							8'd90: begin // input key = ENTER
								key_value <= KEY_ENTER;
								key_valid <= 1;
							end
							default : ;
						endcase
					end
					is_break <= 0;
				end
				
			end
		end
	end
	
	
endmodule

// ------------------------------------------------------------------------

