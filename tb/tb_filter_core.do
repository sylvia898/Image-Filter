# Run from the tb folder:  do tb_filter_core.do
# Results (PASS/FAIL) are printed in the transcript.

quit -sim
vlib work
vlog ../filter/kernel_table.v ../filter/filter_core.v tb_filter_core.v
vsim -voptargs="+acc" tb_filter_core

add wave                  /tb_filter_core/clk
add wave                  /tb_filter_core/resetn
add wave -radix binary    /tb_filter_core/filter_sel
add wave                  /tb_filter_core/win_start
add wave                  /tb_filter_core/pix_valid
add wave -radix unsigned  /tb_filter_core/k
add wave -radix unsigned  /tb_filter_core/pix
add wave -radix decimal   /tb_filter_core/dut/weight
add wave -radix decimal   /tb_filter_core/dut/weight_y
add wave -radix decimal   /tb_filter_core/dut/acc
add wave -radix decimal   /tb_filter_core/dut/acc_gy
add wave -radix decimal   /tb_filter_core/dut/total
add wave                  /tb_filter_core/result_valid
add wave -radix unsigned  /tb_filter_core/result

onbreak {resume}
run -all
wave zoom full
