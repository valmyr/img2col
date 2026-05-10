
set LIB_PATH $env(HOME)/PDK/gsclib045/timing
set LEF_PATH $env(HOME)/PDK/gsclib045/lef
set LEF_PATH_IO_PAD $env(HOME)/PDK/giolib045/lef
set VR_PATH_IO_PAD $env(HOME)/PDK/giolib045/vlog/pads_SS_s1vg.v

set QRC_PATH $env(HOME)/PDK/gsclib045/qrc/qx
set_db init_lib_search_path [list $LIB_PATH $LEF_PATH $LEF_PATH_IO_PAD $QRC_PATH]
set_db init_hdl_search_path ../rtl

set_db library fast_vdd1v0_basicCells.lib
#set_db lef_library {gsclib045_tech.lef  giolib045.lef}
set_db lef_library {gsclib045_tech.lef}

set RTL "../rtl/img2col.sv" 

read_hdl -sv $RTL -top img2row




elaborate 
set_db syn_generic_effort medium
set_db syn_map_effort medium
set_db syn_opt_effort medium

syn_generic 
syn_map 
syn_opt 

#reports
report_timing > reports_genus/report_timing.rpt
report_power  > reports_genus/report_power.rpt
report_area   > reports_genus/report_area.rpt
report_qor    > reports_genus/report_qor.rpt



#Outputs
write_hdl > outputs_genus/img2col_netlist.v
write_sdc > outputs_genus/img2col.sdc
write_hdl -abstract > outputs_genus/img2col_io.v
write_sdf -timescale ns -nonegchecks -recrem split -edges check_edge  -setuphold split > outputs_genus/delays.sdf