# compile.tcl — invoke DC using read + compile
source read_design.tcl
source constraints.sdc
compile_ultra -no_autoungroup
report_area   > synth/dc/reports/area.rpt
report_timing -max_paths 10 > synth/dc/reports/timing.rpt
write -format verilog -hierarchy -output ../../results/netlist/cardinal_router_syn.v
write_sdf ../../results/netlist/cardinal_router_syn.sdf
