library IEEE;
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
        we_i  : in  std_logic;
        inc_i : in  std_logic_vector(PHA_ACC_BITS-1 downto 0);
        pha_i : in  std_logic_vector(PHA_ACC_BITS-1 downto 0);
        amp_i : in  std_logic_vector(OUT_RES_BITS-1 downto 0);
        sig_o : out std_logic_vector(OUT_RES_BITS-1 downto 0)
    );
end entity sig_gen;

architecture rtl of sig_gen is

    signal pha_val : std_logic_vector(PHA_ACC_BITS-1 downto 0);

    signal addr : std_logic_vector(LUT_ADDR_BITS+1 downto 0);

    signal sine : std_logic_vector(OUT_RES_BITS-1 downto 0);

begin

    u_pha_acc : pha_acc generic map (
        PHA_ACC_BITS => PHA_ACC_BITS
    ) port map (
        clk_i => clk_i,
        rst_i => rst_i,
        we_i  => we_i,
        inc_i => inc_i,
        pha_i => pha_i,
        val_o => pha_val
    );

    addr <= pha_val(PHA_ACC_BITS-1 downto PHA_ACC_BITS-LUT_ADDR_BITS-2);

    u_sine_lut : sine_lut port map (
        rst_i => rst_i,
        clk_i => clk_i,
        adr_i => addr,
        sig_o => sine
    );

    u_amp_scale : amp_scale port map (
        clk_i => clk_i,
        rst_i => rst_i,
        we_i  => we_i,
        amp_i => amp_i,
        sig_i => sine,
        sig_o => sig_o
    );

end architecture rtl;
