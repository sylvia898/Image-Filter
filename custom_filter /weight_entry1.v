// weight_entry: fsm for user to input their custom weights with the keyboard

// Two sets of registers:
//   new_kernel[0..9]    - what the user is typing in (9 weights + shift)
//   active_kernel[0..9] - what the filter actually uses
// The filter keeps using the old kernel until all 10 are entered, so a
// half-typed kernel never shows on screen.

module weight_entry (
    input clk,
    input resetn,                    // active-low
    input start,                     // one-clock pulse: begin entering a new kernel
    input key_valid,                 // from keyboard decoder: 1 for one clock per key press
    input [3:0] key_value,           // from keyboard decoder: 0..9 digit, 10 minus, 11 Enter
    input [3:0] k,                   // from filter_core: which weight it wants right now
    output reg signed [7:0] weight,  // active weight for square k
    output [3:0] shift,              // active shift
    output reg [3:0] entry,          // which entry is being typed: 0..8 weights, 9 shift
    output reg signed [7:0] signed_number, // the number typed so far, with its sign (for the display)
    output reg weights_changed       // 1 for one clock when the new kernel goes live
);

    // FSM states (5 states, so 3 bits: 2 bits could only count 4)
    parameter S_IDLE   = 3'b000;  // waiting for start
    parameter S_TYPING = 3'b001;  // building the number from key presses
    parameter S_STORE  = 3'b010;  // Enter pressed: check range, save to new_kernel
    parameter S_NEXT   = 3'b011;  // move on to the next entry
    parameter S_DONE   = 3'b100;  // all 10 in: copy new_kernel -> active_kernel

    // key_value meanings (agreed with the keyboard decoder)
    // 0..9 are the digits themselves
    parameter KEY_MINUS = 4'd10;
    parameter KEY_ENTER = 4'd11;

    reg [2:0] state, next_state;   // 3 bits: holds one of the 5 states above

    // the number being typed, split into its size and its sign
    // e.g. typing - 1 2 5 gives number = 125, is_negative = 1, signed_number = -125
    reg [9:0] number;              // 10 bits: up to 3 digits = 999, and 2^10 = 1024 > 999
    reg is_negative;               // 1 bit: 1 = minus was typed, 0 = positive

    // 10 entries each (0..8 weights, 9 shift), 8 bits signed each (-128..127)
    reg signed [7:0] new_kernel    [0:9];
    reg signed [7:0] active_kernel [0:9];

    integer index;                 // loop counter, only used while compiling

    // ---------------- range check ----------------

    // weights (entries 0..8): -128..127     shift (entry 9): 0..15
    reg in_range;

    always @(*) begin
        if (entry == 4'd9)
            in_range = !is_negative && (number <= 10'd15);
        else if (is_negative)
            in_range = (number <= 10'd128);
        else
            in_range = (number <= 10'd127);
    end

    // put the sign back on: 8 bits signed, since that's what a weight is
    always @(*) begin
        if (is_negative)
            signed_number = 8'd0 - number[7:0];   // 0 - 125 = -125
        else
            signed_number = number[7:0];          // stays 125
    end

    // ---------------- block 1: next state ----------------

    always @(*) begin
        next_state = state;

        case (state)
            S_IDLE: begin
                if (start)
                    next_state = S_TYPING;
            end
            S_TYPING: begin
                if (key_valid && key_value == KEY_ENTER)
                    next_state = S_STORE;
            end
            S_STORE: begin
                if (in_range)
                    next_state = S_NEXT;
                else
                    next_state = S_TYPING;     // try this entry again
            end
            S_NEXT: begin
                if (entry < 4'd9)
                    next_state = S_TYPING;
                else
                    next_state = S_DONE;
            end
            S_DONE: begin
                next_state = S_IDLE;
            end
            default: next_state = S_IDLE;
        endcase
    end

    // ---------------- block 2: registers ----------------

    always @(posedge clk) begin
        if (!resetn) begin
            state           <= S_IDLE;  // 3 bits: start waiting for start
            entry           <= 4'd0;    // 4 bits: 0..9 needs 4 (3 bits only reach 7)
            number          <= 10'd0;   // 10 bits: nothing typed yet
            is_negative     <= 1'b0;    // 1 bit: positive
            weights_changed <= 1'b0;    // 1 bit: no change yet
            // start as identity (centre = 1, shift 0) so the image isn't all black
            for (index = 0; index < 10; index = index + 1) begin
                active_kernel[index] <= 8'sd0;
                new_kernel[index]    <= 8'sd0;
            end
            active_kernel[4] <= 8'sd1;
            new_kernel[4]    <= 8'sd1;
        end
        else begin
            state <= next_state;
            weights_changed <= 1'b0;   // default: only high for one clock

            case (state)
                S_IDLE: begin
                    if (start) begin
                        entry       <= 4'd0;
                        number      <= 10'd0;
                        is_negative <= 1'b0;
                    end
                end

                S_TYPING: begin
                    if (key_valid) begin
                        if (key_value <= 4'd9) begin
                            // a digit: e.g. 12 then 5 -> 125; stop at 3 digits
                            if (number < 10'd100)
                                number <= number * 10'd10 + key_value;
                        end
                        else if (key_value == KEY_MINUS)
                            is_negative <= 1'b1;
                    end
                end

                S_STORE: begin
                    if (in_range)
                        new_kernel[entry] <= signed_number;
                    else begin
                        number      <= 10'd0;  // throw it away, type again
                        is_negative <= 1'b0;
                    end
                end

                S_NEXT: begin
                    entry       <= entry + 4'd1;
                    number      <= 10'd0;
                    is_negative <= 1'b0;
                end

                S_DONE: begin
                for (index = 0; index < 10; index = index + 1)
                    active_kernel[index] <= new_kernel[index];
                    weights_changed <= 1'b1;
                end

                default: ;
            endcase
        end
    end

    // look up the weight filter_core is asking for (k = 9..15 aren't weights)
    always @(*) begin
        if (k <= 4'd8)
            weight = active_kernel[k];   // squares 0..8
        else
            weight = 8'sd0;              // k = 9..15 aren't squares
    end
    assign shift  = active_kernel[9][3:0];   // shift is 0..15, so only the low 4 bits

endmodule

// ------------------------------------------------------------------------

// key_pulse: turns one press of a KEY button into a single one-clock pulse,
// which is what weight_entry's start input needs.
//
// Why: a press lasts millions of clocks at 50 MHz. Without this, start
// would stay high for the whole press.
// KEY buttons are active-low: 1 = not pressed, 0 = pressed.
//
// Hook-up:
//   key_pulse KP_START (.clk(CLOCK_50), .resetn(KEY[0]), .key_n(KEY[1]), .pulse(start_pulse));
//   weight_entry WE (... .start(start_pulse), ...);

module key_pulse (
    input clk,
    input resetn,     // active-low
    input key_n,      // the KEY pin (active-low)
    output pulse      // 1 for exactly one clock when the key goes down
);

    // sync1, sync2: pass the button through 2 flip-flops first, because the
    // button isn't timed to the clock and could confuse the logic otherwise
    // prev: what the button was last clock, to spot the moment it changes
    reg sync1, sync2, prev;

    always @(posedge clk) begin
        if (!resetn) begin
            sync1 <= 1'b1;    // 1 = not pressed
            sync2 <= 1'b1;
            prev  <= 1'b1;
        end
        else begin
            sync1 <= key_n;
            sync2 <= sync1;
            prev  <= sync2;
        end
    end

    // was up last clock (1), is down now (0) -> just pressed
    assign pulse = prev & ~sync2;

endmodule
