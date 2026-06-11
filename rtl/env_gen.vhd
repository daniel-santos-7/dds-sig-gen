library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.envelope_lut_pkg.all;
use work.sine_lut_pkg.OUT_RES_BITS;

entity env_gen is
    port (
        clk_i        : in  std_logic;
        rst_i        : in  std_logic;
        addr_i       : in  std_logic_vector(ENV_LUT_ADDR_BITS-1 downto 0);
        active_i     : in  std_logic;
        drag_coeff_i : in  std_logic_vector(15 downto 0);
        amp_i        : in  std_logic_vector(15 downto 0);
        gauss_o      : out std_logic_vector(OUT_RES_BITS downto 0);
        drag_o       : out std_logic_vector(OUT_RES_BITS downto 0)
    );
end entity env_gen;

architecture rtl of env_gen is

    signal gauss_val : std_logic_vector(ENV_OUT_RES_BITS-1 downto 0);
    signal drag_val  : std_logic_vector(ENV_OUT_RES_BITS-1 downto 0);

    signal addr      : unsigned(ENV_LUT_ADDR_BITS-1 downto 0);

    signal mirror_addr : unsigned(ENV_LUT_ADDR_BITS-1 downto 0);
    signal eff_addr    : unsigned(ENV_LUT_ADDR_BITS-2 downto 0);
    signal drag_neg_s  : std_logic;

    signal gauss_raw : std_logic_vector(ENV_OUT_RES_BITS-1 downto 0);
    signal drag_raw  : std_logic_vector(ENV_OUT_RES_BITS-1 downto 0);

    signal amp_mult   : unsigned(ENV_OUT_RES_BITS+15 downto 0);
    signal env_q_mult : signed(ENV_OUT_RES_BITS+15 downto 0);

begin

    addr <= unsigned(addr_i);

    mirror_addr <= to_unsigned(2**ENV_LUT_ADDR_BITS - 1, ENV_LUT_ADDR_BITS) - addr;
    eff_addr    <= addr(ENV_LUT_ADDR_BITS-2 downto 0) when addr(ENV_LUT_ADDR_BITS-1) = '0'
                   else mirror_addr(ENV_LUT_ADDR_BITS-2 downto 0);
    drag_neg_s  <= addr(ENV_LUT_ADDR_BITS-1);

    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if active_i = '1' then
                gauss_raw <= GAUSS_TABLE(to_integer(eff_addr));
                drag_raw  <= DRAG_TABLE(to_integer(eff_addr));
            else
                gauss_raw <= (others => '0');
                drag_raw  <= (others => '0');
            end if;
        end if;
    end process;

    gauss_val <= gauss_raw;
    drag_val  <= std_logic_vector(-signed(drag_raw)) when drag_neg_s = '1' else drag_raw;

    amp_mult <= unsigned(gauss_val) * unsigned(amp_i);
    env_q_mult <= signed(drag_val) * signed(drag_coeff_i);

    gauss_o <= '0' & std_logic_vector(amp_mult(ENV_OUT_RES_BITS+15 downto ENV_OUT_RES_BITS+15-OUT_RES_BITS+1));
    drag_o  <= std_logic_vector(env_q_mult(ENV_OUT_RES_BITS+15 downto ENV_OUT_RES_BITS+15-OUT_RES_BITS));

end architecture rtl;
