library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pha_acc is
    generic (
        PHA_ACC_BITS : natural := 32
    );
    port (
        clk_i  : in  std_logic;
        rst_i  : in  std_logic;
        sync_i : in  std_logic;
        ftw_i  : in  std_logic_vector(PHA_ACC_BITS-1 downto 0);
        pow_i  : in  std_logic_vector(PHA_ACC_BITS-1 downto 0);
        val_o  : out std_logic_vector(PHA_ACC_BITS-1 downto 0)
    );
end entity pha_acc;

architecture rtl of pha_acc is

    signal ftw_reg : std_logic_vector(PHA_ACC_BITS-1 downto 0);
    signal acc_reg : std_logic_vector(PHA_ACC_BITS-1 downto 0);
    signal pow_reg : std_logic_vector(PHA_ACC_BITS-1 downto 0);

begin

    ftw_reg_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                ftw_reg <= (others => '0');
                pow_reg <= (others => '0');
            elsif sync_i = '1' then
                ftw_reg <= ftw_i;
                pow_reg <= pow_i;
            end if;
        end if;
    end process ftw_reg_proc;

    acc_reg_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                acc_reg <= (others => '0');
            elsif sync_i = '1' then
                acc_reg <= (others => '0');
            else
                acc_reg <= std_logic_vector(unsigned(acc_reg) + unsigned(ftw_reg));
            end if;
        end if;
    end process acc_reg_proc;

    val_o <= std_logic_vector(unsigned(acc_reg) + unsigned(pow_reg));

end architecture rtl;
