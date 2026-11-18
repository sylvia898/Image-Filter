// sw 00: filter identity: copies centre pixel so image looks unchanegd
// switch 00 identity: The original picture, exactly as stored in ROM. It's your baseline: if this looks wrong, the problem is in the ROM, VGA or address logic, not your filter.
// switch 01 blur: The same picture, slightly softer and fuzzier. Sharp edges become gradual, fine detail and specks are smoothed out, and flat areas look the same. A 3×3 blur is fairly gentle, so flip between 00 and 01 to compare.

// kernel_table: combinational lookup (no clock)
// for selected filter and neighbour k, gives weight to multiply that neighbour by, and shift to apply to final sum 

module kernel_table (
    input             [1:0] filter_select, // SW[1:0]: 00 identity, 01 blur, 10 Sobel (M2), 11 custom (M2)
    input             [3:0] k,          // neighbour index 0..8
    output reg signed [7:0] weight,     // signed weight for neighbour k
    output reg        [3:0] shift       // arithmetic right shift for the sum
);

    always @(*) begin
        // Defaults: anything not listed below gets weight 0, shift 0.
        // Setting every output first also prevents latches.
        weight = 8'sd0;
        shift  = 4'd0;

        case (filter_sel)
            // Identity: 0 0 0 / 0 1 0 / 0 0 0, weights sum to 1 -> shift 0
            2'b00: begin
                shift = 4'd0;
                if (k == 4'd4)
                    weight = 8'sd1;
            end

            // Blur: 1 2 1 / 2 4 2 / 1 2 1, weights sum to 16 = 2^4 -> shift 4
            2'b01: begin
                shift = 4'd4;
                case (k)
                    4'd0, 4'd2, 4'd6, 4'd8: weight = 8'sd1; // corners
                    4'd1, 4'd3, 4'd5, 4'd7: weight = 8'sd2; // edges
                    4'd4:                   weight = 8'sd4; // centre
                    default:                weight = 8'sd0; // k = 9..15 unused
                endcase
            end

            // 2'b10 Sobel and 2'b11 custom: Milestone 2 (defaults for now)
            default: ;
        endcase
    end

endmodule
