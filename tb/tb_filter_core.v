// tb_filter_core: tests filter_core + kernel_table for every filter
// (identity, blur, Sobel, sharpen, custom, unused setting).
// Each test prints PASS or FAIL in the transcript, with a total at the end.

module tb_filter_core;

    reg clk;
    reg resetn;
    reg win_start;
    reg [7:0] pix;
    reg pix_valid;
    reg [3:0] k;
    reg [2:0] filter_sel;
    wire [7:0] result;
    wire result_valid;

    // pretend to be weight_entry: a custom kernel the test sets,
    // looked up by k the same way weight_entry does it
    reg signed [7:0] custom_kernel [0:8];
    reg [3:0] custom_shift;
    reg signed [7:0] custom_weight;

    always @(*) begin
        if (k <= 4'd8)
            custom_weight = custom_kernel[k];
        else
            custom_weight = 8'sd0;
    end

    filter_core dut (
        .clk(clk),
        .resetn(resetn),
        .win_start(win_start),
        .pix(pix),
        .pix_valid(pix_valid),
        .k(k),
        .filter_sel(filter_sel),
        .custom_weight(custom_weight),
        .custom_shift(custom_shift),
        .result(result),
        .result_valid(result_valid)
    );

    initial clk = 1'b0;
    always #10 clk = ~clk;

    // the 3x3 window, numbered like k:  0 1 2 / 3 4 5 / 6 7 8
    reg [7:0] win [0:8];
    integer i;

    integer passes;
    integer fails;
    integer valid_count;   // how many times result_valid has pulsed

    always @(posedge clk)
        if (result_valid)
            valid_count = valid_count + 1;

    // every square the same
    task fill_all;
        input [7:0] v;
        begin
            for (i = 0; i < 9; i = i + 1)
                win[i] = v;
        end
    endtask

    // left, middle and right columns (a vertical edge)
    task fill_columns;
        input [7:0] left, middle, right;
        begin
            win[0] = left; win[1] = middle; win[2] = right;
            win[3] = left; win[4] = middle; win[5] = right;
            win[6] = left; win[7] = middle; win[8] = right;
        end
    endtask

    // top, middle and bottom rows (a horizontal edge)
    task fill_rows;
        input [7:0] top, middle, bottom;
        begin
            win[0] = top;    win[1] = top;    win[2] = top;
            win[3] = middle; win[4] = middle; win[5] = middle;
            win[6] = bottom; win[7] = bottom; win[8] = bottom;
        end
    endtask

    // 10 20 30 / 40 50 60 / 70 80 90
    task fill_gradient;
        begin
            for (i = 0; i < 9; i = i + 1)
                win[i] = (i + 1) * 10;
        end
    endtask

    // custom kernel, given as 9 weights and a shift
    task set_custom;
        input signed [7:0] w0, w1, w2, w3, w4, w5, w6, w7, w8;
        input [3:0] sh;
        begin
            custom_kernel[0] = w0; custom_kernel[1] = w1; custom_kernel[2] = w2;
            custom_kernel[3] = w3; custom_kernel[4] = w4; custom_kernel[5] = w5;
            custom_kernel[6] = w6; custom_kernel[7] = w7; custom_kernel[8] = w8;
            custom_shift = sh;
        end
    endtask

    // send one window the way the neighbour FSM will:
    // win_start on its own clock, then the 9 pixels with their k
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

    // run the window and check the answer (and that result_valid pulsed once)
    task test;
        input [2:0] sel;
        input [7:0] expected;
        input [8*40:1] name;
        integer before;
        begin
            before = valid_count;
            run_window(sel);
            if (valid_count != before + 1) begin
                $display("FAIL  %0s: result_valid pulsed %0d times, expected 1", name, valid_count - before);
                fails = fails + 1;
            end
            else if (result !== expected) begin
                $display("FAIL  %0s: result = %0d, expected %0d", name, result, expected);
                fails = fails + 1;
            end
            else begin
                $display("PASS  %0s: result = %0d", name, result);
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
        pix        = 8'd0;
        pix_valid  = 1'b0;
        k          = 4'd0;
        filter_sel = 3'b000;
        set_custom(0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        repeat (3) @(negedge clk);
        resetn = 1'b1;
        @(negedge clk);

        // ---------------- identity (000) ----------------
        fill_columns(8'd0, 8'd100, 8'd200);
        test(3'b000, 8'd100, "identity: keeps centre (columns)");
        fill_gradient;
        test(3'b000, 8'd50,  "identity: keeps centre (gradient)");
        fill_all(8'd0);
        test(3'b000, 8'd0,   "identity: all black");

        // ---------------- blur (001) ----------------
        fill_all(8'd100);
        test(3'b001, 8'd100, "blur: flat 100 stays 100");
        fill_columns(8'd0, 8'd100, 8'd200);
        test(3'b001, 8'd100, "blur: 0/100/200 columns -> 100");
        fill_all(8'd255);
        test(3'b001, 8'd255, "blur: flat 255 stays 255");
        fill_gradient;
        test(3'b001, 8'd50,  "blur: gradient -> 50");

        // ---------------- Sobel (010) ----------------
        fill_all(8'd100);
        test(3'b010, 8'd0,   "sobel: flat area is black");
        fill_columns(8'd0, 8'd0, 8'd255);
        test(3'b010, 8'd255, "sobel: dark->bright vertical edge");
        fill_columns(8'd255, 8'd0, 8'd0);
        test(3'b010, 8'd255, "sobel: bright->dark edge (abs)");
        fill_rows(8'd255, 8'd0, 8'd0);
        test(3'b010, 8'd255, "sobel: horizontal edge (Gy)");
        fill_columns(8'd100, 8'd100, 8'd110);
        test(3'b010, 8'd40,  "sobel: weak edge -> grey 40");

        // ---------------- sharpen (011) ----------------
        fill_all(8'd100);
        test(3'b011, 8'd100, "sharpen: flat 100 stays 100");
        fill_gradient;
        test(3'b011, 8'd50,  "sharpen: gradient -> 50");
        fill_all(8'd200);
        win[1] = 8'd0;
        test(3'b011, 8'd255, "sharpen: next to dark edge -> 255");
        fill_all(8'd100);
        win[4] = 8'd0;
        test(3'b011, 8'd0,   "sharpen: dark centre -> 0 (clamp)");

        // ---------------- custom (100) ----------------
        set_custom(1, 1, 1, 1, 1, 1, 1, 1, 1, 0);
        fill_all(8'd10);
        test(3'b100, 8'd90,  "custom: all 1s, shift 0 -> 9 x 10");
        set_custom(1, 1, 1, 1, 8, 1, 1, 1, 1, 4);
        fill_all(8'd100);
        test(3'b100, 8'd100, "custom: sum 16, shift 4 -> 100");
        set_custom(-1, -1, -1, -1, 8, -1, -1, -1, -1, 0);
        fill_all(8'd100);
        test(3'b100, 8'd0,   "custom: edge detect, flat -> 0");
        fill_all(8'd0);
        win[4] = 8'd100;
        test(3'b100, 8'd255, "custom: edge detect, bright dot");

        // ---------------- unused setting (101) ----------------
        fill_all(8'd100);
        test(3'b101, 8'd0,   "unused 101: all weights 0 -> 0");

        $display("");
        $display("tb_filter_core: %0d passed, %0d failed", passes, fails);
        $stop;
    end

endmodule
