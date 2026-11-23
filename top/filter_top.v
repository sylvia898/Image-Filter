// filter_top: reads the image from ROM, filters it, and shows it on VGA
//
// SW[1:0]: 00 identity, 01 blur, 10 Sobel, 11 custom
// KEY[0]:  reset
//
// Uses image_rom and vga_adapter from the load_display file, so that file
// (and the vga_adapter files) must be in the Quartus project too.
//
// The image is 24-bit colour, so there are 3 filter_cores: one each for
// red, green and blue. They all get the same k, win_start and pix_valid.

module filter_top (CLOCK_50, SW, KEY, VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);

    input CLOCK_50;
    input [9:0] SW;
    input [3:0] KEY;
    output [7:0] VGA_R, VGA_G, VGA_B;
    output VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK;

    wire resetn = KEY[0];
    wire [1:0] filter_sel = SW[1:0];

    // reader <-> ROM <-> filters
    wire [7:0] x;
    wire [6:0] y;
    wire [14:0] rom_address;
    wire [23:0] colour;            // {red, green, blue} from the ROM
    wire win_start, pix_valid, plot;
    wire [3:0] k;

    // filter results, one per colour
    wire [7:0] red_out, green_out, blue_out;
    wire red_valid, green_valid, blue_valid;

    // custom filter weights
    wire signed [7:0] custom_weight;
    wire [3:0] custom_shift;

    filter_reader FR (
        .clock(CLOCK_50),
        .resetn(resetn),
        .result_valid(red_valid),  // all 3 finish on the same clock, so any one works
        .x(x),
        .y(y),
        .rom_address(rom_address),
        .win_start(win_start),
        .pix_valid(pix_valid),
        .k_out(k),
        .plot(plot)
    );

    image_rom IR (CLOCK_50, rom_address, colour);

    filter_core FC_RED (
        .clk(CLOCK_50),
        .resetn(resetn),
        .win_start(win_start),
        .pix(colour[23:16]),
        .pix_valid(pix_valid),
        .k(k),
        .filter_sel(filter_sel),
        .custom_weight(custom_weight),
        .custom_shift(custom_shift),
        .result(red_out),
        .result_valid(red_valid)
    );

    filter_core FC_GREEN (
        .clk(CLOCK_50),
        .resetn(resetn),
        .win_start(win_start),
        .pix(colour[15:8]),
        .pix_valid(pix_valid),
        .k(k),
        .filter_sel(filter_sel),
        .custom_weight(custom_weight),
        .custom_shift(custom_shift),
        .result(green_out),
        .result_valid(green_valid)
    );

    filter_core FC_BLUE (
        .clk(CLOCK_50),
        .resetn(resetn),
        .win_start(win_start),
        .pix(colour[7:0]),
        .pix_valid(pix_valid),
        .k(k),
        .filter_sel(filter_sel),
        .custom_weight(custom_weight),
        .custom_shift(custom_shift),
        .result(blue_out),
        .result_valid(blue_valid)
    );

    // custom weights: for now entered with SW[9:2] + KEY1 (save) / KEY2 (restart).
    // When the keyboard part is ready, connect its value / Enter pulse / Esc pulse
    // to .value / .save / .restart instead, and remove the two key_pulses.
    wire save_pulse, restart_pulse;

    key_pulse KP_SAVE    (.clk(CLOCK_50), .resetn(resetn), .key_n(KEY[1]), .pulse(save_pulse));
    key_pulse KP_RESTART (.clk(CLOCK_50), .resetn(resetn), .key_n(KEY[2]), .pulse(restart_pulse));

    weight_entry WE (
        .clk(CLOCK_50),
        .resetn(resetn),
        .save(save_pulse),
        .restart(restart_pulse),
        .value(SW[9:2]),
        .k(k),                     // same k as the filter_cores
        .weight(custom_weight),
        .shift(custom_shift),
        .slot(),                   // not shown yet
        .done()
    );

    vga_adapter VGA (resetn, CLOCK_50, {red_out, green_out, blue_out}, x, y, plot,
                     VGA_R, VGA_G, VGA_B, VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);

    defparam VGA.RESOLUTION  = "160x120";
    defparam VGA.COLOR_DEPTH = 24;

endmodule
