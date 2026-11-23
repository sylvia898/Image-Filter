# Run from the tb folder:  do tb_weight_entry.do
# Results (PASS/FAIL) are printed in the transcript.

quit -sim
vlib work
vlog ../custom/weight_entry.v tb_weight_entry.v
vsim -voptargs="+acc" tb_weight_entry

add wave                  /tb_weight_entry/clk
add wave                  /tb_weight_entry/resetn
add wave                  /tb_weight_entry/key1_n
add wave                  /tb_weight_entry/start_pulse
add wave                  /tb_weight_entry/key_valid
add wave -radix unsigned  /tb_weight_entry/key_value
add wave -radix unsigned  /tb_weight_entry/dut/state
add wave -radix unsigned  /tb_weight_entry/dut/number
add wave                  /tb_weight_entry/dut/is_negative
add wave -radix decimal   /tb_weight_entry/signed_number
add wave                  /tb_weight_entry/dut/in_range
add wave -radix unsigned  /tb_weight_entry/entry
add wave                  /tb_weight_entry/weights_changed
add wave -radix unsigned  /tb_weight_entry/k
add wave -radix decimal   /tb_weight_entry/weight
add wave -radix unsigned  /tb_weight_entry/shift

onbreak {resume}
run -all
wave zoom full
