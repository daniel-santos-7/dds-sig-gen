library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.sig_gen_pkg.all;
use work.sig_gen_tb_pkg.all;
use work.sine_lut_pkg.LUT_ADDR_BITS;
use work.sine_lut_pkg.OUT_RES_BITS;

entity sig_gen_tb is
    generic (
        PHA_ACC_BITS  : natural := 32;
        CLK_FREQUENCY : natural := 50e6;
        OUT_FREQUENCY : natural := 1e6
    );
end sig_gen_tb;

architecture tb of sig_gen_tb is

    constant CLK_PERIOD : time := (1 sec / CLK_FREQUENCY);

    signal clk_en : boolean := false;

    signal clk_i : std_logic := '0';

    signal dut_if : sig_gen_dut_if_t;

    constant PHA_INC : std_logic_vector(PHA_ACC_BITS-1 downto 0) := calc_phase_increment(PHA_ACC_BITS, CLK_FREQUENCY, OUT_FREQUENCY);

    constant OUT_PERIOD : time := (1 sec / OUT_FREQUENCY);

begin

    -- Instantiate the unit under test --
    uut : sig_gen generic map (
        PHA_ACC_BITS => PHA_ACC_BITS
    ) port map (
        clk_i => clk_i,
        rst_i => dut_if.rst_i,
        we_i  => dut_if.we_i,
        inc_i => dut_if.inc_i,
        pha_i => dut_if.pha_i,
        amp_i => dut_if.amp_i,
        sig_o => dut_if.sig_o
    );

    -- Clock generation --
    clk_i <= not clk_i after (CLK_PERIOD/2) when clk_en else '0';

    -- Test stimulus --
    stim_process : process
    begin
        clk_en <= true;
        initialize(dut_if);
        reset(clk_i, dut_if);
        write_data(clk_i, dut_if, PHA_INC);
        wait for OUT_PERIOD;
        clk_en <= false;
        wait;
    end process stim_process;

end tb;
