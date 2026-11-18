// Shows an 8-bit signed number (-128..127) as a sign and 2 hex digits.
// HEX2 = minus or blank, HEX1 = high digit, HEX0 = low digit. Active-low.
module signed_hex_display (
    input [7:0] value,
    output [6:0] hex0,
    output [6:0] hex1,
    output reg [6:0] hex2
);

    // top bit is the sign bit: 1 = negative
    wire negative = value[7];

    reg [7:0] magnitude;

    always @(*) begin
        if (negative) begin
            magnitude = ~value + 8'd1;   // two's complement: flip bits, add 1
            hex2 = 7'b0111111;      // minus sign (middle segment only)
        end
        else begin
            magnitude = value;
            hex2 = 7'b1111111;      // blank
        end
    end

    // low 4 bits -> HEX0, high 4 bits -> HEX1
    hex_decoder low_digit (
        .digit(magnitude[3:0]),
        .seg(hex0)
    );

    hex_decoder high_digit (
        .digit(magnitude[7:4]),
        .seg(hex1)
    );

endmodule
