library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.envelope_lut_pkg.ENV_LUT_ADDR_BITS;

entity env_seq is
    port (
        clk_i    : in  std_logic;
        rst_i    : in  std_logic;
        clr_i    : in  std_logic;
        en_i     : in  std_logic;
        step_i   : in  std_logic_vector(31 downto 0);
        addr_o   : out std_logic_vector(ENV_LUT_ADDR_BITS-1 downto 0);
        done_o   : out std_logic
    );
end entity env_seq;

architecture rtl of env_seq is

    signal env_cnt_inc  : unsigned(32 downto 0);
    signal env_cnt_val  : unsigned(32 downto 0);
    signal env_cnt_reg  : unsigned(32 downto 0);
    signal env_cnt_done : std_logic;

begin

    env_cnt_inc  <= unsigned('0' & step_i);
    env_cnt_val  <= env_cnt_reg + env_cnt_inc;
    env_cnt_done <= env_cnt_reg(32);

    env_cnt_reg_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                env_cnt_reg <= (32 => '1', others => '0');
            elsif en_i = '1' then
                if clr_i = '1' then
                    env_cnt_reg <= (others => '0');
                elsif env_cnt_done = '0' then
                    if env_cnt_val(32) = '1' then
                        env_cnt_reg <= (32 => env_cnt_val(32), others => '0');
                    else
                        env_cnt_reg <= env_cnt_val;
                    end if;
                end if;
            end if;
        end if;
    end process env_cnt_reg_proc;

    done_o <= env_cnt_done;
    addr_o <= std_logic_vector(env_cnt_reg(31 downto 32-ENV_LUT_ADDR_BITS));

end architecture rtl;