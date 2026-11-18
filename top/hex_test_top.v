// ============================================================================
// hex_test_top: Milestone 1 board demo for signed_hex_display (Partner B)
//
// Top-level module for the DE1-SoC. Shows the 8-bit signed number set on
// switches SW[7:0] on the HEX displays, as a sign plus two hex digits:
//
//   HEX2 = minus sign if the number is negative, blank if not
//   HEX1 = high hex digit of the magnitude
//   HEX0 = low hex digit of the magnitude
//   HEX3, HEX4, HEX5 = turned off (all segments 1, since HEX is active-low)
//
// Examples:   SW[7:0] = 00000000 ->  0  ->  " 00"
//             SW[7:0] = 01111111 ->  127 ->  " 7F"
//             SW[7:0] = 11111111 -> -1   ->  "-01"
//             SW[7:0] = 10000000 -> -128 ->  "-80"
//
// The real work is done in signed_hex_display (sign, two's-complement
// magnitude) and hex_decoder (4-bit digit -> 7 segments). This file only
// connects them to the board. SW[9:8] are not used.
//
// Port names (SW, HEX0-HEX5) match the DE1-SoC pin assignment file (.qsf).
// ============================================================================

module hex_test_top (
    input  [9:0] SW,
    output [6:0] HEX0,
    output [6:0] HEX1,
    output [6:0] HEX2,
    output [6:0] HEX3,
    output [6:0] HEX4,
    output [6:0] HEX5
);

    signed_hex_display u_display (
        .value(SW[7:0]),
        .hex0(HEX0),
        .hex1(HEX1),
        .hex2(HEX2)
    );

    assign HEX3 = 7'b1111111;
    assign HEX4 = 7'b1111111;
    assign HEX5 = 7'b1111111;

endmodule
