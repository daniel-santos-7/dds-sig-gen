library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pha_acc is
    generic (
        PHA_ACC_BITS : natural := 32
    );
    port (
        clk_i : in  std_logic;
        rst_i : in  std_logic;
        inc_i : in  std_logic_vector(PHA_ACC_BITS-1 downto 0);
        val_o : out std_logic_vector(PHA_ACC_BITS-1 downto 0)
    );
end entity pha_acc;

architecture rtl of pha_acc is

    signal pha_reg : std_logic_vector(PHA_ACC_BITS-1 downto 0);

begin

    pha_reg_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                pha_reg <= (others => '0');
            else
                pha_reg <= std_logic_vector(unsigned(pha_reg) + unsigned(inc_i));
            end if;
        end if;
    end process pha_reg_proc; -- pha_reg_proc

    val_o <= pha_reg;

end architecture rtl;