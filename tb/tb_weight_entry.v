// tb_weight_entry: tests weight_entry and key_pulse together.
// The testbench pretends to be:
//   - KEY1 (key1_n, active-low), going through key_pulse into start
//   - partner 1's keyboard decoder (key_valid + key_value)
//   - filter_core asking for weights (k)
// Each test prints PASS or FAIL in the transcript, with a total at the end.

module tb_weight_entry;

    reg clk;
    reg resetn;
    reg key1_n;              // fake KEY1 button: 1 = up, 0 = pressed
    reg key_valid;           // fake keyboard decoder
    reg [3:0] key_value;     // 0..9 digit, 10 minus, 11 Enter
    reg [3:0] k;             // fake filter_core asking for square k

    wire start_pulse;
    wire signed [7:0] weight;
    wire [3:0] shift;
    wire [3:0] entry;
    wire signed [7:0] signed_number;
    wire weights_changed;

    key_pulse kp (
        .clk(clk),
        .resetn(resetn),
        .key_n(key1_n),
        .pulse(start_pulse)
    );

    weight_entry dut (
        .clk(clk),
        .resetn(resetn),
        .start(start_pulse),
        .key_valid(key_valid),
        .key_value(key_value),
        .k(k),
        .weight(weight),
        .shift(shift),
        .entry(entry),
        .signed_number(signed_number),
        .weights_changed(weights_changed)
    );

    initial clk = 1'b0;
    always #10 clk = ~clk;

    integer i;
    integer passes;
    integer fails;
    integer start_count;     // how many start pulses key_pulse has made
    integer changed_count;   // how many weights_changed pulses

    always @(posedge clk) begin
        if (start_pulse)
            start_count = start_count + 1;
        if (weights_changed)
            changed_count = changed_count + 1;
    end

    // compare two numbers and print PASS / FAIL
    task check;
        input integer actual;
        input integer expected;
        input [8*44:1] name;
        begin
            if (actual == expected) begin
                $display("PASS  %0s: %0d", name, actual);
                passes = passes + 1;
            end
            else begin
                $display("FAIL  %0s: got %0d, expected %0d", name, actual, expected);
                fails = fails + 1;
            end
        end
    endtask

    // press one key on the "keyboard": key_valid high for one clock
    task press;
        input [3:0] value;
        begin
            @(negedge clk);
            key_value = value;
            key_valid = 1'b1;
            @(negedge clk);
            key_valid = 1'b0;
            repeat (2) @(negedge clk);
        end
    endtask

    // type a whole number and press Enter, e.g. -12 -> minus, 1, 2, Enter
    task type_number;
        input integer n;
        integer size;
        begin
            if (n < 0) begin
                press(4'd10);           // minus
                size = -n;
            end
            else
                size = n;
            if (size >= 100)
                press(size / 100);       // hundreds
            if (size >= 10)
                press((size / 10) % 10); // tens
            press(size % 10);            // ones
            press(4'd11);                // Enter
            repeat (3) @(negedge clk);   // let STORE and NEXT happen
        end
    endtask

    // hold KEY1 down for 20 clocks, then let go
    task press_start;
        begin
            @(negedge clk);
            key1_n = 1'b0;
            repeat (20) @(negedge clk);
            key1_n = 1'b1;
            repeat (5) @(negedge clk);
        end
    endtask

    // ask for each square's weight like filter_core does, and check all 9 + shift
    task check_kernel;
        input integer w0, w1, w2, w3, w4, w5, w6, w7, w8;
        input integer sh;
        input [8*44:1] name;
        integer expected;
        integer bad;
        begin
            bad = 0;
            for (i = 0; i < 9; i = i + 1) begin
                case (i)
                    0: expected = w0;
                    1: expected = w1;
                    2: expected = w2;
                    3: expected = w3;
                    4: expected = w4;
                    5: expected = w5;
                    6: expected = w6;
                    7: expected = w7;
                    default: expected = w8;
                endcase
                k = i;
                #1;
                if (weight != expected) begin
                    $display("FAIL  %0s: square %0d weight = %0d, expected %0d", name, i, weight, expected);
                    bad = 1;
                end
            end
            if (shift != sh) begin
                $display("FAIL  %0s: shift = %0d, expected %0d", name, shift, sh);
                bad = 1;
            end
            if (bad)
                fails = fails + 1;
            else begin
                $display("PASS  %0s", name);
                passes = passes + 1;
            end
        end
    endtask

    initial begin
        passes        = 0;
        fails         = 0;
        start_count   = 0;
        changed_count = 0;

        resetn    = 1'b0;
        key1_n    = 1'b1;
        key_valid = 1'b0;
        key_value = 4'd0;
        k         = 4'd0;
        repeat (3) @(negedge clk);
        resetn = 1'b1;
        @(negedge clk);

        $display("--- 1. after reset");
        check_kernel(0, 0, 0, 0, 1, 0, 0, 0, 0, 0, "reset: custom kernel is identity");
        check(entry, 0, "reset: entry is 0");

        $display("--- 2. typing before start does nothing");
        type_number(5);
        check(entry, 0, "still on entry 0");
        check(dut.number, 0, "number not changed in IDLE");

        $display("--- 3. key_pulse: holding KEY1 gives one start");
        press_start;
        check(start_count, 1, "20-clock press gives 1 start pulse");
        check(dut.state, dut.S_TYPING, "FSM is in TYPING");

        $display("--- 4. key_value without key_valid is ignored");
        @(negedge clk);
        key_value = 4'd7;
        repeat (10) @(negedge clk);
        check(dut.number, 0, "number stays 0 while key_valid = 0");

        $display("--- 5. signed_number shows what is being typed");
        press(4'd10);                    // minus
        press(4'd3);
        check(signed_number, -3, "typing - 3 shows -3");
        press(4'd11);                    // Enter: entry 0 = -3
        repeat (3) @(negedge clk);
        check(entry, 1, "Enter saved it, now entry 1");

        $display("--- 6. enter the rest of sharpen; kernel only changes at the end");
        // entry 0 was -3 above; restart to enter sharpen cleanly
        @(negedge clk);
        resetn = 1'b0;
        repeat (2) @(negedge clk);
        resetn = 1'b1;
        @(negedge clk);
        press_start;
        type_number(0);
        type_number(-1);
        type_number(0);
        type_number(-1);
        check(entry, 4, "4 numbers in, now entry 4");
        check_kernel(0, 0, 0, 0, 1, 0, 0, 0, 0, 0, "filter still uses identity");
        type_number(5);
        type_number(-1);
        type_number(0);
        type_number(-1);
        type_number(0);
        check(changed_count, 0, "no weights_changed before shift");
        type_number(0);                  // the shift
        check(changed_count, 1, "weights_changed pulsed once");
        check_kernel(0, -1, 0, -1, 5, -1, 0, -1, 0, 0, "active kernel is now sharpen");
        check(dut.state, dut.S_IDLE, "back to IDLE");

        $display("--- 7. out-of-range weights are rejected");
        press_start;
        type_number(200);
        check(entry, 0, "200 rejected, still entry 0");
        type_number(128);
        check(entry, 0, "+128 rejected, still entry 0");
        type_number(-129);
        check(entry, 0, "-129 rejected, still entry 0");
        type_number(-128);
        check(entry, 1, "-128 accepted, now entry 1");
        type_number(127);
        check(entry, 2, "127 accepted, now entry 2");

        $display("--- 8. only 3 digits are kept");
        press(4'd1);
        press(4'd2);
        press(4'd3);
        press(4'd4);
        check(dut.number, 123, "typing 1 2 3 4 keeps 123");
        press(4'd11);
        repeat (3) @(negedge clk);
        check(entry, 3, "123 accepted, now entry 3");

        for (i = 3; i < 9; i = i + 1)    // entries 3..8 = 0
            type_number(0);
        check(entry, 9, "now on entry 9 (shift)");

        $display("--- 9. the shift must be 0..15");
        type_number(16);
        check(entry, 9, "shift 16 rejected");
        type_number(-1);
        check(entry, 9, "shift -1 rejected");
        check(changed_count, 1, "no new kernel yet");
        type_number(4);
        check(changed_count, 2, "weights_changed pulsed again");
        check_kernel(-128, 127, 123, 0, 0, 0, 0, 0, 0, 4, "second kernel is live");

        $display("--- 10. k = 9..15 are not squares");
        k = 4'd9;
        #1;
        check(weight, 0, "k = 9 gives weight 0");
        k = 4'd15;
        #1;
        check(weight, 0, "k = 15 gives weight 0");

        $display("");
        $display("tb_weight_entry: %0d passed, %0d failed", passes, fails);
        $stop;
    end

endmodule
