# program_zedboard.tcl
# Program ZedBoard with NOEL-V bitstream using XSDB

puts "----------------------------------------------"
puts " Programming ZedBoard with bitstream"
puts "----------------------------------------------"

set BITFILE "./noelvmp.bit"
set PS7INIT "./vivado/noelv-zedboard-xc7z020/noelv-zedboard-xc7z020.gen/sources_1/bd/zedboard_ps/ip/zedboard_ps_processing_system7_0_0/ps7_init.tcl"

if {![file exists $BITFILE]} {
    puts "ERROR: Bitstream file '$BITFILE' not found!"
    exit
}
if {![file exists $PS7INIT]} {
    puts "ERROR: ps7_init.tcl '$PS7INIT' not found!"
    exit
}

# Load PS7 init script
source $PS7INIT

# Connect to XSDB server
connect

# Program FPGA fabric
puts "Programming FPGA with $BITFILE ..."
fpga $BITFILE


# Run initialization
puts "Running PS7 initialization..."
target 2
ps7_init
ps7_post_config

puts "Programming complete."
exit