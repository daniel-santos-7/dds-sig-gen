library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity trig_ctrl is
    port (
        clk_i        : in  std_logic;
        rst_i        : in  std_logic;
        valid_i      : in  std_logic;
        delay_i      : in  std_logic_vector(23 downto 0);
        env_active_i : in  std_logic;
        ready_o      : out std_logic
    );
end entity trig_ctrl;

architecture rtl of trig_ctrl is

    signal counter : unsigned(23 downto 0);

begin

    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                counter <= (others => '0');
            else
                if counter = 0 then
                    if valid_i = '1' and env_active_i = '0' then
                        counter <= unsigned(delay_i);
                    end if;
                elsif env_active_i = '0' then
                    counter <= counter - 1;
                end if;
            end if;
        end if;
    end process;

    ready_o <= '0' when (counter = 0 and valid_i = '1' and env_active_i = '1') or (counter /= 0 and env_active_i = '0') else '1';

end architecture rtl;
