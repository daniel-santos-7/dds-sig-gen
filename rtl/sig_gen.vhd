library IEEE;
library work;
use IEEE.std_logic_1164.all;
use work.sig_gen_pkg.all;
use work.sine_lut_pkg.LUT_ADDR_BITS;
use work.sine_lut_pkg.OUT_RES_BITS;

entity sig_gen is
    generic (
        PHA_ACC_BITS : natural := 32
    );
    port (
        clk_i : in  std_logic;
        rst_i : in  std_logic;
        cyc_i : in  std_logic;
        stb_i : in  std_logic;
        we_i  : in  std_logic;
        sel_i : in  std_logic_vector(PHA_ACC_BITS/8-1 downto 0);
        dat_i : in  std_logic_vector(PHA_ACC_BITS-1 downto 0);
        ack_o : out std_logic;
        dat_o : out std_logic_vector(PHA_ACC_BITS-1 downto 0);
        sig_o : out std_logic_vector(OUT_RES_BITS-1 downto 0)
    );
end entity sig_gen;

architecture rtl of sig_gen is

    signal rst_n : std_logic;

    signal pha_inc : std_logic_vector(PHA_ACC_BITS-1 downto 0);

    signal pha_val : std_logic_vector(PHA_ACC_BITS-1 downto 0);

    signal addr : std_logic_vector(LUT_ADDR_BITS+1 downto 0);

begin

    rst_n <= not rst_i;

    u_sig_gen_wbif: sig_gen_wbif generic map (
        DATA_WIDTH => PHA_ACC_BITS
    ) port map (
        rst_i => rst_i,
        clk_i => clk_i,
        cyc_i => cyc_i,
        stb_i => stb_i,
        we_i  => we_i,
        sel_i => sel_i,
        dat_i => dat_i,
        ack_o => ack_o,
        dat_o => pha_inc
    );

    u_pha_acc : pha_acc generic map (
        PHA_ACC_BITS => PHA_ACC_BITS
    ) port map (
        clk_i => clk_i,
        rst_i => rst_i,
        inc_i => pha_inc,
        val_o => pha_val
    );

    addr <= pha_val(PHA_ACC_BITS-1 downto PHA_ACC_BITS-LUT_ADDR_BITS-2);

    u_sine_lut : sine_lut port map (
        rst_n  => rst_n,
        clk    => clk_i,
        addr   => addr,
        wave   => sig_o
    );

    dat_o <= pha_inc;

end architecture rtl;
