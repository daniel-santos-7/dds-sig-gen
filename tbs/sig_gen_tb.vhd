library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.math_real.all;
use work.sig_gen_pkg.all;
use work.sig_gen_tb_pkg.all;
use work.sine_lut_pkg.OUT_RES_BITS;
use IEEE.numeric_std.all;

entity sig_gen_tb is
    generic (
        PHA_ACC_BITS  : natural := 32;
        FREQ_HZ       : natural := 1000000;
        PHASE_DEG     : natural := 0;
        AMP_VAL       : natural := 65535;
        PULSE_LEN     : natural := 200;
        DRAG_COEFF    : integer := 16384;  -- Q1.15: 0.5 * 32768
        NUM_PERIODS   : natural := 4;
        SAMPLES_FILE  : string  := "samples.txt";
        CASE_FILE     : string  := "test_case.txt";
        REG_FILE      : string  := "reg_values.txt"
    );
end sig_gen_tb;

architecture tb of sig_gen_tb is

    constant CLK_PERIOD : time := 10 ns;

    constant FREQ_HZ_VAL   : real := real(FREQ_HZ);
    constant PHASE_DEG_VAL : real := real(PHASE_DEG);
    constant AMP_VAL_VAL   : real := real(AMP_VAL);
    
    constant TC   : test_case_t := (
        freq_hz => FREQ_HZ_VAL, 
        phase_deg => PHASE_DEG_VAL, 
        amp_val => AMP_VAL_VAL,
        pulse_len => PULSE_LEN,
        drag_coeff => real(DRAG_COEFF) / 32768.0
    );
    
    constant REGS : reg_values_t  := to_regs(TC);

    constant TOTAL_SAMPLES : natural := PULSE_LEN + 50; -- Pulse + padding

    signal clk_en : boolean := false;
    signal clk_i  : std_logic := '0';
    signal rst_i  : std_logic := '0';

    signal wb : wb_bus;

    signal sig_i    : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal sig_q    : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal active   : std_logic;

    signal mon_cycles : natural := 0;
    signal mon_edges  : natural := 0;
    signal mon_pre_i  : std_logic_vector(OUT_RES_BITS-1 downto 0) := (others => '0');
    signal mon_pre_q  : std_logic_vector(OUT_RES_BITS-1 downto 0) := (others => '0');
    signal mon_post_i : std_logic_vector(OUT_RES_BITS-1 downto 0) := (others => '0');
    signal mon_post_q : std_logic_vector(OUT_RES_BITS-1 downto 0) := (others => '0');

    signal p2_arm    : std_logic := '0';
    signal p2_cycles : natural := 0;
    signal p2_edges  : natural := 0;
    signal p2_active : std_logic := '0';

    -- component wb_sig_gen
    component wb_sig_gen is
        generic (
            DATA_WIDTH   : natural := 32;
            ADDR_WIDTH   : natural := 5;
            PHA_ACC_BITS : natural := 32
        );
        port (
            rst_i : in  std_logic;
            clk_i : in  std_logic;
            adr_i : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
            cyc_i : in  std_logic;
            stb_i : in  std_logic;
            we_i  : in  std_logic;
            sel_i : in  std_logic_vector(DATA_WIDTH/8-1 downto 0);
            dat_i : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            ack_o : out std_logic;
            dat_o : out std_logic_vector(DATA_WIDTH-1 downto 0);
            
            sig_i_o  : out std_logic_vector(OUT_RES_BITS-1 downto 0);
            sig_q_o  : out std_logic_vector(OUT_RES_BITS-1 downto 0);
            active_o : out std_logic
        );
    end component wb_sig_gen;

begin

    uut : wb_sig_gen generic map (
        DATA_WIDTH   => DATA_WIDTH,
        ADDR_WIDTH   => ADDR_WIDTH,
        PHA_ACC_BITS => PHA_ACC_BITS
    ) port map (
        rst_i => rst_i,
        clk_i => clk_i,
        adr_i => wb.adr_i,
        cyc_i => wb.cyc_i,
        stb_i => wb.stb_i,
        we_i  => wb.we_i,
        sel_i => wb.sel_i,
        dat_i => wb.dat_i,
        ack_o => wb.ack_o,
        dat_o => wb.dat_o,
        sig_i_o  => sig_i,
        sig_q_o  => sig_q,
        active_o => active
    );

    clk_i <= not clk_i after (CLK_PERIOD / 2) when clk_en else '0';

    monitor_proc : process(clk_i)
        variable prev : std_logic := '0';
        variable p2_prev : std_logic := '0';
    begin
        if rising_edge(clk_i) and clk_en then
            if active = '1' and prev = '0' then
                mon_edges <= mon_edges + 1;
                mon_pre_i <= sig_i;
                mon_pre_q <= sig_q;
            elsif active = '0' and prev = '1' then
                mon_edges <= mon_edges + 1;
                mon_post_i <= sig_i;
                mon_post_q <= sig_q;
            end if;
            if active = '1' then
                mon_cycles <= mon_cycles + 1;
            end if;
            prev := active;

            if p2_arm = '1' then
                if active = '1' and p2_prev = '0' then
                    p2_edges <= p2_edges + 1;
                    p2_active <= '1';
                elsif active = '0' and p2_prev = '1' then
                    p2_edges <= p2_edges + 1;
                    p2_active <= '0';
                end if;
                if active = '1' then
                    p2_cycles <= p2_cycles + 1;
                end if;
            end if;
            p2_prev := active;
        end if;
    end process monitor_proc;

    stim_process : process
    begin
        report "freq=" & img(TC.freq_hz) & " Hz, pulse=" & integer'image(TC.pulse_len) & " cycles";
        clk_en <= true;

        wb_init(wb);
        wb_reset(clk_i, rst_i);
        wb_write_config(clk_i, wb, REGS);

        write_case_file(CASE_FILE, TC);
        write_reg_file(REG_FILE, REGS);

        write_iq_sample(clk_i, SAMPLES_FILE, sig_i, sig_q, TOTAL_SAMPLES);

        report "Pulse width: " & integer'image(mon_cycles) & " cycles (expected " & integer'image(PULSE_LEN) & ")";
        assert mon_cycles >= PULSE_LEN and mon_cycles <= PULSE_LEN + 2
            report "PULSE WIDTH CHECK FAILED: " & integer'image(mon_cycles) & " (expected " & integer'image(PULSE_LEN) & ")"
            severity error;

        assert mon_edges = 2
            report "GLITCH CHECK FAILED: " & integer'image(mon_edges) & " edges"
            severity error;

        assert abs(to_integer(unsigned(mon_pre_i)) - 2**(OUT_RES_BITS-1)) < 50
            report "PRE-PULSE EXTINCTION I FAILED: " & integer'image(to_integer(unsigned(mon_pre_i)))
            severity error;

        assert abs(to_integer(unsigned(mon_pre_q)) - 2**(OUT_RES_BITS-1)) < 50
            report "PRE-PULSE EXTINCTION Q FAILED: " & integer'image(to_integer(unsigned(mon_pre_q)))
            severity error;

        assert abs(to_integer(unsigned(mon_post_i)) - 2**(OUT_RES_BITS-1)) < 50
            report "POST-PULSE EXTINCTION I FAILED: " & integer'image(to_integer(unsigned(mon_post_i)))
            severity error;

        assert abs(to_integer(unsigned(mon_post_q)) - 2**(OUT_RES_BITS-1)) < 50
            report "POST-PULSE EXTINCTION Q FAILED: " & integer'image(to_integer(unsigned(mon_post_q)))
            severity error;

        report "VHDL assertions: all passed";

        -- ============================================
        -- Phase 2: Pending trigger with delay
        -- ============================================
        report "=== Phase 2: Pending trigger with delay test ===";

        -- Arm phase 2 monitor
        p2_arm <= '1';
        wait until rising_edge(clk_i);

        -- Write new config while idle
        wb_write(clk_i, wb, REG_FTW, x"00000001");
        wb_write(clk_i, wb, REG_AMP, x"00007FFF");

        -- Trigger pulse 2 (normal, no pending)
        wb_write(clk_i, wb, REG_TRIG, x"00000001");

        -- Wait for env_active to go high (pulse started)
        wait until rising_edge(clk_i) and active = '1';

        -- Now write TRIG with delay=75 while pulse is active — should pend
        wb_write(clk_i, wb, REG_TRIG, x"00004B01");  -- delay=75 (0x4B), trig=1

        -- Wait for current pulse to finish + delay + next pulse
        for i in 0 to PULSE_LEN + 150 + PULSE_LEN loop
            wait until rising_edge(clk_i);
        end loop;

        -- Verify phase 2 pulse quality
        assert p2_edges = 4
            report "PHASE 2 GLITCH CHECK FAILED: " & integer'image(p2_edges) & " edges"
            severity error;

        assert p2_cycles >= 2 * PULSE_LEN and p2_cycles <= 2 * PULSE_LEN + 4
            report "PHASE 2 PULSE WIDTH CHECK FAILED: " & integer'image(p2_cycles)
            severity error;

        report "Phase 2 assertions: all passed";
        clk_en <= false;
        wait;
    end process stim_process;

end architecture tb;
