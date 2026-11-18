`timescale 1ns / 1ps

module tb_filter_core;

    reg        clk;
    reg        resetn;
    reg        win_start;
    reg  [7:0] pix;
    reg        pix_valid;
    reg  [3:0] k;
    reg  [1:0] filter_sel;
    wire [7:0] result;
    wire       result_valid;

    filter_core dut (
        .clk(clk),
        .resetn(resetn),
        .win_start(win_start),
        .pix(pix),
        .pix_valid(pix_valid),
        .k(k),
        .filter_sel(filter_sel),
        .result(result),
        .result_valid(result_valid)
    );

    initial clk = 1'b0;
    always #10 clk = ~clk;

    reg [7:0] win [0:8];
    integer i;

    task fill_all;
        input [7:0] v;
        begin
            for (i = 0; i < 9; i = i + 1)
                win[i] = v;
        end
    endtask

    task fill_rows;
        input [7:0] left, mid, right;
        begin
            win[0] = left; win[1] = mid; win[2] = right;
            win[3] = left; win[4] = mid; win[5] = right;
            win[6] = left; win[7] = mid; win[8] = right;
        end
    endtask

    task run_window;
        input [1:0] sel;
        begin
            filter_sel = sel;
            @(negedge clk);
            win_start = 1'b1;
            @(negedge clk);
            win_start = 1'b0;
            for (i = 0; i < 9; i = i + 1) begin
                pix       = win[i];
                k         = i;
                pix_valid = 1'b1;
                @(negedge clk);
                pix_valid = 1'b0;
                @(negedge clk);
            end
            repeat (6) @(negedge clk);
        end
    endtask

    initial begin
        resetn     = 1'b0;
        win_start  = 1'b0;
        pix        = 8'd0;
        pix_valid  = 1'b0;
        k          = 4'd0;
        filter_sel = 2'b00;
        repeat (3) @(negedge clk);
        resetn = 1'b1;
        @(negedge clk);

        fill_all(8'd100);
        run_window(2'b01);

        fill_rows(8'd0, 8'd100, 8'd200);
        run_window(2'b00);

        fill_rows(8'd0, 8'd100, 8'd200);
        run_window(2'b01);

        fill_all(8'd255);
        run_window(2'b01);

        win[0] = 8'd10; win[1] = 8'd20; win[2] = 8'd30;
        win[3] = 8'd40; win[4] = 8'd50; win[5] = 8'd60;
        win[6] = 8'd70; win[7] = 8'd80; win[8] = 8'd90;
        run_window(2'b00);
        run_window(2'b01);

        fill_all(8'd0);
        run_window(2'b00);

        $stop;
    end

endmodule
