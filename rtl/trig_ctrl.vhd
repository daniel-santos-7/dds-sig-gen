library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.envelope_lut_pkg.ENV_LUT_ADDR_BITS;

entity trig_ctrl is
    port (
        clk_i        : in  std_logic;
        rst_i        : in  std_logic;
        valid_i      : in  std_logic;
        delay_i      : in  std_logic_vector(23 downto 0);
        step_i       : in  std_logic_vector(31 downto 0);
        trigger_o    : out std_logic;
        env_addr_o   : out std_logic_vector(ENV_LUT_ADDR_BITS-1 downto 0);
        env_active_o : out std_logic;
        ready_o      : out std_logic
    );
end entity trig_ctrl;

architecture rtl of trig_ctrl is

    signal ready      : std_logic;
    signal env_cnt    : unsigned(32 downto 0);
    signal delay_cnt  : unsigned(23 downto 0);
    signal env_active : std_logic;
    signal env_done   : std_logic;
    signal delay_done : std_logic;

begin

    env_active_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                env_active <= '0';
            elsif valid_i = '1' and ready = '1' then
                env_active <= '1';
            elsif env_done = '1' then
                env_active <= '0';
            end if;
        end if;
    end process env_active_proc;

    env_cnt_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                env_cnt <= (32 => '1', others => '0');
            elsif valid_i = '1' and ready = '1' then
                env_cnt <= (others => '0');
            elsif env_active = '1' and env_done = '0' then
                env_cnt <= env_cnt + unsigned('0' & step_i);
            end if;
        end if;
    end process env_cnt_proc;

    delay_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                delay_cnt <= (others => '0');
            elsif valid_i = '1' and ready = '1' then
                delay_cnt <= unsigned(delay_i);
            elsif env_done = '1' and delay_done = '0' then
                delay_cnt <= delay_cnt - 1;
            end if;
        end if;
    end process delay_proc;

    env_done    <= env_cnt(32);
    delay_done  <= '1' when delay_cnt = 0 else '0';
    ready       <= '1' when env_active = '0' and delay_done = '1' else '0';

    ready_o      <= ready;
    trigger_o    <= valid_i and ready;
    env_addr_o   <= std_logic_vector(env_cnt(31 downto 32-ENV_LUT_ADDR_BITS)) when env_active = '1' else (others => '0');
    env_active_o <= env_active and not env_done;

end architecture rtl;