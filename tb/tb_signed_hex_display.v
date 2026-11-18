`timescale 1ns / 1ps

module tb_signed_hex_display;

    reg  [7:0] value;
    wire [6:0] hex0;
    wire [6:0] hex1;
    wire [6:0] hex2;

    signed_hex_display dut (
        .value(value),
        .hex0(hex0),
        .hex1(hex1),
        .hex2(hex2)
    );

    initial begin
        value = 8'd0;          #20;
        value = 8'd127;        #20;
        value = 8'b11111111;   #20;
        value = 8'b10000000;   #20;
        value = 8'b11111011;   #20;
        value = 8'd26;         #20;
        $stop;
    end

endmodule
