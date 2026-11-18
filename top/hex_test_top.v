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
