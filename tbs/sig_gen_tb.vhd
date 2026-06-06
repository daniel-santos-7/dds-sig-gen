library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.math_real.all;
use work.sig_gen_pkg.all;
use work.sig_gen_tb_pkg.all;

entity sig_gen_tb is
    generic (
        PHA_ACC_BITS  : natural := 32;
        TEST_INDEX    : natural := 0;
        NUM_PERIODS   : natural := 4;
        SAMPLES_FILE  : string  := "samples.txt";
        CASE_FILE     : string  := "test_case.txt";
        REG_FILE      : string  := "reg_values.txt";
        VECTORS_FILE  : string  := "test_vectors.csv"
    );
end sig_gen_tb;

architecture tb of sig_gen_tb is

    constant CLK_PERIOD : time := 20 ns;

    constant TC   : test_case_t := get_test_case(TEST_INDEX, VECTORS_FILE);
    constant REGS : reg_values_t  := to_regs(TC);

    constant INC_REAL : real := TC.freq_hz / CLK_FREQ * (2.0 ** PHA_ACC_BITS);

    constant CYCLES_PER_PERIOD : natural := natural(ceil((2.0 ** PHA_ACC_BITS) / INC_REAL));
    constant TOTAL_SAMPLES     : natural := NUM_PERIODS * CYCLES_PER_PERIOD;

    signal clk_en : boolean := false;
    signal clk_i  : std_logic := '0';
    signal rst_i  : std_logic := '0';

    signal wb : wb_bus;

    signal sig_o : std_logic_vector(11 downto 0);

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
        sig_o => sig_o
    );

    clk_i <= not clk_i after (CLK_PERIOD / 2) when clk_en else '0';

    stim_process : process
    begin
        report "Running test " & integer'image(TEST_INDEX) & ": freq=" & img(TC.freq_hz) & " Hz, phase=" & img(TC.phase_deg) & " deg, amp=" & img(TC.amp_pct) & "%";
        clk_en <= true;

        wb_init(wb);
        wb_reset(clk_i, rst_i);
        wb_write_config(clk_i, wb, REGS.inc, REGS.pha, REGS.amp);

        write_case_file(CASE_FILE, TC);
        write_reg_file(REG_FILE, REGS);

        for i in 0 to 2 loop
            wait until rising_edge(clk_i);
        end loop;

        write_sample(clk_i, SAMPLES_FILE, sig_o, TOTAL_SAMPLES);

        clk_en <= false;
        wait;
    end process stim_process;

end architecture tb;
