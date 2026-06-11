library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity trig_pending_ctrl is
    port (
        clk_i        : in  std_logic;
        rst_i        : in  std_logic;
        trig_i       : in  std_logic;
        delay_i      : in  std_logic_vector(23 downto 0);
        env_active_i : in  std_logic;
        pulse_o      : out std_logic;
        pending_o    : out std_logic
    );
end entity trig_pending_ctrl;

architecture rtl of trig_pending_ctrl is

    signal trig_pending   : std_logic;
    signal trig_pulse_del : std_logic;
    signal env_active_d   : std_logic;
    signal delay_counter  : unsigned(23 downto 0);

begin

    pulse_o <= (trig_i and not env_active_i and not trig_pending) or trig_pulse_del;
    pending_o <= trig_pending;

    env_edge_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            env_active_d <= env_active_i;
        end if;
    end process;

    pending_proc : process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            trig_pending   <= '0';
            delay_counter  <= (others => '0');
            trig_pulse_del <= '0';
        elsif rising_edge(clk_i) then
            trig_pulse_del <= '0';

            if trig_i = '1' and env_active_i = '1' then
                trig_pending <= '1';
            end if;

            if env_active_d = '1' and env_active_i = '0' and trig_pending = '1' then
                if unsigned(delay_i) = 0 then
                    trig_pulse_del <= '1';
                    trig_pending   <= '0';
                else
                    delay_counter <= unsigned(delay_i);
                end if;
            elsif delay_counter > 0 then
                delay_counter <= delay_counter - 1;
                if delay_counter = 1 then
                    trig_pulse_del <= '1';
                    trig_pending   <= '0';
                end if;
            end if;
        end if;
    end process;

end architecture rtl;
