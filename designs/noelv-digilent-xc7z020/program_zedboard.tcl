# program_zedboard.tcl
# Program ZedBoard with NOEL-V bitstream using XSDB

puts "----------------------------------------------"
puts " Programming ZedBoard with bitstream"
puts "----------------------------------------------"

set BITFILE "./noelvmp.bit"
set PS7INIT "/home/mivashch/PW/Dyploma/bitstreams/ps7_init_40MHz.tcl"

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