// tb_filter_core_rgb: checks that filter_core_rgb splits a 24-bit colour into
// red, green and blue, filters each one, and joins them back in the right order.
// (The maths itself is tested in tb_filter_core.)
// Each test prints PASS or FAIL in the transcript, with a total at the end.

module tb_filter_core_rgb;

    reg clk;
    reg resetn;
    reg win_start;
    reg [23:0] pix;             // {red, green, blue}
    reg pix_valid;
    reg [3:0] k;
    reg [2:0] filter_sel;
    wire [23:0] result;
    wire result_valid;

    filter_core_rgb dut (
        .clk(clk),
        .resetn(resetn),
        .win_start(win_start),
        .pix(pix),
        .pix_valid(pix_valid),
        .k(k),
        .filter_sel(filter_sel),
        .custom_weight(8'sd0),   // custom filter is tested in tb_filter_core
        .custom_shift(4'd0),
        .result(result),
        .result_valid(result_valid)
    );

    initial clk = 1'b0;
    always #10 clk = ~clk;

    // the 3x3 window of colour pixels, numbered like k:  0 1 2 / 3 4 5 / 6 7 8
    reg [23:0] win [0:8];
    integer i;

    integer passes;
    integer fails;
    integer valid_count;   // how many times result_valid has pulsed

    always @(posedge clk)
        if (result_valid)
            valid_count = valid_count + 1;

    task fill_all;
        input [23:0] colour;
        begin
            for (i = 0; i < 9; i = i + 1)
                win[i] = colour;
        end
    endtask

    // send one window: win_start on its own clock, then the 9 pixels
    task run_window;
        input [2:0] sel;
        begin
            filter_sel = sel;
            @(negedge clk);
            win_start = 1'b1;
            @(negedge clk);
            win_start = 1'b0;
            for (i = 0; i < 9; i = i + 1) begin
                pix = win[i];
                k = i;
                pix_valid = 1'b1;
                @(negedge clk);
                pix_valid = 1'b0;
                @(negedge clk);
            end
            repeat (6) @(negedge clk);
        end
    endtask

    // run the window and check the 24-bit answer (shown in hex: RRGGBB)
    task test;
        input [2:0] sel;
        input [23:0] expected;
        input [8*44:1] name;
        integer before;
        begin
            before = valid_count;
            run_window(sel);
            if (valid_count != before + 1) begin
                $display("FAIL  %0s: result_valid pulsed %0d times, expected 1", name, valid_count - before);
                fails = fails + 1;
            end
            else if (result !== expected) begin
                $display("FAIL  %0s: result = %h, expected %h", name, result, expected);
                fails = fails + 1;
            end
            else begin
                $display("PASS  %0s: result = %h", name, result);
                passes = passes + 1;
            end
        end
    endtask

    initial begin
        passes      = 0;
        fails       = 0;
        valid_count = 0;

        resetn     = 1'b0;
        win_start  = 1'b0;
        pix        = 24'd0;
        pix_valid  = 1'b0;
        k          = 4'd0;
        filter_sel = 3'b000;
        repeat (3) @(negedge clk);
        resetn = 1'b1;
        @(negedge clk);

        // 1. each colour different everywhere: blur of a flat area changes nothing,
        //    so any mixed-up or swapped channel would show
        fill_all(24'h6400FF);                       // red 100, green 0, blue 255
        test(3'b001, 24'h6400FF, "blur flat: channels stay separate");

        // 2. identity keeps the centre pixel, so R, G, B must come out in order
        fill_all(24'h000000);
        win[4] = 24'h0A141E;                        // red 10, green 20, blue 30
        test(3'b000, 24'h0A141E, "identity: R G B in the right order");

        // 3. an edge in red only: Sobel finds it in red, green and blue stay 0
        for (i = 0; i < 9; i = i + 1)
            win[i] = {8'd0, 8'd50, 8'd50};          // flat green and blue
        win[2][23:16] = 8'd255;                     // right column bright red
        win[5][23:16] = 8'd255;
        win[8][23:16] = 8'd255;
        test(3'b010, 24'hFF0000, "sobel: edge in red only");

        // 4. each channel gets its own answer: red flat 200, green 0,
        //    blue a 10..90 gradient (blur -> 50)
        for (i = 0; i < 9; i = i + 1)
            win[i] = {8'd200, 8'd0, 8'd0};
        for (i = 0; i < 9; i = i + 1)
            win[i][7:0] = (i + 1) * 10;
        test(3'b001, 24'hC80032, "blur: each channel filtered alone");

        $display("");
        $display("tb_filter_core_rgb: %0d passed, %0d failed", passes, fails);
        $stop;
    end

endmodule
