library IEEE;
library work;
use IEEE.std_logic_1164.all;
use work.sine_lut_pkg.LUT_ADDR_BITS;
use work.sine_lut_pkg.OUT_RES_BITS;

package sig_gen_pkg is

    component sine_lut is
        port (
            rst_n : in  std_logic;
            clk   : in  std_logic;
            addr  : in  std_logic_vector(LUT_ADDR_BITS+1 downto 0);
            wave  : out std_logic_vector(OUT_RES_BITS-1 downto 0)
        );
    end component sine_lut;

    component pha_acc is
        generic (
            PHA_ACC_BITS : natural := 32
        );
        port (
            rst_n   : in  std_logic;
            clk     : in  std_logic;
            pha_inc : in  std_logic_vector(PHA_ACC_BITS-1 downto 0);
            pha_val : out std_logic_vector(PHA_ACC_BITS-1 downto 0)
        );
    end component pha_acc;

    component sig_gen is
        generic (
            PHA_ACC_BITS : natural := 32
        );
        port (
            rst_i : in  std_logic;
            clk_i : in  std_logic;
            cyc_i : in  std_logic;
            stb_i : in  std_logic;
            we_i  : in  std_logic;
            sel_i : in  std_logic_vector(PHA_ACC_BITS/8-1 downto 0);
            dat_i : in  std_logic_vector(PHA_ACC_BITS-1 downto 0);
            ack_o : out std_logic;
            dat_o : out std_logic_vector(PHA_ACC_BITS-1 downto 0)
        );
    end component sig_gen;

    component sig_gen_wbif is
        generic (
            DATA_WIDTH : natural := 32
        );
        port (
            rst_i : in  std_logic;
            clk_i : in  std_logic;
            cyc_i : in  std_logic;
            stb_i : in  std_logic;
            we_i  : in  std_logic;
            sel_i : in  std_logic_vector(DATA_WIDTH/8-1 downto 0);
            dat_i : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            ack_o : out std_logic;
            dat_o : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component sig_gen_wbif;

end package sig_gen_pkg;
