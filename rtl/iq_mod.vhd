library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.sine_lut_pkg.OUT_RES_BITS;

entity iq_mod is
    port (
        clk_i   : in  std_logic;
        rst_i   : in  std_logic;
        gauss_i : in  std_logic_vector(OUT_RES_BITS downto 0);
        drag_i  : in  std_logic_vector(OUT_RES_BITS downto 0);
        sin_i   : in  std_logic_vector(OUT_RES_BITS-1 downto 0);
        cos_i   : in  std_logic_vector(OUT_RES_BITS-1 downto 0);
        sig_i_o : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        sig_q_o : out std_logic_vector(OUT_RES_BITS-1 downto 0)
    );
end entity iq_mod;

architecture rtl of iq_mod is

    signal gauss : signed(OUT_RES_BITS downto 0);
    signal drag  : signed(OUT_RES_BITS downto 0);

    signal sin_gauss_reg : signed(2*OUT_RES_BITS downto 0);
    signal cos_drag_reg  : signed(2*OUT_RES_BITS downto 0);
    signal sin_drag_reg  : signed(2*OUT_RES_BITS downto 0);
    signal cos_gauss_reg : signed(2*OUT_RES_BITS downto 0);

    signal sig_i : signed(2*OUT_RES_BITS downto 0);
    signal sig_q : signed(2*OUT_RES_BITS downto 0);

    signal i_reg : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal q_reg : std_logic_vector(OUT_RES_BITS-1 downto 0);

begin

    gauss <= signed(gauss_i);
    drag  <= signed(drag_i);

    mult_pipe_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            sin_gauss_reg <= signed(sin_i) * gauss;
            cos_drag_reg  <= signed(cos_i) * drag;
            sin_drag_reg  <= signed(sin_i) * drag;
            cos_gauss_reg <= signed(cos_i) * gauss;
        end if;
    end process mult_pipe_proc;

    sig_i <= cos_gauss_reg - sin_drag_reg;
    sig_q <= sin_gauss_reg + cos_drag_reg;

    sig_reg_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                i_reg <= (others => '0');
                q_reg <= (others => '0');
            else
                i_reg <= std_logic_vector(sig_i(2*OUT_RES_BITS-1 downto OUT_RES_BITS));
                q_reg <= std_logic_vector(sig_q(2*OUT_RES_BITS-1 downto OUT_RES_BITS));
            end if;
        end if;
    end process sig_reg_proc;

    sig_i_o <= i_reg;
    sig_q_o <= q_reg;

end architecture rtl;
