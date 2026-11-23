# Run from the tb folder:  do tb_filter_core_rgb.do
# Results (PASS/FAIL) are printed in the transcript.

quit -sim
vlib work
vlog ../filter/kernel_table.v ../filter/filter_core.v ../filter/filter_core_rgb.v tb_filter_core_rgb.v
vsim -voptargs="+acc" tb_filter_core_rgb

add wave                  /tb_filter_core_rgb/clk
add wave                  /tb_filter_core_rgb/resetn
add wave -radix binary    /tb_filter_core_rgb/filter_sel
add wave                  /tb_filter_core_rgb/win_start
add wave                  /tb_filter_core_rgb/pix_valid
add wave -radix unsigned  /tb_filter_core_rgb/k
add wave -radix hex       /tb_filter_core_rgb/pix
add wave -radix unsigned  /tb_filter_core_rgb/dut/red_out
add wave -radix unsigned  /tb_filter_core_rgb/dut/green_out
add wave -radix unsigned  /tb_filter_core_rgb/dut/blue_out
add wave                  /tb_filter_core_rgb/result_valid
add wave -radix hex       /tb_filter_core_rgb/result

onbreak {resume}
run -all
wave zoom full
