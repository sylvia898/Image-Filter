// Turns 9 pixels (1 centre and 8 neighbour pixels) into 1 pixel
// total = sum of (pixel x weight), then shift right, clamp to 0..255,
// and pulse result_valid for one clock.
module filter_core (
    input clk,
    input resetn, // active-low
    input win_start, // new pixel: clear the total
    input [7:0] pix,
    input pix_valid, // pix is a real neighbour this clock
    input [3:0] k, // neighbour number 0..8 (4 = centre)
    input [1:0] filter_sel, // 00 identity, 01 blur
    output reg [7:0] result,
    output reg result_valid
);

    // weight = how much neighbour k counts
    wire signed [7:0] weight;
    wire [3:0] shift;

    kernel_table kt (
        .filter_select(filter_sel),
        .k(k),
        .weight(weight),
        .shift(shift)
    );

    // add a 0 on top so 255 stays +255 when treated as signed
    wire signed [8:0]  pix_signed = {1'b0, pix};

    // 1. multiply: how much does this neighbour matter?
    //    (blur: centre x4, edges x2, corners x1; identity: only centre x1)
    wire signed [16:0] product = pix_signed * weight;

    // 2. add: combine the 9 weighted pixels into one number
    //    (blur on a flat area of 100: 16 x 100 = 1600)
    //    20 bits fits the worst case, 293,760
    reg signed [19:0] acc;

    // 1 for one clock after the 9th pixel has been added
    reg last_added;

    // 3. shift: bring the brightness back to normal
    //    blur weights add up to 16, so divide by 16: 1600 >>> 4 = 100
    //    a shift instead of / because dividing is slow and big in hardware
    wire signed [19:0] shifted = acc >>> shift;

    // 4. clamp: make it fit on the screen (a pixel is only 0..255)
    //    without it, 800 would wrap to 32 (dark) and -10 to 246 (bright)
    reg [7:0] clamped;

    always @(*) begin
        clamped = shifted[7:0];
        if (shifted < 20'sd0)
            clamped = 8'd0;
        else if (shifted > 20'sd255)
            clamped = 8'd255;
    end

    always @(posedge clk) begin
        if (!resetn) begin
            acc <= 20'sd0;
            result <= 8'd0;
            result_valid <= 1'b0;
            last_added <= 1'b0;
        end
        else begin
            // default 0, so these are only high for one clock
            result_valid <= 1'b0;
            last_added <= 1'b0;

            if (win_start)
                acc <= 20'sd0;
            else if (pix_valid) begin
                acc <= acc + product;
                if (k == 4'd8)
                    last_added <= 1'b1;
            end

            // acc now has all 9 pixels: output the answer
            if (last_added) begin
                result       <= clamped;
                result_valid <= 1'b1;
            end
        end
    end

endmodule
