vlib work

vlog -sv ../rtl/lifo.sv
vlog -sv lifo_tb.sv

vsim lifo_tb
add log -r /*
add wave -r *
run -all