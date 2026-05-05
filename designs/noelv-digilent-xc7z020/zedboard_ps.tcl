
################################################################
# This is a generated script based on design: leon3_zedboard_stub
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2020.2
set current_vivado_version [version -short]


################################################################
# START
################################################################

set design_name zedboard_ps

# CHECKING IF PROJECT EXISTS
if { [get_projects -quiet] eq "" } {
   puts "ERROR: Please open or create a project!"
   return 1
}


# Creating design if needed
set errMsg ""
set nRet 0

set cur_design [current_bd_design -quiet]
if { ${design_name} ne "" && ${cur_design} eq ${design_name} } {
   # Checks if design is empty or not
   set list_cells [get_bd_cells -quiet]

   if { $list_cells ne "" } {
      set errMsg "ERROR: Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
      set nRet 1
   } else {
      puts "INFO: Constructing design in IPI design <$design_name>..."
   }
} else {

   if { [get_files -quiet ${design_name}.bd] eq "" } {
      puts "INFO: Currently there is no design <$design_name> in project, so creating one..."

      create_bd_design $design_name

      puts "INFO: Making design <$design_name> as current_bd_design."
      current_bd_design $design_name

   } else {
      set errMsg "ERROR: Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
      set nRet 3
   }

}

puts "INFO: Currently the variable <design_name> is equal to \"$design_name\"."

if { $nRet != 0 } {
   puts $errMsg
   return $nRet
}

##################################################################
# DESIGN PROCs
##################################################################



# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     puts "ERROR: Unable to find parent cell <$parentCell>!"
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     puts "ERROR: Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj
  # Import custom ip blocks
  set_property ip_repo_paths ../../IPs [current_project]
  update_ip_catalog

  # Create interface ports
  set DDR [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddrx_rtl:1.0 DDR ]
  set FIXED_IO [ create_bd_intf_port -mode Master -vlnv xilinx.com:display_processing_system7:fixedio_rtl:1.0 FIXED_IO ]
  set S_AXI_GP0 [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_GP0 ]
  set_property -dict [ list CONFIG.ADDR_WIDTH {32} CONFIG.ARUSER_WIDTH {0} CONFIG.AWUSER_WIDTH {0} CONFIG.BUSER_WIDTH {0} CONFIG.CLK_DOMAIN {} CONFIG.DATA_WIDTH {32} CONFIG.FREQ_HZ {40000000} CONFIG.ID_WIDTH {6} CONFIG.MAX_BURST_LENGTH {16} CONFIG.NUM_READ_OUTSTANDING {1} CONFIG.NUM_WRITE_OUTSTANDING {1} CONFIG.PHASE {0.000} CONFIG.PROTOCOL {AXI3} CONFIG.READ_WRITE_MODE {READ_WRITE} CONFIG.RUSER_WIDTH {0} CONFIG.SUPPORTS_NARROW_BURST {1} CONFIG.WUSER_WIDTH {0}  ] $S_AXI_GP0

  set AXI_Counter [create_bd_cell -type ip -vlnv xilinx.com:user:AXI_Counter:1.0 axi_counter_0] 
  # Create ports
  set FCLK_CLK0 [ create_bd_port -dir O -type clk FCLK_CLK0 ]
  set FCLK_CLK1 [ create_bd_port -dir O -type clk FCLK_CLK1 ]
  set RESETN    [ create_bd_port -dir O -type rst RESETN ]
  set COUNTER_EN [ create_bd_port -dir I COUNTER_EN ]
  set COUNTER_RSTN [ create_bd_port -dir I COUNTER_RSTN ]

  # Create instance: processing_system7_0, and set properties
  set processing_system7_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0 ]
  set_property -dict [ list CONFIG.PCW_EN_CLK1_PORT {1} CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {40.000000} CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ {200.000000} CONFIG.PCW_M_AXI_GP1_ENABLE_STATIC_REMAP {0} CONFIG.PCW_TTC0_PERIPHERAL_ENABLE {0} CONFIG.PCW_USE_M_AXI_GP0 {1} CONFIG.PCW_USE_M_AXI_GP1 {0} CONFIG.PCW_USE_S_AXI_ACP {0} CONFIG.PCW_USE_S_AXI_GP0 {1} CONFIG.PCW_USE_S_AXI_GP1 {0} CONFIG.PCW_USE_S_AXI_HP0 {0} CONFIG.preset {ZedBoard*}  ] $processing_system7_0
  
  # Connect axi counter
  # AXI interconnect
  set axi_ic [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_ic_0]
  set_property -dict [list CONFIG.NUM_MI {1} CONFIG.NUM_SI {1}] $axi_ic

  connect_bd_intf_net [get_bd_intf_pins processing_system7_0/M_AXI_GP0] \
                    [get_bd_intf_pins axi_ic_0/S00_AXI]
  
  connect_bd_intf_net [get_bd_intf_pins axi_ic_0/M00_AXI] \
                    [get_bd_intf_pins axi_counter_0/s00_axi]
  
  # Proc Sys Reset
  set rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0]
  connect_bd_net \
  [get_bd_pins processing_system7_0/FCLK_CLK0] \
  [get_bd_pins proc_sys_reset_0/slowest_sync_clk]

  connect_bd_net \
  [get_bd_pins processing_system7_0/FCLK_RESET0_N] \
  [get_bd_pins proc_sys_reset_0/ext_reset_in]
  
  # Clock/reset
  connect_bd_net \
  [get_bd_pins proc_sys_reset_0/interconnect_aresetn] \
  [get_bd_pins axi_ic_0/ARESETN]

  connect_bd_net \
  [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
  [get_bd_pins axi_counter_0/s00_axi_aresetn] \
  [get_bd_pins axi_ic_0/S00_ARESETN] \
  [get_bd_pins axi_ic_0/M00_ARESETN]

  connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] \
               [get_bd_pins axi_ic_0/ACLK] \
               [get_bd_pins axi_ic_0/S00_ACLK] \
               [get_bd_pins axi_ic_0/M00_ACLK] \
               [get_bd_pins axi_counter_0/s00_axi_aclk]


  ## connect to out ports
  connect_bd_net -net axi_counter_0_COUNTER_EN [get_bd_ports COUNTER_EN] [get_bd_pins axi_counter_0/enable_counter]
  connect_bd_net -net axi_counter_0_COUNTER_RSTN [get_bd_ports COUNTER_RSTN] [get_bd_pins axi_counter_0/resetn_counter]
  ## create axi memory mapping
  create_bd_addr_seg -range 0x10000 -offset 0x43c00000 [get_bd_addr_spaces processing_system7_0/Data] [get_bd_addr_segs axi_counter_0/s00_axi/reg0] SEG_axi_counter

  # Create interface connections
  connect_bd_intf_net -intf_net S_AXI_GP0_1 [get_bd_intf_ports S_AXI_GP0] [get_bd_intf_pins processing_system7_0/S_AXI_GP0]
  connect_bd_intf_net -intf_net processing_system7_0_DDR [get_bd_intf_ports DDR] [get_bd_intf_pins processing_system7_0/DDR]
  connect_bd_intf_net -intf_net processing_system7_0_FIXED_IO [get_bd_intf_ports FIXED_IO] [get_bd_intf_pins processing_system7_0/FIXED_IO]

  # Create port connections
  connect_bd_net -net processing_system7_0_FCLK_CLK0 [get_bd_ports FCLK_CLK0] [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins processing_system7_0/S_AXI_GP0_ACLK]
  connect_bd_net -net processing_system7_0_FCLK_CLK0 [get_bd_ports FCLK_CLK0] [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins processing_system7_0/M_AXI_GP0_ACLK]
  connect_bd_net -net processing_system7_0_FCLK_CLK1 [get_bd_ports FCLK_CLK1] [get_bd_pins processing_system7_0/FCLK_CLK1]
  connect_bd_net -net proc_sys_reset_0_peripheral_aresetn [get_bd_ports RESETN] [get_bd_pins proc_sys_reset_0/peripheral_aresetn]

  # Create address segments
  create_bd_addr_seg -range 0x20000000 -offset 0x0 [get_bd_addr_spaces S_AXI_GP0] [get_bd_addr_segs processing_system7_0/S_AXI_GP0/GP0_DDR_LOWOCM] SEG_processing_system7_0_GP0_DDR_LOWOCM
  create_bd_addr_seg -range 0x400000 -offset 0xE0000000 [get_bd_addr_spaces S_AXI_GP0] [get_bd_addr_segs processing_system7_0/S_AXI_GP0/GP0_IOP] SEG_processing_system7_0_GP0_IOP
  create_bd_addr_seg -range 0x1000000 -offset 0xFC000000 [get_bd_addr_spaces S_AXI_GP0] [get_bd_addr_segs processing_system7_0/S_AXI_GP0/GP0_QSPI_LINEAR] SEG_processing_system7_0_GP0_QSPI_LINEAR
  

  # Restore current instance
  current_bd_instance $oldCurInst

  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""


