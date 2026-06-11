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
        pulse_o      : out std_logic;
        ready_o      : out std_logic
    );
end entity trig_ctrl;

architecture rtl of trig_ctrl is

    type state_t is (IDLE, PENDING, DELAY);
    signal state       : state_t;
    signal valid_prev  : std_logic;
    signal counter     : unsigned(23 downto 0);

begin

    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                state      <= IDLE;
                valid_prev <= '0';
                counter    <= (others => '0');
                pulse_o    <= '0';
                ready_o    <= '1';
            else
                pulse_o    <= '0';
                valid_prev <= valid_i;
                ready_o    <= '1';

                case state is
                    when IDLE =>
                        if valid_i = '1' and valid_prev = '0' then
                            if env_active_i = '0' then
                                pulse_o <= '1';
                            else
                                state   <= PENDING;
                                ready_o <= '0';
                            end if;
                        end if;

                    when PENDING =>
                        if env_active_i = '0' then
                            if unsigned(delay_i) = 0 then
                                pulse_o <= '1';
                                state   <= IDLE;
                            else
                                counter <= unsigned(delay_i);
                                state   <= DELAY;
                                ready_o <= '0';
                            end if;
                        else
                            ready_o <= '0';
                        end if;

                    when DELAY =>
                        if counter = 1 then
                            pulse_o <= '1';
                            state   <= IDLE;
                        else
                            counter <= counter - 1;
                            ready_o <= '0';
                        end if;
                end case;
            end if;
        end if;
    end process;

end architecture rtl;
