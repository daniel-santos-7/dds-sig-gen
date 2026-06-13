library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.envelope_lut_pkg.all;
use work.sine_lut_pkg.OUT_RES_BITS;

entity env_gen is
    port (
        clk_i    : in  std_logic;
        rst_i    : in  std_logic;
        adr_i    : in  std_logic_vector(ENV_LUT_ADDR_BITS-1 downto 0);
        active_i : in  std_logic;
        drag_i   : in  std_logic_vector(15 downto 0);
        amp_i    : in  std_logic_vector(15 downto 0);
        gauss_o  : out std_logic_vector(OUT_RES_BITS downto 0);
        drag_o   : out std_logic_vector(OUT_RES_BITS downto 0)
    );
end entity env_gen;

architecture rtl of env_gen is

    signal lut_pha : std_logic;
    signal lut_adr : unsigned(ENV_LUT_ADDR_BITS-2 downto 0);

    signal gauss_reg : std_logic_vector(ENV_OUT_RES_BITS-1 downto 0);
    signal drag_reg  : std_logic_vector(ENV_OUT_RES_BITS-1 downto 0);

    signal gauss : std_logic_vector(ENV_OUT_RES_BITS-1 downto 0);
    signal drag  : std_logic_vector(ENV_OUT_RES_BITS-1 downto 0);

    signal amp_mult   : unsigned(ENV_OUT_RES_BITS+15 downto 0);
    signal env_q_mult : signed(ENV_OUT_RES_BITS+32 downto 0);

begin

    lut_pha <= adr_i(ENV_LUT_ADDR_BITS-1);
    lut_adr  <= not unsigned(adr_i(ENV_LUT_ADDR_BITS-2 downto 0)) when lut_pha = '1' else unsigned(adr_i(ENV_LUT_ADDR_BITS-2 downto 0));

    reg_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if active_i = '1' then
                gauss_reg <= GAUSS_TABLE(to_integer(lut_adr));
                drag_reg  <= DRAG_TABLE(to_integer(lut_adr));
            else
                gauss_reg <= (others => '0');
                drag_reg  <= (others => '0');
            end if;
        end if;
    end process reg_proc;

    gauss <= gauss_reg;
    drag  <= std_logic_vector(-signed(drag_reg)) when lut_pha = '1' else drag_reg;

    amp_mult <= unsigned(gauss) * unsigned(amp_i);
    env_q_mult <= signed(drag) * signed('0' & amp_i) * signed(drag_i);

    gauss_o <= '0' & std_logic_vector(amp_mult(ENV_OUT_RES_BITS+14 downto ENV_OUT_RES_BITS+15-OUT_RES_BITS));
    drag_o  <= std_logic_vector(env_q_mult(ENV_OUT_RES_BITS+30 downto ENV_OUT_RES_BITS+31-OUT_RES_BITS-1));

end architecture rtl;