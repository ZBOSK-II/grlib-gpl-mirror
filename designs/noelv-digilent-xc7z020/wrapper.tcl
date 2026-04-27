# build zynq ps wrapper

set_property target_language VHDL [current_project]

source {zedboard_ps.tcl}

generate_target all [get_files  vivado/noelv-zedboard-xc7z020/noelv-zedboard-xc7z020.srcs/sources_1/bd/zedboard_ps/zedboard_ps.bd]
make_wrapper -files [get_files vivado/noelv-zedboard-xc7z020/noelv-zedboard-xc7z020.srcs/sources_1/bd/zedboard_ps/zedboard_ps.bd] -top
add_files -norecurse vivado/noelv-zedboard-xc7z020/noelv-zedboard-xc7z020.srcs/sources_1/bd/zedboard_ps/hdl/zedboard_ps_wrapper.vhd
update_compile_order -fileset sources_1

write_hw_platform -fixed -file zedboard_ps.xsa