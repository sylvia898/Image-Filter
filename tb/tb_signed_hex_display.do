# Run from the Image-Filter folder:  do tb/tb_signed_hex_display.do

vlib work
vlog "display /hex_decoder.v" "display /signed_hex_display.v" tb/tb_signed_hex_display.v
vsim -voptargs="+acc" tb_signed_hex_display

add wave -radix decimal  /tb_signed_hex_display/value
add wave -radix binary   /tb_signed_hex_display/value
add wave -radix unsigned /tb_signed_hex_display/dut/magnitude
add wave -radix binary   /tb_signed_hex_display/hex2
add wave -radix binary   /tb_signed_hex_display/hex1
add wave -radix binary   /tb_signed_hex_display/hex0

run -all
wave zoom full
