library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use STD.textio.all;
use work.sig_gen_pkg.all;
use work.sig_gen_tb_pkg.all;
use work.sine_lut_pkg.OUT_RES_BITS;

entity sig_gen_tb is
    generic (
        PHA_ACC_BITS  : natural := 32;
        REG_INC_VAL   : natural := 85899345;
        REG_PHA_VAL   : natural := 0;
        REG_AMP_VAL   : natural := 4095;
        DATA_FILE     : string  := "sig_gen_tb.txt"
    );
end sig_gen_tb;

architecture tb of sig_gen_tb is

    constant CLK_PERIOD : time := 20 ns;

    constant CYCLES_PER_PERIOD : natural := natural((2.0 ** PHA_ACC_BITS + real(REG_INC_VAL) - 1.0) / real(REG_INC_VAL));

    signal clk_en : boolean := false;
    signal clk_i  : std_logic := '0';
    signal rst_i  : std_logic := '0';

    signal wb : wb_bus;

    signal sig_o : std_logic_vector(OUT_RES_BITS-1 downto 0);

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
        file outfile : text open write_mode is DATA_FILE;
    begin
        clk_en <= true;

        wb_init(wb);
        wb_reset(clk_i, rst_i);
        wb_write_config(clk_i, wb, REG_INC_VAL, REG_PHA_VAL, REG_AMP_VAL);

        write_sample(clk_i, outfile, sig_o, CYCLES_PER_PERIOD);

        report "Saved " & integer'image(CYCLES_PER_PERIOD) & " samples";
        clk_en <= false;
        wait;
    end process stim_process;

end architecture tb;
