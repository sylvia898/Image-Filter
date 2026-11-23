module kernel_table (
    input [2:0] filter_select, // SW[2:0]: 000 identity, 001 blur, 010 Sobel (M2), 011 sharpen (M2), 100 custom (M2)
    input [3:0] k,
    input signed [7:0] custom_weight, // from weight_entry: user's weight for square k
    input [3:0] custom_shift,         // from weight_entry: user's shift
    output reg signed [7:0] weight,   // normal weight for filters & Gx
    output reg signed [7:0] weight_y, // Gy, only for Sobel
    output reg [3:0] shift       // arithmetic right shift for the sum
);

    always @(*) begin
        weight = 8'sd0;
        weight_y = 8'sd0;
        shift  = 4'd0;

        case (filter_select)
            // Identity: 0 0 0 / 0 1 0 / 0 0 0, weights sum to 1 -> shift 0
            3'b000: begin
                shift = 4'd0;
                if (k == 4'd4)
                    weight = 8'sd1;
            end

            // Blur: 1 2 1 / 2 4 2 / 1 2 1, weights sum to 16 = 2^4 -> shift 4
            3'b001: begin
                shift = 4'd4; // shifts right by 4 bits which means divide by 16
                case (k)
                    4'd0, 4'd2, 4'd6, 4'd8: weight = 8'sd1; // corners
                    4'd1, 4'd3, 4'd5, 4'd7: weight = 8'sd2; // edges
                    4'd4:                   weight = 8'sd4; // centre
                    default:                weight = 8'sd0; // k = 9..15 unused
                endcase
            end

            // Sobel: has gx and gy
            3'b010: begin 
                shift = 4'd0; // bc sobel weights add up to 0 so nothing scaled up
                case (k) // Gx: -1 0 1 / -2 0 2 / -1 0 1
                    4'd0, 4'd6: weight = -8'sd1; 
                    4'd3: weight = -8'sd2; 
                    4'd2, 4'd8: weight = 8'sd1; 
                    4'd5: weight = 8'sd2; 
                    default: weight = 8'sd0; // middle column unused
                endcase
                case(k) // Gy: 1 2 1 / 0 0 0 / -1 -2 -1
                    4'd0, 4'd2: weight_y = 8'sd1; 
                    4'd1: weight_y = 8'sd2; 
                    4'd6, 4'd8: weight_y = -8'sd1; 
                    4'd7: weight_y = -8'sd2;
                    default: weight_y = 8'sd0; 
                endcase
            end

            // Sharpen: 0 -1 0 / -1 5 -1 / 0 -1 0, weights sum to 1 -> shift 0
            3'b011: begin 
                shift = 4'd0;
                case (k)
                    4'd1, 4'd3, 4'd5, 4'd7: weight = -8'sd1;
                    4'd4: weight = 8'sd5; 
                    default: weight = 8'sd0; 
                endcase
            end

            // Custom: whatever the user entered (stored in weight_entry)
            3'b100: 
            begin
                weight = custom_weight;
                shift  = custom_shift;
            end

            default: ;
        endcase
    end

endmodule
