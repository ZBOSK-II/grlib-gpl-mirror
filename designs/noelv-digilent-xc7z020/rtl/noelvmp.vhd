------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2014, Aeroflex Gaisler
--  Copyright (C) 2015 - 2023, Cobham Gaisler
--  Copyright (C) 2023 - 2025, Frontgrade Gaisler
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; version 2.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program; if not, write to the Free Software
--  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA 

library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
use grlib.config.all;
use grlib.config_types.all;

library techmap;
use techmap.gencomp.all;

library gaisler;
use gaisler.leon3.all;
use gaisler.uart.all;
use gaisler.misc.all;
use gaisler.net.all;
use gaisler.jtag.all;
use gaisler.axi.all;
use gaisler.plic.all;
use gaisler.l2cache.all;
use gaisler.noelv.all;

--pragma translate_off
use gaisler.sim.all;
--pragma translate_on

use work.config.all;
use work.config_local.all;
use work.rev.REVISION;
use work.cfgmap.all;

entity noelvmp is
  generic (
    fabtech                 : integer := CFG_FABTECH;
    memtech                 : integer := CFG_MEMTECH;
    padtech                 : integer := CFG_PADTECH;
    clktech                 : integer := CFG_CLKTECH;
    disas                   : integer := CFG_DISAS;     -- Enable disassembly to console
    SIMULATION              : integer := 0
    -- pragma translate_off 
    ; ramfile               : string  := "ram.srec"
    ; romfile               : string  := "prom.srec"
    -- pragma translate_on
    );
  port (
    -- LEDs. 0: off, 1: on
    led                : out   std_logic_vector(7 downto 0);
    -- Buttons 0: not pressed, 1: pressed
    btn                : in    std_logic_vector(3 downto 0);
    -- Switches
    sw                 : in    std_logic_vector(3 downto 0);
    -- PMOD-JB
    pmod_jb            : inout std_logic_vector(7 downto 0);
    -- PMOD-JC
    pmod_jc            : in std_logic_vector(1 downto 0);
    -- PMOD-JA
    ja                 : inout std_logic_vector(7 downto 0);
    -- USB-RS232 interface
    uart_txd_in        : in    std_ulogic;
    uart_rxd_out       : out   std_ulogic;
    -- MIO
    ps_mio            : inout std_logic_vector(53 downto 0);
    ps_srstb          : inout std_logic;
    ps_porb           : inout std_logic;
    ps_clk            : inout std_logic;
    -- DDR3
    ddr3_clk          : inout std_logic;
    ddr3_clk_n        : inout std_logic;
    ddr3_dq           : inout std_logic_vector(31 downto 0);
    ddr3_dqs_p        : inout std_logic_vector(3 downto 0);
    ddr3_dqs_n        : inout std_logic_vector(3 downto 0);
    ddr3_addr         : inout   std_logic_vector(14 downto 0);
    ddr3_ba           : inout   std_logic_vector(2 downto 0);
    ddr3_ras_n        : inout   std_logic;
    ddr3_cas_n        : inout   std_logic;
    ddr3_we_n         : inout   std_logic;
    ddr3_reset_n      : inout   std_logic;
    ddr3_ck_p         : inout   std_logic;
    ddr3_ck_n         : inout   std_logic;
    ddr3_cke          : inout   std_logic;
    ddr3_cs_n         : inout   std_logic;
    ddr3_dm           : inout   std_logic_vector(3 downto 0);
    ddr3_odt          : inout   std_logic;

    ddr3_vrn          : inout std_logic;
    ddr3_vrp          : inout std_logic
  );
end;

architecture rtl of noelvmp is
  -- TODO: move out to separate file
  -- Zedboard processing system stub
  component zedboard_ps
    port (
    DDR_addr : inout STD_LOGIC_VECTOR ( 14 downto 0 );
    DDR_ba : inout STD_LOGIC_VECTOR ( 2 downto 0 );
    DDR_cas_n : inout STD_LOGIC;
    DDR_ck_n : inout STD_LOGIC;
    DDR_ck_p : inout STD_LOGIC;
    DDR_cke : inout STD_LOGIC;
    DDR_cs_n : inout STD_LOGIC;
    DDR_dm : inout STD_LOGIC_VECTOR ( 3 downto 0 );
    DDR_dq : inout STD_LOGIC_VECTOR ( 31 downto 0 );
    DDR_dqs_n : inout STD_LOGIC_VECTOR ( 3 downto 0 );
    DDR_dqs_p : inout STD_LOGIC_VECTOR ( 3 downto 0 );
    DDR_odt : inout STD_LOGIC;
    DDR_ras_n : inout STD_LOGIC;
    DDR_reset_n : inout STD_LOGIC;
    DDR_we_n : inout STD_LOGIC;
    FCLK_CLK0 : out STD_LOGIC;
    FCLK_CLK1 : out STD_LOGIC;
    COUNTER_EN : in STD_LOGIC;
    COUNTER_RSTN : in STD_LOGIC;
    RESETN : out STD_LOGIC;
    FIXED_IO_ddr_vrn : inout STD_LOGIC;
    FIXED_IO_ddr_vrp : inout STD_LOGIC;
    FIXED_IO_mio : inout STD_LOGIC_VECTOR ( 53 downto 0 );
    FIXED_IO_ps_clk : inout STD_LOGIC;
    FIXED_IO_ps_porb : inout STD_LOGIC;
    FIXED_IO_ps_srstb : inout STD_LOGIC;
    S_AXI_GP0_araddr : in STD_LOGIC_VECTOR ( 31 downto 0 );
    S_AXI_GP0_arburst : in STD_LOGIC_VECTOR ( 1 downto 0 );
    S_AXI_GP0_arcache : in STD_LOGIC_VECTOR ( 3 downto 0 );
    S_AXI_GP0_arid : in STD_LOGIC_VECTOR ( 5 downto 0 ); --
    S_AXI_GP0_arlen : in STD_LOGIC_VECTOR ( 3 downto 0 );
    S_AXI_GP0_arlock : in STD_LOGIC_VECTOR ( 1 downto 0 ); --
    S_AXI_GP0_arprot : in STD_LOGIC_VECTOR ( 2 downto 0 );
    S_AXI_GP0_arqos : in STD_LOGIC_VECTOR ( 3 downto 0 );  --
    S_AXI_GP0_arready : out STD_LOGIC;
    S_AXI_GP0_arsize : in STD_LOGIC_VECTOR ( 2 downto 0 );
    S_AXI_GP0_arvalid : in STD_LOGIC;
    S_AXI_GP0_awaddr : in STD_LOGIC_VECTOR ( 31 downto 0 );
    S_AXI_GP0_awburst : in STD_LOGIC_VECTOR ( 1 downto 0 );
    S_AXI_GP0_awcache : in STD_LOGIC_VECTOR ( 3 downto 0 );
    S_AXI_GP0_awid : in STD_LOGIC_VECTOR ( 5 downto 0 );  --
    S_AXI_GP0_awlen : in STD_LOGIC_VECTOR ( 3 downto 0 );
    S_AXI_GP0_awlock : in STD_LOGIC_VECTOR ( 1 downto 0 ); --
    S_AXI_GP0_awprot : in STD_LOGIC_VECTOR ( 2 downto 0 );
    S_AXI_GP0_awqos : in STD_LOGIC_VECTOR ( 3 downto 0 );  --
    S_AXI_GP0_awready : out STD_LOGIC;
    S_AXI_GP0_awsize : in STD_LOGIC_VECTOR ( 2 downto 0 );
    S_AXI_GP0_awvalid : in STD_LOGIC;
    S_AXI_GP0_bid : out STD_LOGIC_VECTOR ( 5 downto 0 );  --
    S_AXI_GP0_bready : in STD_LOGIC;
    S_AXI_GP0_bresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
    S_AXI_GP0_bvalid : out STD_LOGIC;
    S_AXI_GP0_rdata : out STD_LOGIC_VECTOR ( 31 downto 0 );
    S_AXI_GP0_rid : out STD_LOGIC_VECTOR ( 5 downto 0 );  --
    S_AXI_GP0_rlast : out STD_LOGIC;
    S_AXI_GP0_rready : in STD_LOGIC;
    S_AXI_GP0_rresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
    S_AXI_GP0_rvalid : out STD_LOGIC;
    S_AXI_GP0_wdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    S_AXI_GP0_wid : in STD_LOGIC_VECTOR ( 5 downto 0 );  --
    S_AXI_GP0_wlast : in STD_LOGIC;
    S_AXI_GP0_wready : out STD_LOGIC;
    S_AXI_GP0_wstrb : in STD_LOGIC_VECTOR ( 3 downto 0 );
    S_AXI_GP0_wvalid : in STD_LOGIC
    );
  end component;

  constant BOARD_FREQ : integer := 40000;  -- CLK input frequency in KHz
  -- cpu frequency in KHz
  constant CPU_FREQ : integer := BOARD_FREQ * CFG_CLKMUL / CFG_CLKDIV;

  constant OEPOL  : integer := padoen_polarity(padtech);
  constant oeon   : std_logic := conv_std_logic_vector(OEPOL,1)(0);
  constant oeoff  : std_logic := not conv_std_logic_vector(OEPOL,1)(0);

  -------------------------------------
  -- Misc
  signal vcc            : std_ulogic;
  signal gnd            : std_ulogic;
  signal stati          : ahbstat_in_type;

  signal counter_en     : std_logic;
  signal counter_rstn   : std_logic;
  -- Clock & Reset
  signal rstn           : std_ulogic;
  signal resetn         : std_ulogic;
  signal lock           : std_logic;
  signal clkm           : std_ulogic
  -- pragma translate_off 
  := '0'
  -- pragma translate_on
  ;

  -- UART
  signal dsu_sel        : std_ulogic;
  signal uart_rx    : std_logic_vector(0 downto 0);
  signal uart_ctsn  : std_logic_vector(0 downto 0);
  signal uart_tx    : std_logic_vector(0 downto 0);
  signal uart_rtsn  : std_logic_vector(0 downto 0);
  signal duart_rx   : std_ulogic;
  signal duart_tx   : std_ulogic;
  -- GPIO
  signal gpio_i         : std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0);
  signal gpio_o         : std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0);
  signal gpio_oe        : std_logic_vector(CFG_GRGPIO_WIDTH-1 downto 0);
  -- JTAG
  signal tck, tms, tdi, tdo : std_ulogic;
  -- RISC-V JTAG
  signal jtag_rv_tck    : std_ulogic := '0';
  signal jtag_rv_tms    : std_ulogic := '0';
  signal jtag_rv_tdi    : std_ulogic := '0';
  signal jtag_rv_tdo    : std_ulogic;
  -- Ethernet
  signal ethi : eth_in_type;
  signal etho : eth_out_type;

  -- Memory
  signal mem_aximi      : axi_somi_type;
  signal mem_aximo      : axi_mosi_type;

  signal mem_apbi       : apb_slv_in_type;
  signal mem_apbo       : apb_slv_out_type;
  signal mem_ahbsi      : ahb_slv_in_type;
  signal mem_ahbso      : ahb_slv_out_type;
  signal rom_ahbsi      : ahb_slv_in_type;
  signal rom_ahbso      : ahb_slv_out_type;

  signal uart_rx_int    : std_ulogic; 
  signal uart_tx_int    : std_ulogic; 
  signal uart_ctsn_int  : std_ulogic;
  signal uart_rtsn_int  : std_ulogic;

  signal dmen           : std_logic;
  signal dmbreak        : std_logic;
  signal dmreset        : std_logic;
  signal cpu0errn       : std_logic;

  -- Internal signals for AXI GP0 interface
  signal S_AXI_GP0_araddr   : std_logic_vector(31 downto 0);
  signal S_AXI_GP0_arburst  : std_logic_vector(1 downto 0);
  signal S_AXI_GP0_arcache  : std_logic_vector(3 downto 0);
  signal S_AXI_GP0_arid     : std_logic_vector(5 downto 0);
  signal S_AXI_GP0_arlen    : std_logic_vector(3 downto 0);
  signal S_AXI_GP0_arlock   : std_logic_vector(1 downto 0);
  signal S_AXI_GP0_arprot   : std_logic_vector(2 downto 0);
  signal S_AXI_GP0_arqos    : std_logic_vector(3 downto 0);
  signal S_AXI_GP0_arready  : std_logic;
  signal S_AXI_GP0_arsize   : std_logic_vector(2 downto 0);
  signal S_AXI_GP0_arvalid  : std_logic;
  
  signal S_AXI_GP0_awaddr   : std_logic_vector(31 downto 0);
  signal S_AXI_GP0_awburst  : std_logic_vector(1 downto 0);
  signal S_AXI_GP0_awcache  : std_logic_vector(3 downto 0);
  signal S_AXI_GP0_awid     : std_logic_vector(5 downto 0);
  signal S_AXI_GP0_awlen    : std_logic_vector(3 downto 0);
  signal S_AXI_GP0_awlock   : std_logic_vector(1 downto 0);
  signal S_AXI_GP0_awprot   : std_logic_vector(2 downto 0);
  signal S_AXI_GP0_awqos    : std_logic_vector(3 downto 0);
  signal S_AXI_GP0_awready  : std_logic;
  signal S_AXI_GP0_awsize   : std_logic_vector(2 downto 0);
  signal S_AXI_GP0_awvalid  : std_logic;
  
  signal S_AXI_GP0_bid      : std_logic_vector(5 downto 0);
  signal S_AXI_GP0_bready   : std_logic;
  signal S_AXI_GP0_bresp    : std_logic_vector(1 downto 0);
  signal S_AXI_GP0_bvalid   : std_logic;
  
  signal S_AXI_GP0_rdata    : std_logic_vector(31 downto 0);
  signal S_AXI_GP0_rid      : std_logic_vector(5 downto 0);
  signal S_AXI_GP0_rlast    : std_logic;
  signal S_AXI_GP0_rready   : std_logic;
  signal S_AXI_GP0_rresp    : std_logic_vector(1 downto 0);
  signal S_AXI_GP0_rvalid   : std_logic;
  
  signal S_AXI_GP0_wdata    : std_logic_vector(31 downto 0);
  signal S_AXI_GP0_wid      : std_logic_vector(5 downto 0);
  signal S_AXI_GP0_wlast    : std_logic;
  signal S_AXI_GP0_wready   : std_logic;
  signal S_AXI_GP0_wstrb    : std_logic_vector(3 downto 0);
  signal S_AXI_GP0_wvalid   : std_logic;

begin

  ----------------------------------------------------------------------
  ---  Reset and Clock generation  -------------------------------------
  ----------------------------------------------------------------------
  vcc         <= '1';
  gnd         <= '0';
  lock        <= '1';

  ----------------------------------------------------------------------
  ---  Zedboard PS -----------------------------------------------------
  ----------------------------------------------------------------------

  zedboard_ps_stub_i : zedboard_ps
    port map (
      DDR_ck_p                      => ddr3_clk,
      DDR_ck_n                      => ddr3_clk_n,
      DDR_cke                       => ddr3_cke,
      DDR_cs_n                      => ddr3_cs_n,
      DDR_ras_n                     => ddr3_ras_n,
      DDR_cas_n                     => ddr3_cas_n,
      DDR_we_n                      => ddr3_we_n,
      DDR_ba                        => ddr3_ba,
      DDR_addr                      => ddr3_addr,
      DDR_odt                       => ddr3_odt,
      DDR_reset_n                   => ddr3_reset_n,
      DDR_dq                        => ddr3_dq,
      DDR_dm                        => ddr3_dm,
      DDR_dqs_p                     => ddr3_dqs_p,
      DDR_dqs_n                     => ddr3_dqs_n,
      FCLK_CLK0                     => clkm,
      RESETN                         => resetn,
      COUNTER_EN                    => counter_en,
      COUNTER_RSTN                  => counter_rstn,
      FIXED_IO_mio                  => ps_mio,
      FIXED_IO_ps_srstb             => ps_srstb,
      FIXED_IO_ps_clk               => ps_clk,
      FIXED_IO_ps_porb              => ps_porb,
      FIXED_IO_ddr_vrn              => ddr3_vrn,
      FIXED_IO_ddr_vrp              => ddr3_vrp,
      S_AXI_GP0_araddr              => S_AXI_GP0_araddr,
      S_AXI_GP0_arburst(1 downto 0) => S_AXI_GP0_arburst(1 downto 0),
      S_AXI_GP0_arcache(3 downto 0) => S_AXI_GP0_arcache(3 downto 0),
      S_AXI_GP0_arid                => S_AXI_GP0_arid,
      S_AXI_GP0_arlen               => S_AXI_GP0_arlen,
      S_AXI_GP0_arlock              => S_AXI_GP0_arlock,
      S_AXI_GP0_arprot(2 downto 0)  => S_AXI_GP0_arprot(2 downto 0),
      S_AXI_GP0_arqos               => S_AXI_GP0_arqos,
      S_AXI_GP0_awqos               => S_AXI_GP0_awqos,
      S_AXI_GP0_arready             => S_AXI_GP0_arready,
      S_AXI_GP0_arsize(2 downto 0)  => S_AXI_GP0_arsize(2 downto 0),
      S_AXI_GP0_arvalid             => S_AXI_GP0_arvalid,
      S_AXI_GP0_awaddr              => S_AXI_GP0_awaddr,
      S_AXI_GP0_awburst(1 downto 0) => S_AXI_GP0_awburst(1 downto 0),
      S_AXI_GP0_awcache(3 downto 0) => S_AXI_GP0_awcache(3 downto 0),
      S_AXI_GP0_awid                => S_AXI_GP0_awid,
      S_AXI_GP0_awlen               => S_AXI_GP0_awlen,
      S_AXI_GP0_awlock              => S_AXI_GP0_awlock,
      S_AXI_GP0_awprot(2 downto 0)  => S_AXI_GP0_awprot(2 downto 0),
      S_AXI_GP0_awready             => S_AXI_GP0_awready,
      S_AXI_GP0_awsize(2 downto 0)  => S_AXI_GP0_awsize(2 downto 0),
      S_AXI_GP0_awvalid             => S_AXI_GP0_awvalid,
      S_AXI_GP0_bid                 => S_AXI_GP0_bid,
      S_AXI_GP0_bready              => S_AXI_GP0_bready,
      S_AXI_GP0_bresp(1 downto 0)   => S_AXI_GP0_bresp(1 downto 0),
      S_AXI_GP0_bvalid              => S_AXI_GP0_bvalid,
      S_AXI_GP0_rdata(31 downto 0)  => S_AXI_GP0_rdata(31 downto 0),
      S_AXI_GP0_rid                 => S_AXI_GP0_rid,
      S_AXI_GP0_rlast               => S_AXI_GP0_rlast,
      S_AXI_GP0_rready              => S_AXI_GP0_rready,
      S_AXI_GP0_rresp(1 downto 0)   => S_AXI_GP0_rresp(1 downto 0),
      S_AXI_GP0_rvalid              => S_AXI_GP0_rvalid,
      S_AXI_GP0_wdata(31 downto 0)  => S_AXI_GP0_wdata(31 downto 0),
      S_AXI_GP0_wid                 => S_AXI_GP0_wid,
      S_AXI_GP0_wlast               => S_AXI_GP0_wlast,
      S_AXI_GP0_wready              => S_AXI_GP0_wready,
      S_AXI_GP0_wstrb(3 downto 0)   => S_AXI_GP0_wstrb(3 downto 0),
      S_AXI_GP0_wvalid              => S_AXI_GP0_wvalid
  );
  
  -- Connect NOEL-V AXI MEM to Zynq PS S AXI GP0

  S_AXI_GP0_araddr    <= "0001"&mem_aximo.ar.addr(27 downto 0);
  S_AXI_GP0_arburst   <= mem_aximo.ar.burst;
  S_AXI_GP0_arcache   <= mem_aximo.ar.cache;
  S_AXI_GP0_arid      <= "00" & mem_aximo.ar.id;
  S_AXI_GP0_arlen     <= mem_aximo.ar.len;
  S_AXI_GP0_arlock    <= mem_aximo.ar.lock;
  S_AXI_GP0_arprot    <= mem_aximo.ar.prot;
  S_AXI_GP0_arqos     <= (others=>'0');
  S_AXI_GP0_arsize    <= mem_aximo.ar.size;
  S_AXI_GP0_arvalid   <= mem_aximo.ar.valid;
  mem_aximi.ar.ready  <= S_AXI_GP0_arready;

  S_AXI_GP0_awaddr    <= "0001"&mem_aximo.aw.addr(27 downto 0);
  S_AXI_GP0_awburst   <= mem_aximo.aw.burst;
  S_AXI_GP0_awcache   <= mem_aximo.aw.cache;
  S_AXI_GP0_awid      <= "00" & mem_aximo.aw.id;
  S_AXI_GP0_awlen     <= mem_aximo.aw.len;
  S_AXI_GP0_awlock    <= mem_aximo.aw.lock;
  S_AXI_GP0_awprot    <= mem_aximo.aw.prot;
  S_AXI_GP0_awqos     <= (others => '0');
  S_AXI_GP0_awsize    <= mem_aximo.aw.size;
  S_AXI_GP0_awvalid   <= mem_aximo.aw.valid;
  mem_aximi.aw.ready  <=  S_AXI_GP0_awready;

  mem_aximi.b.id    <= S_AXI_GP0_bid(3 downto 0);                   
  S_AXI_GP0_bready  <= mem_aximo.b.ready;
  mem_aximi.b.resp  <=  S_AXI_GP0_bresp;
  mem_aximi.b.valid <=  S_AXI_GP0_bvalid;
  
  mem_aximi.r.data  <= S_AXI_GP0_rdata;
  mem_aximi.r.id    <= S_AXI_GP0_rid(3 downto 0);
  mem_aximi.r.last  <= S_AXI_GP0_rlast;
  S_AXI_GP0_rready  <= mem_aximo.r.ready;
  mem_aximi.r.resp  <= S_AXI_GP0_rresp;
  mem_aximi.r.valid <= S_AXI_GP0_rvalid;

  S_AXI_GP0_wdata   <= mem_aximo.w.data;
  S_AXI_GP0_wlast   <= mem_aximo.w.last;
  mem_aximi.w.ready <= S_AXI_GP0_wready;
  S_AXI_GP0_wstrb   <= mem_aximo.w.strb;
  S_AXI_GP0_wvalid  <= mem_aximo.w.valid;
  S_AXI_GP0_wid     <= "00" & mem_aximo.w.id;

  ----------------------------------------------------------------------
  ---  NOEL-V SUBSYSTEM ------------------------------------------------
  ----------------------------------------------------------------------

  core0 : entity work.noelvcore
  generic map (
    fabtech     => CFG_FABTECH,
    memtech     => CFG_MEMTECH,
    padtech     => CFG_PADTECH,
    clktech     => CFG_CLKTECH,
    cpu_freq    => CPU_FREQ,
    devid       => GAISLER_RV64GC,
    disas       => disas)
  port map (
    -- Clock & reset
    clkm        => clkm, 
    resetn      => resetn,
    lock        => lock,
    rstno       => rstn,
    -- misc
    dmen        => dmen,
    dmbreak     => dmbreak,
    dmreset     => dmreset,
    cpu0errn    => cpu0errn,
    -- GPIO
    gpio_i      => gpio_i,
    gpio_o      => gpio_o,
    gpio_oe     => gpio_oe,
    -- UART
    uart_rx     => uart_rx,
    uart_ctsn   => uart_ctsn,
    uart_tx     => uart_tx,
    uart_rtsn   => uart_rtsn,
    -- Memory controller
    mem_aximi   => mem_aximi,
    mem_aximo   => mem_aximo,
    mem_ahbsi0  => mem_ahbsi,
    mem_ahbso0  => mem_ahbso,
    mem_apbi0   => mem_apbi, 
    mem_apbo0   => mem_apbo, 
    -- PROM controller
    rom_ahbsi1  => rom_ahbsi,
    rom_ahbso1  => rom_ahbso,
    -- Ethernet PHY
    ethi        => ethi,
    etho        => etho,
    eth_apbi    => open,
    eth_apbo    => apb_none,
    -- Debug UART
    duart_rx    => duart_rx,
    duart_tx    => duart_tx,
    -- Debug JTAG
    tck         => tck,
    tms         => tms,
    tdi         => tdi,
    tdo         => tdo,
    -- RISC-V JTAG
    jtag_rv_tck => jtag_rv_tck,
    jtag_rv_tms => jtag_rv_tms,
    jtag_rv_tdi => jtag_rv_tdi,
    jtag_rv_tdo => jtag_rv_tdo
  );

  --errorn_pad : odpad
  --  generic map (tech => padtech, oepol => OEPOL)
  --  port map (errorn, cpu0errn);

  --dsuen_pad : inpad
  --  generic map (tech => padtech, level => cmos, voltage => x12v)
  --  port map (switch(2), dmen);
  dmen <= '1';

  -- Button 2,3,4 are still to be assigned
  --dsubre_pad : inpad
  --  generic map (tech => padtech, level => cmos, voltage => x18v)
  --  port map (button(4), dmbreak);
  dmbreak <= '0';

  --ndreset_pad : outpad
  --  generic map (tech => padtech, level => cmos, voltage => x18v)
  --  port map (led(4), dsuo.ndmreset);

  --dmactive_pad : outpad
  --  generic map (tech => padtech, level => cmos, voltage => x18v)
  --  port map (led(5), dsuo.dmactive);

  -----------------------------------------------------------------------------
  -- Debug UART / UART --------------------------------------------------------
  -----------------------------------------------------------------------------
  sw3_pad : inpad
    generic map (tech => padtech, level => cmos, voltage => x12v)
    port map (sw(3), dsu_sel);
  
  uart_tx_int     <= duart_tx       when dsu_sel = '1' else uart_tx(0);
  uart_rtsn_int   <= '1'            when dsu_sel = '1' else uart_rtsn(0);  
  uart_rx(0)      <= uart_rx_int    when dsu_sel = '0' else '1';
  uart_ctsn(0)    <= uart_ctsn_int  when dsu_sel = '0' else '1';
  duart_rx        <= uart_rx_int    when dsu_sel = '1' else '1';
  
  dsurx_pad : inpad
    generic map (level => cmos, voltage => x18v, tech => padtech)
    port map (uart_txd_in, uart_rx_int);
  dsutx_pad : outpad
    generic map (level => cmos, voltage => x18v, tech => padtech)
    port map (uart_rxd_out, uart_tx_int);

  -----------------------------------------------------------------------
  --  PROM
  -----------------------------------------------------------------------

  prom_gen : if (SIMULATION = 0) generate
    rom32 : if CFG_AHBDW = 32 generate
      brom : entity work.ahbrom
        generic map (
          hindex  => 1,
          haddr   => ROM_HADDR,
          hmask   => ROM_HMASK,
          pipe    => 0)
        port map (
          rst     => rstn,
          clk     => clkm,
          ahbsi   => rom_ahbsi,
          ahbso   => rom_ahbso);
    end generate;
    rom64 : if CFG_AHBDW = 64 generate
      brom : entity work.ahbrom64
        generic map (
          hindex  => 1,
          haddr   => ROM_HADDR,
          hmask   => ROM_HMASK,
          pipe    => 0)
        port map (
          rst     => rstn,
          clk     => clkm,
          ahbsi   => rom_ahbsi,
          ahbso   => rom_ahbso);
    end generate;
    rom128 : if CFG_AHBDW = 128 generate
      brom : entity work.ahbrom128
        generic map (
          hindex  => 1,
          haddr   => ROM_HADDR,
          hmask   => ROM_HMASK,
          pipe    => 0)
        port map (
          rst     => rstn,
          clk     => clkm,
          ahbsi   => rom_ahbsi,
          ahbso   => rom_ahbso);
    end generate;
  end generate prom_gen;

-----------------------------------------------------------------------
-- GPIO                                                                
-----------------------------------------------------------------------
  gpio0 : if CFG_GRGPIO_ENABLE /= 0 generate
  -- SWITCHES  
  gpsw_pads : for i in 0 to 2 generate
      gpsw_pad : inpad
        generic map (tech => padtech, level => cmos, voltage => x12v)
        port map (sw(i), gpio_i(i));
    end generate gpsw_pads;
    gpio_i(3) <= dsu_sel;

  -- BUTTONS left out one for compatibility with Arty A7
  gpb_pads : for i in 1 to 3 generate
    gpb_pad : inpad
      generic map (tech => padtech, level => cmos, voltage => x12v)
      port map (btn(i), gpio_i(i+4));
  end generate gpb_pads;

  -- LEDS
  gpled_pads : for i in 0 to 7 generate
    gpled_pad : outpad
      generic map (tech => padtech, level => cmos, voltage => x18v)
      port map (led(i), gpio_o(i+16));
  end generate gpled_pads;

  -- PMOD JB
   pmod_jb_pads : for i in 0 to 7 generate
      pmod_jb_gpio_pad : iopad
	generic map (tech => padtech, level => cmos, voltage => x33v) -- , strength => 8)
        port map (pmod_jb(i), gpio_o(i+24), gpio_oe(i+24), gpio_i(i+24));
    end generate;
  
  counter_en <= gpio_o(24);
  counter_rstn <= gpio_o(25);

  end generate;

-----------------------------------------------------------------------
-- RISC-V JTAG
-----------------------------------------------------------------------
  --     PMOD-JA
  -------------------
  -- TDO  1 |  7  TDI
  -- NC   2 |  8  TMS
  -- TCK  3 |  9  NC
  -- NC   4 | 10  NC
  -- GND  5 | 11  GND
  -- VCC  6 | 12  VCC
  -------------------

  rvjtag : if CFG_LOCAL_AHB_JTAG_RV = 1 generate
    --tdo_pad : iopad generic map (tech => padtech)
    --  port map (ja(0), jtag_rv_tdo, oeon, open);
    tdo_pad : outpad generic map (tech => padtech)
        port map (ja(0), jtag_rv_tdo);
    
    --ntrst_pad : iopad generic map (tech => padtech)
    --  port map (ja(1), gnd, oeoff, open);
    
    --tck_pad : iopad generic map (tech => padtech)
    --  port map (ja(2), gnd, oeoff, jtag_rv_tck);
    tck_pad : clkpad generic map (tech => padtech, arch => 2)
      port map (ja(2), jtag_rv_tck);
    
    --nc3_pad : iopad generic map (tech => padtech)
    --  port map (ja(3), gnd, oeoff, open);
    
    tdi_pad : iopad generic map (tech => padtech)
      port map (ja(4), gnd, oeoff, jtag_rv_tdi);
    tms_pad : iopad generic map (tech => padtech)
      port map (ja(5), gnd, oeoff, jtag_rv_tms);
    
      --nrst_pad : iopad generic map (tech => padtech)
    --  port map (ja(6), gnd, oeoff, open);
    --nc7_pad : iopad generic map (tech => padtech)
    --  port map (ja(7), gnd, oeoff, open);

  end generate;

-----------------------------------------------------------------------
---  Boot message  ----------------------------------------------------
-----------------------------------------------------------------------

-- pragma translate_off
  x : report_design
    generic map (
      msg1 => "NOEL-V Demonstration design for Digilent Zedboard" &
      ", " & integer'image(CPU_FREQ / 1000) & " MHz",
      fabtech => tech_table(fabtech), memtech => tech_table(memtech),
      mdel => 1
      );
-- pragma translate_on

end rtl;


