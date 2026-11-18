# Run from the Image-Filter folder:  do tb/tb_filter_core.do

quit -sim
vlib work
vlog filter/kernel_table.v filter/filter_core.v tb/tb_filter_core.v
vsim -voptargs="+acc" tb_filter_core

add wave                  /tb_filter_core/clk
add wave                  /tb_filter_core/resetn
add wave                  /tb_filter_core/filter_sel
add wave                  /tb_filter_core/win_start
add wave                  /tb_filter_core/pix_valid
add wave -radix unsigned  /tb_filter_core/k
add wave -radix unsigned  /tb_filter_core/pix
add wave -radix decimal   /tb_filter_core/dut/weight
add wave -radix decimal   /tb_filter_core/dut/acc
add wave                  /tb_filter_core/result_valid
add wave -radix unsigned  /tb_filter_core/result

onbreak {resume}
run -all
wave zoom full
