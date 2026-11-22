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
    input [1:0] filter_sel, // 00 identity, 01 blur, 10 Sobel, 11 custom
    input signed [7:0] custom_weight, // from weight_entry, passed to kernel_table
    input [3:0] custom_shift,         // from weight_entry, passed to kernel_table
    output reg [7:0] result,
    output reg result_valid
);

    // weight = how much neighbour k counts
    wire signed [7:0] weight; // normal weight for other filters and Gx
    wire signed [7:0] weight_y; // Gy, Sobel only
    wire [3:0] shift;

    kernel_table kt (
        .filter_select(filter_sel),
        .k(k),
        .custom_weight(custom_weight),
        .custom_shift(custom_shift),
        .weight(weight),
        .weight_y(weight_y),
        .shift(shift)
    );

    // add a 0 on top so 255 stays +255 when treated as signed
    wire signed [8:0]  pix_signed = {1'b0, pix};

    // 1. multiply: how much does this neighbour matter
    //    (blur: centre x4, edges x2, corners x1; identity: only centre x1)
    wire signed [16:0] product = pix_signed * weight;
    wire signed [16:0] product_gy = pix_signed * weight_y; 

    // 2. add: combine the 9 weighted pixels into one number
    reg signed [19:0] acc;
    reg signed [19:0] acc_gy;

    // 1 for one clock after the 9th pixel has been added
    reg last_added;

    reg signed [19:0] abs_gx; 
    reg signed [19:0] abs_gy; 
    reg signed [19:0] total; 

    // bit 19 = 0 means number is positive, bit 19 = 1 means number is negative
    // gx: takes vertical edge, gy: takes horizontal edge (makes them white)
    // inside becomes black (based on filter_table)
    always @(*) begin
        if (acc[19])
            abs_gx = -acc; 
        else 
            abs_gx = acc; 
        if (acc_gy[19])
            abs_gy = -acc_gy; 
        else 
            abs_gy = acc_gy; 
        
        // pick result for this filter
        if (filter_sel == 2'b10) 
            total = abs_gx + abs_gy; // Sobel
        else 
            total = acc; 
    end

    // 3. shift: bring the brightness back to normal
    //    blur weights add up to 16, so divide by 16: 1600 >>> 4 = 100
    //    a shift instead of / because dividing is slow and big in hardware
    wire signed [19:0] shifted = total >>> shift;

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

    // main part: runs once every clock edge
    always @(posedge clk) begin
        // reset button held: clear everything
        if (!resetn) begin
            acc <= 20'sd0;
            acc_gy <= 20'sd0;
            result <= 8'd0;
            result_valid <= 1'b0;
            last_added <= 1'b0;
        end
        else begin
            // default 0, so these are only high for one clock
            result_valid <= 1'b0;
            last_added <= 1'b0;

            // new pixel starting: total back to 0
            if (win_start) 
            begin 
                acc <= 20'sd0;
                acc_gy <= 20'sd0;
            end
            
            // a neighbour arrived: add it to the total
            else if (pix_valid) 
            begin
                acc <= acc + product;
                acc_gy <= acc_gy + product_gy; 
                // last neighbour? acc updates on this edge,
                // so wait one clock before using it
                if (k == 4'd8)
                    last_added <= 1'b1;
            end

            // acc now has all 9 pixels: output the answer
            if (last_added) 
            begin
                result       <= clamped;
                result_valid <= 1'b1;
            end
        end
    end

endmodule
