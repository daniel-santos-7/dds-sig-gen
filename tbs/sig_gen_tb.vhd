library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.math_real.all;
use work.sig_gen_pkg.all;
use work.sig_gen_tb_pkg.all;

entity sig_gen_tb is
    generic (
        PHA_ACC_BITS  : natural := 32;
        FREQ_HZ       : natural := 1000000;
        PHASE_DEG     : natural := 0;
        AMP_VAL       : natural := 65535;
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
    
    constant PULSE_LEN_VAL : natural := 200;
    constant DRAG_COEFF_VAL : real := 0.5;

    constant TC   : test_case_t := (
        freq_hz => FREQ_HZ_VAL, 
        phase_deg => PHASE_DEG_VAL, 
        amp_val => AMP_VAL_VAL,
        pulse_len => PULSE_LEN_VAL,
        drag_coeff => DRAG_COEFF_VAL
    );
    
    constant REGS : reg_values_t  := to_regs(TC);

    constant TOTAL_SAMPLES : natural := PULSE_LEN_VAL + 50; -- Pulse + padding

    signal clk_en : boolean := false;
    signal clk_i  : std_logic := '0';
    signal rst_i  : std_logic := '0';

    signal wb : wb_bus;

    signal sig_i : std_logic_vector(15 downto 0);
    signal sig_q : std_logic_vector(15 downto 0);

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
            
            sig_i_o : out std_logic_vector(15 downto 0);
            sig_q_o : out std_logic_vector(15 downto 0)
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
        sig_i_o => sig_i,
        sig_q_o => sig_q
    );

    clk_i <= not clk_i after (CLK_PERIOD / 2) when clk_en else '0';

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

        clk_en <= false;
        wait;
    end process stim_process;

end architecture tb;
