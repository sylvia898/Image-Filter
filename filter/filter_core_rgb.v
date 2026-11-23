module filter_core_rgb (
    input clk,
    input resetn,                     // active-low
    input win_start,
    input [23:0] pix,                 // {red, green, blue} from the ROM
    input pix_valid,
    input [3:0] k,
    input [2:0] filter_sel,
    input signed [7:0] custom_weight,
    input [3:0] custom_shift,
    output [23:0] result,    // was [7:0] before but now x 3
    output result_valid
);

    wire [7:0] red_out, green_out, blue_out;

    // each pixel takes 11 clocks, most of time, result holding previous pixel's answer
    // 1st clock cycle, 2-10 (adding 9 neighbours), 11 (this pixel's answer) (result_valid becomes 1)
    wire red_valid, green_valid, blue_valid;

    // red is [23:16]
    filter_core fc_red (
        .clk(clk),
        .resetn(resetn),
        .win_start(win_start),
        .pix(pix[23:16]),
        .pix_valid(pix_valid),
        .k(k),
        .filter_sel(filter_sel),
        .custom_weight(custom_weight),
        .custom_shift(custom_shift),
        .result(red_out), // .result is port name inside filter_core, wire here (filter_core_rgb is red_out)
        .result_valid(red_valid)
    );

    // green is [15:8]
    filter_core fc_green (
        .clk(clk),
        .resetn(resetn),
        .win_start(win_start),
        .pix(pix[15:8]),
        .pix_valid(pix_valid),
        .k(k),
        .filter_sel(filter_sel),
        .custom_weight(custom_weight),
        .custom_shift(custom_shift),
        .result(green_out),
        .result_valid(green_valid)
    );

    // blue is [7:0]
    filter_core fc_blue (
        .clk(clk),
        .resetn(resetn),
        .win_start(win_start),
        .pix(pix[7:0]),
        .pix_valid(pix_valid),
        .k(k),
        .filter_sel(filter_sel),
        .custom_weight(custom_weight),
        .custom_shift(custom_shift),
        .result(blue_out),
        .result_valid(blue_valid)
    );
    assign result = {red_out, green_out, blue_out}; // join 3 filtered colors into one 24-bit pixel
    assign result_valid = red_valid & green_valid & blue_valid;   // all 3 are done

    // output is 
endmodule 


