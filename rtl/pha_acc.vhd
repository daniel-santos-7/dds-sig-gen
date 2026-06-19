library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.sine_lut_pkg.LUT_ADDR_BITS;

entity pha_acc is
    generic (
        PHA_ACC_BITS : natural := 32
    );
    port (
        clk_i  : in  std_logic;
        rst_i  : in  std_logic;
        clr_i : in  std_logic;
        en_i  : in  std_logic;
        ftw_i  : in  std_logic_vector(PHA_ACC_BITS-1 downto 0);
        pow_i  : in  std_logic_vector(PHA_ACC_BITS-1 downto 0);
        adr_o  : out std_logic_vector(LUT_ADDR_BITS+1 downto 0)
    );
end entity pha_acc;

architecture rtl of pha_acc is

    signal ftw     : unsigned(PHA_ACC_BITS-1 downto 0);
    signal pow     : unsigned(PHA_ACC_BITS-1 downto 0);
    signal acc_reg : unsigned(PHA_ACC_BITS-1 downto 0);
    signal acc_val : unsigned(PHA_ACC_BITS-1 downto 0);

begin

    ftw  <= unsigned(ftw_i);
    pow  <= unsigned(pow_i);

    acc_reg_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                acc_reg <= (others => '0');
            elsif clr_i = '1' then
                acc_reg <= (others => '0');
            elsif en_i = '1' then
                acc_reg <= acc_reg + ftw;
            end if;
        end if;
    end process acc_reg_proc;

    acc_val <= acc_reg + pow;
    adr_o   <= std_logic_vector(acc_val(PHA_ACC_BITS-1 downto PHA_ACC_BITS-LUT_ADDR_BITS-2));

end architecture rtl;
