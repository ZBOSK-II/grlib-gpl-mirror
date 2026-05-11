
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- GRLIB libraries
library grlib;
use grlib.stdlib.all;
use grlib.amba.all;
use grlib.devices.all;

entity axi_reset_gate is
    generic (
        -- Technology configuration
        tech         : integer := 0;  -- Target technology (0 for inferred)
        
        -- AXI configuration
        id_width     : integer range 1 to 16 := 4;   -- AXI ID width
        addr_width   : integer range 12 to 64 := 32; -- Address width (Zynq PS is 40)
        data_width   : integer range 32 to 1024 := 32; -- Data width
        
        -- Number of outstanding transactions
        max_pending  : integer range 1 to 256 := 16;
        
        -- AXITE or AXI4 selection
        axi4         : boolean := false;  -- true = AXI4, false = AXI3
        
        -- Debug
        debug_en     : integer range 0 to 1 := 0
    );
    port (
        -- Clock and Reset
        clk          : in  std_logic;
        rstn         : in  std_logic;  -- GRLIB convention: active low sync reset
        
        -- Control interface
        isolate_i    : in  std_logic;  -- Assert to begin isolation sequence
        quiescent_o  : out std_logic;  -- Indicates safe to reset
        
        -- Debug output
        debug_o      : out std_logic_vector(7 downto 0);
        
        --------------------------------------------------------------------------
        -- Slave AXI Interface (to NOELV - acts as slave to processor)
        --------------------------------------------------------------------------
        s_axi_mosi_i : in  axi_mosi_type;  -- From NOELV master
        s_axi_somi_o : out axi_somi_type;  -- To NOELV master (ready signals)
        
        --------------------------------------------------------------------------
        -- Master AXI Interface (to Zynq PS memory controller)
        --------------------------------------------------------------------------
        m_axi_mosi_o : out axi_mosi_type;  -- To Zynq PS slave port
        m_axi_somi_i : in  axi_somi_type    -- From Zynq PS slave port
    );
end entity axi_reset_gate;

architecture rtl of axi_reset_gate is
    --------------------------------------------------------------------------
    -- State machine type
    --------------------------------------------------------------------------
    type t_gate_state is (
        ST_RUNNING,      -- Normal operation, full passthrough
        ST_ISOLATING,    -- Isolate asserted, draining pending transactions
        ST_QUIESCENT     -- All transactions drained, safe to reset
    );
    
    signal state, next_state : t_gate_state;
    
    --------------------------------------------------------------------------
    -- Transaction counters
    --------------------------------------------------------------------------
    signal wr_pending    : integer range 0 to max_pending;
    signal rd_pending    : integer range 0 to max_pending;
    signal wr_pending_n  : integer range 0 to max_pending;
    signal rd_pending_n  : integer range 0 to max_pending;
    
    --------------------------------------------------------------------------
    -- Transaction event detection
    --------------------------------------------------------------------------
    -- Write transactions
    signal wr_addr_hs    : std_logic;  -- Write address handshake
    signal wr_data_last  : std_logic;  -- Last write data beat
    signal wr_resp_hs    : std_logic;  -- Write response handshake
    
    -- Read transactions
    signal rd_addr_hs    : std_logic;  -- Read address handshake
    signal rd_data_last  : std_logic;  -- Last read data beat
    
    --------------------------------------------------------------------------
    -- Master side registered signals (single driver)
    --------------------------------------------------------------------------
    signal m_mosi_r    : axi_mosi_type;
    signal m_mosi_nxt  : axi_mosi_type;
    
    --------------------------------------------------------------------------
    -- Slave side combinational signals
    --------------------------------------------------------------------------
    signal s_somi_c    : axi_somi_type;
    
    --------------------------------------------------------------------------
    -- Handshake detection
    --------------------------------------------------------------------------
    impure function write_addr_handshake(
        mosi : axi_mosi_type;
        somi : axi_somi_type
    ) return std_logic is
    begin
        if mosi.aw.valid = '1' and somi.aw.ready = '1' then
            return '1';
        end if;
        return '0';
    end function;
    
    impure function write_data_handshake(
        mosi : axi_mosi_type;
        somi : axi_somi_type
    ) return std_logic is
    begin
        if mosi.w.valid = '1' and somi.w.ready = '1' then
            return '1';
        end if;
        return '0';
    end function;
    
    impure function write_resp_handshake(
        mosi : axi_mosi_type;
        somi : axi_somi_type
    ) return std_logic is
    begin
        if somi.b.valid = '1' and mosi.b.ready = '1' then
            return '1';
        end if;
        return '0';
    end function;
    
    impure function read_addr_handshake(
        mosi : axi_mosi_type;
        somi : axi_somi_type
    ) return std_logic is
    begin
        if mosi.ar.valid = '1' and somi.ar.ready = '1' then
            return '1';
        end if;
        return '0';
    end function;
    
    impure function read_data_handshake(
        mosi : axi_mosi_type;
        somi : axi_somi_type
    ) return std_logic is
    begin
        if somi.r.valid = '1' and mosi.r.ready = '1' then
            return '1';
        end if;
        return '0';
    end function;

begin

    --------------------------------------------------------------------------
    -- Handshake signal assignment
    --------------------------------------------------------------------------
    -- All handshakes are observed on the master side using the registered
    -- m_mosi_r outputs, which is what the PS actually sees.  Using the
    -- raw slave inputs (s_axi_mosi_i) would be one pipeline stage early
    -- and would produce incorrect counts.
    wr_addr_hs   <= write_addr_handshake(m_mosi_r, m_axi_somi_i)
                    when state = ST_RUNNING else '0';

    wr_data_last <= write_data_handshake(m_mosi_r, m_axi_somi_i)
                    and m_mosi_r.w.last
                    when state = ST_RUNNING else '0';

    wr_resp_hs   <= write_resp_handshake(m_mosi_r, m_axi_somi_i);

    rd_addr_hs   <= read_addr_handshake(m_mosi_r, m_axi_somi_i)
                    when state = ST_RUNNING else '0';

    rd_data_last <= read_data_handshake(m_mosi_r, m_axi_somi_i)
                    and m_axi_somi_i.r.last;
    
    --------------------------------------------------------------------------
    -- Transaction counting - combinational
    --------------------------------------------------------------------------
    p_counters_comb : process(wr_addr_hs, wr_resp_hs, wr_pending,
                              rd_addr_hs, rd_data_last, rd_pending)
        variable wr_inc : integer;
        variable wr_dec : integer;
        variable rd_inc : integer;
        variable rd_dec : integer;
    begin
        -- Write pending counter
        if wr_addr_hs = '1' then
            wr_inc := 1;
        else
            wr_inc := 0;
        end if;
        
        if wr_resp_hs = '1' then
            wr_dec := 1;
        else
            wr_dec := 0;
        end if;
        
        wr_pending_n <= wr_pending + wr_inc - wr_dec;
        
        -- Read pending counter
        if rd_addr_hs = '1' then
            rd_inc := 1;
        else
            rd_inc := 0;
        end if;
        
        if rd_data_last = '1' then
            rd_dec := 1;
        else
            rd_dec := 0;
        end if;
        
        rd_pending_n <= rd_pending + rd_inc - rd_dec;
    end process p_counters_comb;
    
    --------------------------------------------------------------------------
    -- Registered transaction counters
    --------------------------------------------------------------------------
    p_counters_reg : process(clk, rstn)
    begin
        if rstn = '0' then
            wr_pending <= 0;
            rd_pending <= 0;
        elsif rising_edge(clk) then
            wr_pending <= wr_pending_n;
            rd_pending <= rd_pending_n;
        end if;
    end process p_counters_reg;
    
    --------------------------------------------------------------------------
    -- State machine - combinational next state
    --------------------------------------------------------------------------
    p_fsm_comb : process(state, isolate_i, wr_pending_n, rd_pending_n)
    begin
        next_state <= state;

        case state is
            when ST_RUNNING =>
                if isolate_i = '1' then
                    next_state <= ST_ISOLATING;
                end if;

            when ST_ISOLATING =>
                -- Use combinational next values so we transition only when
                -- the counters will genuinely be zero at the next clock edge,
                -- avoiding a one-cycle-early transition on the last decrement.
                if wr_pending_n = 0 and rd_pending_n = 0 then
                    next_state <= ST_QUIESCENT;
                end if;
                
            when ST_QUIESCENT =>
                if isolate_i = '0' then
                    next_state <= ST_RUNNING;
                end if;
                
            when others =>
                next_state <= ST_RUNNING;
        end case;
    end process p_fsm_comb;
    
    --------------------------------------------------------------------------
    -- State machine - registered
    --------------------------------------------------------------------------
    p_fsm_reg : process(clk, rstn)
    begin
        if rstn = '0' then
            state <= ST_RUNNING;
        elsif rising_edge(clk) then
            state <= next_state;
        end if;
    end process p_fsm_reg;
    
    --------------------------------------------------------------------------
    -- Quiescent output
    --------------------------------------------------------------------------
    quiescent_o <= '1' when (state = ST_QUIESCENT) else '0';
    
    --------------------------------------------------------------------------
    -- Master side output generation - combinational next values
    --------------------------------------------------------------------------
    p_master_mosi_comb : process(state, s_axi_mosi_i, m_mosi_r, m_axi_somi_i)
    begin
        -- Default: hold current values
        m_mosi_nxt <= m_mosi_r;
        
        case state is
            when ST_RUNNING =>
                -- Full passthrough for all channels
                m_mosi_nxt.aw.id     <= s_axi_mosi_i.aw.id;
                m_mosi_nxt.aw.addr   <= s_axi_mosi_i.aw.addr;
                m_mosi_nxt.aw.len    <= s_axi_mosi_i.aw.len;
                m_mosi_nxt.aw.size   <= s_axi_mosi_i.aw.size;
                m_mosi_nxt.aw.burst  <= s_axi_mosi_i.aw.burst;
                m_mosi_nxt.aw.lock   <= s_axi_mosi_i.aw.lock;
                m_mosi_nxt.aw.cache  <= s_axi_mosi_i.aw.cache;
                m_mosi_nxt.aw.prot   <= s_axi_mosi_i.aw.prot;
                m_mosi_nxt.aw.valid  <= s_axi_mosi_i.aw.valid;
                
                m_mosi_nxt.w.data    <= s_axi_mosi_i.w.data;
                m_mosi_nxt.w.strb    <= s_axi_mosi_i.w.strb;
                m_mosi_nxt.w.last    <= s_axi_mosi_i.w.last;
                m_mosi_nxt.w.valid   <= s_axi_mosi_i.w.valid;
                
                m_mosi_nxt.b.ready   <= s_axi_mosi_i.b.ready;
                
                m_mosi_nxt.ar.id     <= s_axi_mosi_i.ar.id;
                m_mosi_nxt.ar.addr   <= s_axi_mosi_i.ar.addr;
                m_mosi_nxt.ar.len    <= s_axi_mosi_i.ar.len;
                m_mosi_nxt.ar.size   <= s_axi_mosi_i.ar.size;
                m_mosi_nxt.ar.burst  <= s_axi_mosi_i.ar.burst;
                m_mosi_nxt.ar.lock   <= s_axi_mosi_i.ar.lock;
                m_mosi_nxt.ar.cache  <= s_axi_mosi_i.ar.cache;
                m_mosi_nxt.ar.prot   <= s_axi_mosi_i.ar.prot;
                m_mosi_nxt.ar.valid  <= s_axi_mosi_i.ar.valid;
                
                m_mosi_nxt.r.ready   <= s_axi_mosi_i.r.ready;
                
            when ST_ISOLATING | ST_QUIESCENT =>
                -- Deassert all valid signals to block new transactions
                m_mosi_nxt.aw.valid <= '0';
                m_mosi_nxt.w.valid  <= '0';
                m_mosi_nxt.ar.valid <= '0';
                
                -- Pass through NOEL-V's ready signals so in-flight responses
                -- drain back to NOEL-V normally.  Do NOT force ready='1' here:
                -- swallowing responses invisibly to NOEL-V leaves the PS AXI
                -- slave with retired IDs that NOEL-V never acknowledged, which
                -- corrupts the PS interconnect and causes PS-side DMA errors
                -- (e.g. SDHCI ADMA faults) after the NOEL-V reset cycle.
                m_mosi_nxt.b.ready  <= s_axi_mosi_i.b.ready;
                m_mosi_nxt.r.ready  <= s_axi_mosi_i.r.ready;
                
            when others =>
                null;
        end case;
    end process p_master_mosi_comb;
    
    --------------------------------------------------------------------------
    -- Master side output generation - registered outputs
    --------------------------------------------------------------------------
    p_master_mosi_reg : process(clk, rstn)
    begin
        if rstn = '0' then
            -- Initialize to quiescent state per AXI spec
            m_mosi_r.aw.valid <= '0';
            m_mosi_r.w.valid  <= '0';
            m_mosi_r.ar.valid <= '0';
            m_mosi_r.b.ready  <= '0';
            m_mosi_r.r.ready  <= '0';
        elsif rising_edge(clk) then
            m_mosi_r <= m_mosi_nxt;
        end if;
    end process p_master_mosi_reg;
    
    --------------------------------------------------------------------------
    -- Master side output assignment (single driver point)
    --------------------------------------------------------------------------
    m_axi_mosi_o <= m_mosi_r;
    
    --------------------------------------------------------------------------
    -- Slave side response generation - exclusively driven by this module
    --------------------------------------------------------------------------
    p_slave_somi_comb : process(state, s_axi_mosi_i, m_axi_somi_i)
    begin
        -- Default: zero all ready signals
        s_somi_c.aw.ready <= '0';
        s_somi_c.w.ready  <= '0';
        s_somi_c.ar.ready <= '0';
        
        -- Default: pass through response channel data/valid from master side
        s_somi_c.b.id      <= m_axi_somi_i.b.id;
        s_somi_c.b.resp    <= m_axi_somi_i.b.resp;
        s_somi_c.b.valid   <= m_axi_somi_i.b.valid;
        
        s_somi_c.r.id      <= m_axi_somi_i.r.id;
        s_somi_c.r.data    <= m_axi_somi_i.r.data;
        s_somi_c.r.resp    <= m_axi_somi_i.r.resp;
        s_somi_c.r.last    <= m_axi_somi_i.r.last;
        s_somi_c.r.valid   <= m_axi_somi_i.r.valid;
        
        case state is
            when ST_RUNNING =>
                -- Full passthrough for ready signals
                s_somi_c.aw.ready <= m_axi_somi_i.aw.ready;
                s_somi_c.w.ready  <= m_axi_somi_i.w.ready;
                s_somi_c.ar.ready <= m_axi_somi_i.ar.ready;
                
            when ST_ISOLATING =>
                -- Block new transaction requests but let in-flight responses
                -- drain back to NOEL-V.  The counters track these completions;
                -- only once they reach zero do we move to ST_QUIESCENT.
                s_somi_c.aw.ready <= '0';
                s_somi_c.w.ready  <= '0';
                s_somi_c.ar.ready <= '0';

            when ST_QUIESCENT =>
                -- All transactions fully drained.  Gate response valids to
                -- zero so NOEL-V sees a clean bus while held in reset.
                s_somi_c.aw.ready <= '0';
                s_somi_c.w.ready  <= '0';
                s_somi_c.ar.ready <= '0';
                s_somi_c.b.valid  <= '0';
                s_somi_c.r.valid  <= '0';

            when others =>
                null;
        end case;
    end process p_slave_somi_comb;
    
    --------------------------------------------------------------------------
    -- Slave side output assignment (single driver point)
    --------------------------------------------------------------------------
    s_axi_somi_o <= s_somi_c;
    
    --------------------------------------------------------------------------
    -- Debug output
    --------------------------------------------------------------------------
    g_debug : if debug_en = 1 generate
        debug_o(0) <= '1' when state = ST_RUNNING else '0';
        debug_o(1) <= '1' when state = ST_ISOLATING else '0';
        debug_o(2) <= '1' when state = ST_QUIESCENT else '0';
        debug_o(3) <= '1' when wr_pending = 0 else '0';
        debug_o(4) <= '1' when rd_pending = 0 else '0';
        debug_o(5) <= wr_addr_hs;
        debug_o(6) <= rd_addr_hs;
        debug_o(7) <= isolate_i;
    end generate;
    
    g_no_debug : if debug_en = 0 generate
        debug_o <= (others => '0');
    end generate;

end architecture rtl;