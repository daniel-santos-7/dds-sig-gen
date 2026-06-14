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
        freq_hz   => FREQ_HZ_VAL, 
        phase_deg => PHASE_DEG_VAL, 
        amp_val   => AMP_VAL_VAL,
        pulse_len => PULSE_LEN,
        drag      => real(DRAG_COEFF) / 32768.0
    );
    
    constant REGS : reg_values_t  := to_regs(TC);

    signal clk_en : boolean := false;
    signal clk_i  : std_logic := '0';
    signal rst_i  : std_logic := '0';

    signal wb : wb_bus;

    signal sig_i    : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal sig_q    : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal active   : std_logic;

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

    stim_process : process
    begin
        report "freq=" & img(TC.freq_hz) & " Hz, pulse=" & integer'image(TC.pulse_len) & " cycles";
        clk_en <= true;

        wb_init(wb);
        wb_reset(clk_i, rst_i);
        wb_write_config(clk_i, wb, REGS);

        write_case_file(CASE_FILE, TC);
        write_reg_file(REG_FILE, REGS);

        save_samples(clk_i, SAMPLES_FILE, sig_i, sig_q, active);

        clk_en <= false;
        report "Simulation complete";
        wait;
    end process stim_process;

end architecture tb;
