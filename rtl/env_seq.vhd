library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.envelope_lut_pkg.ENV_LUT_ADDR_BITS;

entity env_seq is
    port (
        clk_i    : in  std_logic;
        rst_i    : in  std_logic;
        valid_i  : in  std_logic;
        delay_i  : in  std_logic_vector(23 downto 0);
        step_i   : in  std_logic_vector(31 downto 0);
        sync_o   : out std_logic;
        addr_o   : out std_logic_vector(ENV_LUT_ADDR_BITS-1 downto 0);
        active_o : out std_logic;
        ready_o  : out std_logic
    );
end entity env_seq;

architecture rtl of env_seq is

    signal ready : std_logic;
    
    signal env_cnt_inc  : unsigned(32 downto 0);
    signal env_cnt_val  : unsigned(32 downto 0);
    signal env_cnt_reg  : unsigned(32 downto 0);
    signal env_cnt_done : std_logic;
    
    signal delay_cnt_reg  : unsigned(23 downto 0);
    signal delay_cnt_done : std_logic;

begin

    env_cnt_inc <= unsigned('0' & step_i);
    env_cnt_val <= env_cnt_reg + env_cnt_inc;

    env_cnt_reg_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                env_cnt_reg <= (32 => '1', others => '0');
            elsif valid_i = '1' and ready = '1' then
                env_cnt_reg <= (others => '0');
            elsif env_cnt_done = '0' then
                if env_cnt_val(32) = '1' then
                    env_cnt_reg <= (32 => env_cnt_val(32), others => '0');
                else
                    env_cnt_reg <= env_cnt_val;
                end if;
            end if;
        end if;
    end process env_cnt_reg_proc;

    env_cnt_done <= env_cnt_reg(32);

    delay_cnt_reg_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                delay_cnt_reg <= (others => '0');
            elsif valid_i = '1' and ready = '1' then
                delay_cnt_reg <= unsigned(delay_i);
            elsif env_cnt_done = '1' and delay_cnt_done = '0' then
                delay_cnt_reg <= delay_cnt_reg - 1;
            end if;
        end if;
    end process delay_cnt_reg_proc;

    delay_cnt_done <= '1' when delay_cnt_reg = 0 else '0';
    
    sync_o   <= valid_i and ready;
    active_o <= not env_cnt_done;
    ready    <= env_cnt_done and delay_cnt_done;
    ready_o  <= ready;
    addr_o   <= std_logic_vector(env_cnt_reg(31 downto 32-ENV_LUT_ADDR_BITS));

end architecture rtl;