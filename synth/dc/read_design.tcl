# read_design.tcl — point to top and filelist
set TOP cardinal_router
set FILELIST "../../tb/filelist.f"
set_app_var hdlin_sv_enable_rtl_names true
analyze -format sverilog -f $FILELIST
elaborate $TOP
link
check_design > synth/dc/reports/checkdesign.rpt
