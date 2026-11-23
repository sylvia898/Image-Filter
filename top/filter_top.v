module filter_top (CLOCK_50, SW, KEY, HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, PS2_CLK, PS2_DAT,
                   VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);

    input CLOCK_50;
    input [9:0] SW;
    input [3:0] KEY;
    output [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    inout PS2_CLK, PS2_DAT;
    output [7:0] VGA_R, VGA_G, VGA_B;
    output VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK;

    wire resetn = KEY[0];
    wire [2:0] filter_sel = SW[2:0];

    // ---------------- wires between the parts ----------------

    // neighbour_reader <-> ROM <-> filter_core_rgb <-> VGA
    wire [7:0]  x;
    wire [6:0]  y;
    wire [14:0] rom_address;
    wire [23:0] colour;             // {red, green, blue} from the ROM
    wire win_start, pix_valid, plot;
    wire [3:0]  k;                  // same k goes to filter_core_rgb AND weight_entry
    wire [23:0] filtered_colour;    // {red, green, blue} after the filter
    wire result_valid;

    // keyboard -> weight_entry
    wire key_valid;
    wire [3:0] key_value;           // 0..9 digit, 10 minus, 11 Enter

    // weight_entry -> filter, display and redraw
    wire start_pulse;
    wire signed [7:0] custom_weight;
    wire [3:0] custom_shift;
    wire [3:0] entry;
    wire signed [7:0] signed_number;
    wire weights_changed;

    // filter_select -> neighbour_reader
    wire redraw;

    // ---------------- image: read neighbours, filter, draw ----------------
    neighbour_reader NR (
        .clock(CLOCK_50),
        .resetn(resetn),
        .redraw(redraw),
        .result_valid(result_valid),
        .x(x),
        .y(y),
        .rom_address(rom_address),
        .win_start(win_start),
        .pix_valid(pix_valid),
        .k(k),
        .plot(plot)
    );

    image_rom IR (CLOCK_50, rom_address, colour);

    filter_core_rgb FC (
        .clk(CLOCK_50),
        .resetn(resetn),
        .win_start(win_start),
        .pix(colour),
        .pix_valid(pix_valid),
        .k(k),
        .filter_sel(filter_sel),
        .custom_weight(custom_weight),
        .custom_shift(custom_shift),
        .result(filtered_colour),
        .result_valid(result_valid)
    );

    vga_adapter VGA (resetn, CLOCK_50, filtered_colour, x, y, plot,
                     VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);

    defparam VGA.RESOLUTION  = "160x120";
    defparam VGA.COLOR_DEPTH = 24;

    // ---------------- custom weights from the keyboard ----------------

    // partner 1: one key_valid pulse per key press
    keyboard_decoder KD (
        .clk(CLOCK_50),
        .resetn(resetn),
        .ps2_clk(PS2_CLK),
        .ps2_dat(PS2_DAT),
        .key_valid(key_valid),
        .key_value(key_value)
    );

    key_pulse KP_START (
        .clk(CLOCK_50),
        .resetn(resetn),
        .key_n(KEY[1]),
        .pulse(start_pulse)
    );

    weight_entry WE (
        .clk(CLOCK_50),
        .resetn(resetn),
        .start(start_pulse),
        .key_valid(key_valid),
        .key_value(key_value),
        .k(k),
        .weight(custom_weight),
        .shift(custom_shift),
        .entry(entry),
        .signed_number(signed_number),
        .weights_changed(weights_changed)
    );

    // ---------------- redraw when something changes ----------------

    // me: pulse redraw when SW[2:0] changes or a new custom kernel goes live
    filter_select FS (
        .clk(CLOCK_50),
        .resetn(resetn),
        .filter_sel(filter_sel),
        .weights_changed(weights_changed),
        .redraw(redraw)
    );

    // ---------------- HEX displays ----------------

    signed_hex_display SD (
        .value(signed_number),
        .hex0(HEX0),
        .hex1(HEX1),
        .hex2(HEX2)
    );

    hex_decoder HD_ENTRY (
        .digit(entry),
        .seg(HEX5)
    );

    assign HEX3 = 7'b1111111;   // blank
    assign HEX4 = 7'b1111111;   // blank

endmodule
