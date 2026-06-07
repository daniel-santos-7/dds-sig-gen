library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.envelope_lut_pkg.all;

entity envelope_gen is
    port (
        clk_i        : in  std_logic;
        rst_i        : in  std_logic;
        trigger_i    : in  std_logic;
        step_i       : in  std_logic_vector(31 downto 0);
        drag_coeff_i : in  std_logic_vector(15 downto 0);
        
        env_i_o      : out std_logic_vector(15 downto 0);
        env_q_o      : out std_logic_vector(15 downto 0);
        active_o     : out std_logic
    );
end entity envelope_gen;

architecture rtl of envelope_gen is
    signal active : std_logic;
    signal acc    : unsigned(32 downto 0);
    
    signal gauss_val : std_logic_vector(ENV_OUT_RES_BITS-1 downto 0);
    signal drag_val  : std_logic_vector(ENV_OUT_RES_BITS-1 downto 0);
    
    signal addr      : unsigned(ENV_LUT_ADDR_BITS-1 downto 0);
    
    signal env_q_mult : signed(31 downto 0);
begin
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                active <= '0';
                acc <= (others => '0');
            else
                if trigger_i = '1' then
                    active <= '1';
                    acc <= (others => '0');
                elsif active = '1' then
                    acc <= acc + unsigned('0' & step_i);
                    if acc(32) = '1' then
                        active <= '0';
                        acc <= (others => '0');
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    active_o <= active;
    
    addr <= acc(31 downto 32-ENV_LUT_ADDR_BITS) when active = '1' else (others => '0');
    
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if active = '1' then
                gauss_val <= GAUSS_TABLE(to_integer(addr));
                drag_val  <= DRAG_TABLE(to_integer(addr));
            else
                gauss_val <= (others => '0');
                drag_val  <= (others => '0');
            end if;
        end if;
    end process;
    
    env_q_mult <= signed(drag_val) * signed(drag_coeff_i);
    
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            env_i_o <= gauss_val;
            env_q_o <= std_logic_vector(env_q_mult(30 downto 15));
        end if;
    end process;
    
end architecture rtl;
