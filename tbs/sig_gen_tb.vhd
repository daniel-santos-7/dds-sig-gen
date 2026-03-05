library IEEE;
library work;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.sig_gen_pkg.all;
use work.sig_gen_tb_pkg.all;
use work.sine_lut_pkg.LUT_ADDR_BITS;
use work.sine_lut_pkg.OUT_RES_BITS;

entity sig_gen_tb is
    generic (
        PHA_ACC_BITS : natural := 32
    );
end sig_gen_tb;

architecture tb of sig_gen_tb is

    signal dut_if : sig_gen_dut_if_t := (
        rst_i => '0',
        clk_i => '0',
        cyc_i => '0',
        stb_i => '0',
        we_i  => '0',
        sel_i => (others => '0'),
        dat_i => (others => '0'),
        ack_o => '0',
        dat_o => (others => '0')
    );

    -- Clock period
    constant CLK_PERIOD : time := 20 ns;

    signal clk_en : boolean := true;

    signal pha_inc : wb_data_t := x"00000000";

begin

    assert PHA_ACC_BITS = WB_DATA_WIDTH
        report "sig_gen_tb expects PHA_ACC_BITS = 32"
        severity failure;

    -- Instantiate the unit under test --
    uut : sig_gen generic map (
        PHA_ACC_BITS => PHA_ACC_BITS
    ) port map (
        rst_i => dut_if.rst_i,
        clk_i => dut_if.clk_i,
        cyc_i => dut_if.cyc_i,
        stb_i => dut_if.stb_i,
        we_i  => dut_if.we_i,
        sel_i => dut_if.sel_i,
        dat_i => dut_if.dat_i,
        ack_o => dut_if.ack_o,
        dat_o => dut_if.dat_o
    );

    -- Clock generation --
    dut_if.clk_i <= not dut_if.clk_i after (CLK_PERIOD/2) when clk_en else '0';

    -- Test stimulus --
    stim_process : process
    begin
        
        initialize_signals(dut_if);
        reset(dut_if);

        for i in LUT_ADDR_BITS to PHA_ACC_BITS-1 loop
            pha_inc <= std_logic_vector(shift_left(to_unsigned(1, PHA_ACC_BITS), i));
            write_data(dut_if, pha_inc);
            for j in 0 to 2**(PHA_ACC_BITS-i)-1 loop
                wait until rising_edge(dut_if.clk_i);
            end loop;
        end loop;

        wait until rising_edge(dut_if.clk_i);
        clk_en <= false;
        wait;
    end process stim_process;

end tb;
