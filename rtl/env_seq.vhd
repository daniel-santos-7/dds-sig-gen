----------------------------------------------------------------------
-- DDS Signal Generator
-- developed by: Daniel Santos
-- module: env_seq
-- description: envelope address sequencer and pulse timing
-- license: MIT
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.envelope_lut_pkg.ENV_LUT_ADDR_BITS;

entity env_seq is
    generic (
        ENV_ACC_BITS : natural := 32
    );
    port (
        clk_i    : in  std_logic;
        rst_i    : in  std_logic;
        clr_i    : in  std_logic;
        en_i     : in  std_logic;
        step_i   : in  std_logic_vector(ENV_ACC_BITS-1 downto 0);
        addr_o   : out std_logic_vector(ENV_LUT_ADDR_BITS-1 downto 0);
        done_o   : out std_logic
    );
end entity env_seq;

architecture rtl of env_seq is

    signal env_cnt_inc  : unsigned(ENV_ACC_BITS-1 downto 0);
    signal env_cnt_val  : unsigned(ENV_ACC_BITS downto 0);
    signal env_cnt_reg  : unsigned(ENV_ACC_BITS-1 downto 0);
    signal env_cnt_done : std_logic;

begin

    env_cnt_inc  <= unsigned(step_i);
    env_cnt_val  <= ('0' & env_cnt_reg) + ('0' & env_cnt_inc);
    env_cnt_done <= env_cnt_val(ENV_ACC_BITS);

    env_cnt_reg_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                env_cnt_reg <= (others => '0');
            elsif clr_i = '1' then
                env_cnt_reg <= (others => '0');
            elsif en_i = '1' and env_cnt_done = '0' then
                env_cnt_reg <= env_cnt_val(ENV_ACC_BITS-1 downto 0);
            end if;
        end if;
    end process env_cnt_reg_proc;

    done_o <= env_cnt_done;
    addr_o <= std_logic_vector(env_cnt_reg(ENV_ACC_BITS-1 downto ENV_ACC_BITS-ENV_LUT_ADDR_BITS));

end architecture rtl;
