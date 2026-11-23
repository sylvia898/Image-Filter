// weight_entry: fsm for user to input their custom weights with the keyboard

module weight_entry (
    input clk,
    input resetn,                 
    input start,                 
    input key_valid,              // from keyboard decoder: 1 for one clock per key press
    input [3:0] key_value,        // from keyboard decoder: 0..9 digit, 10 minus, 11 Enter
    input [3:0] k,                // from filter_core: which weight it wants right now
    output signed [7:0] weight,  
    output [3:0] shift,           
    output reg [3:0] entry,       // which entry is being typed: 0..8 weights, 9 shift
    output signed [7:0] typed,    // the number typed so far (for the display)
    output reg weights_changed    // 1 for one clock when the new kernel goes live
);

    // FSM states 
    parameter S_IDLE = 3'b000; // waiting to start 
    parameter S_TYPING = 3'b001; // building the number for weights
    parameter S_STORE = 3'b010; // enter pressed, check range and save for new kernel
    parameter S_NEXT = 3'b011; // move on to next nmber
    parameter S_DONE = 3'b100; // all 10 entered (9 weights + 1 shift), kernel becomes active kernel 

    // key_value meanings (agreed with the keyboard decoder)
    // 0..9 are the digits themselves
    parameter KEY_MINUS = 4'd10;
    parameter KEY_ENTER = 4'd11;

    reg [2:0] state, next_state;

    reg [9:0] number; // number up to 3 digits
    reg is_negative; // if - typed, it is 1

    reg signed [7:0] new_kernel [0:9]; // user typing in values 
    reg signed [7:0] active_kernel [0:9]; // filter uses

    // ------------------ check range ------------------------------------
    // weights (entries 0 to 8) & shift (entry 9)

    reg in_range; 

    always @(*) begin
        if (entry == 4'd9) 
            in range = !isnegative && (number <= 10'd15);
        else if (is_negative)   
            in_range = (number <= 10'd128); // max - # is 128
        else 
            in_range = (number <= 10'd127) // max # 127
    end 

    // if negative number, put - sign back

    always @(*) begin 
        if (is_negative) 
            signed_number = 8'd0 - number[7:0]; // 0 - 125 = -125
        else 
            signed_number = number[7:0]; // stays 125
    end


     // ---------------- next state -------------------------------

    always @(*) begin 
        next_state = state; 

        case (state) 
            S_IDLE: 
            begin 
                if (start) 
                    next_state = S_TYPING; 
            end 

            S_TYPING: 
            begin 
                if (key_valid && key_value == KEY_ENTER) 
                    next_state = S_STORE; 
            end 

            S_STORE: 
            begin 
                if (in_range) 
                    next_state = S_NEXT;
                else 
                    next_state = S_TYPING; // if not in range, user has to retype value
            end

            S_NEXT: 
            begin 
                if (entry < 4'd9) // checks if typed all entries needed
                    next_state = S_TYPING; 
                else
                    next_state = S_DONE; 
            end 

            S_DONE: 
            begin 
                next_state = S_IDLE; 
            end 
            default: next_state = S_IDLE; 
        endcase
    end


    // ---------------- block 2: registers ---------------------------------

    integer index; // loop counter (0 to 9) for 10 kernel entries, reset clears them
    // DONE copies new_kernel -> active_kernel

    always @(posedge clk) begin 
        if (!resetn) begin 
            state <= S_IDLE; 
            entry <= 4'd0; // 4 bits (0 to 9)
            number <= 10'd0; 
            is_negative <= 1'b0; // 1 bit, starts as +
            weights_changed <= 1'b0; 

            // every custom filter starts as identity so image not all black 

            // sets all 10 slots as 0
            for (index = 0; index < 10; index = index + 1) begin 
                active_kernel[index] <= 8'sd0; 
                new_kernel[index] <= 8'sd0;
            end 
            active_kernel[4] <= 8'sd1; // sets centre as 1
            new_kernel[4] <= 8'sd1; // sets centre as 1
        end 

        else begin 
            state <= next_state; 
            weights_changed <= 1'b0; 

            case (state) 
                S_IDLE: begin 
                    if (start) begin 
                        entry <= 4'd0; 
                        number <= 10'd0; 
                        is_negative <= 1'b0; 
                    end
                end

                S_TYPING: begin 
                    if (key_value <= 4'd9) begin // which digit key pressed
                       // ex. 125 becomes 12 x 10 = 120 and then + 5 = 125
                        if (number < 10'd100)
                            number <= number * 10'd10 + key_value;
                        end

                        else if (key_value == KEY_MINUS) // if - key pressed
                            is_negative <= 1'b1; 
                    end 
                end

                S_STORE: begin 
                    if (in_range) 
                        new_kernel[entry] <= signed_number ;
                    else begin 
                        number <= 10'd0; // throw it away, type again 
                        is_negative <= 1'b0; 
                    end
                
                // goes to next entry and clears typed number so start fresh
                S_NEXT: begin 
                    entry <= entry + 4'd1; 
                    number <= 10'd0; 
                    is_negative <= 1'b0; 
                end

                S_DONE: begin 
                for (index = 0; index < 10; index = index + 1) 
                    active_kernel[index] <= new_kernel[index]; // active kernel is now the new kernel (custom weights)
                    weights_changed <= 1'b1; 
                end

                default: ; // do nothing

            endcase
        end
    end

    // look up the weight filter_core is asking for 
    // every clock, filter_core asks what weight for square k is and weight_entry passes weight

    always @(*) begin 
        if (k <= 4'd8) 
            weight = active_kernel[k]; // squares 0 to 8
        else 
            weight = 8'sd0; // everything else is 0 
    end 
    
    // reads shift out of active_kernel and passes it to filter
    assign shift = active_kernel[9][3:0]; // 9 grabs shift, 3:0 is shift
endmodule 