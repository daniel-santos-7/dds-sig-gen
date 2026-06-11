library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.sine_lut_pkg.OUT_RES_BITS;

entity iq_mod is
    port (
        clk_i    : in  std_logic;
        rst_i    : in  std_logic;
        gauss_i  : in  std_logic_vector(OUT_RES_BITS downto 0);
        drag_i   : in  std_logic_vector(OUT_RES_BITS downto 0);
        sine_i_i : in  std_logic_vector(OUT_RES_BITS-1 downto 0);
        sine_q_i : in  std_logic_vector(OUT_RES_BITS-1 downto 0);
        sig_i_o  : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        sig_q_o  : out std_logic_vector(OUT_RES_BITS-1 downto 0)
    );
end entity iq_mod;

architecture rtl of iq_mod is

    signal gauss_sgn : signed(OUT_RES_BITS downto 0);
    signal drag_sgn  : signed(OUT_RES_BITS downto 0);

    signal mul_i_i : signed(2*OUT_RES_BITS downto 0);
    signal mul_q_q : signed(2*OUT_RES_BITS downto 0);
    signal mul_i_q : signed(2*OUT_RES_BITS downto 0);
    signal mul_q_i : signed(2*OUT_RES_BITS downto 0);

    signal sum_i : signed(2*OUT_RES_BITS downto 0);
    signal sum_q : signed(2*OUT_RES_BITS downto 0);

    signal sig_i_reg : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal sig_q_reg : std_logic_vector(OUT_RES_BITS-1 downto 0);

begin

    gauss_sgn <= signed(gauss_i);
    drag_sgn  <= signed(drag_i);

    mul_i_i <= signed(sine_i_i) * gauss_sgn;
    mul_q_q <= signed(sine_q_i) * drag_sgn;
    mul_i_q <= signed(sine_i_i) * drag_sgn;
    mul_q_i <= signed(sine_q_i) * gauss_sgn;

    sum_i <= mul_i_i - mul_q_q;
    sum_q <= mul_q_i + mul_i_q;

    out_reg_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                sig_i_reg <= (others => '0');
                sig_q_reg <= (others => '0');
            else
                sig_i_reg <= std_logic_vector(sum_i(2*OUT_RES_BITS-1 downto OUT_RES_BITS));
                sig_q_reg <= std_logic_vector(sum_q(2*OUT_RES_BITS-1 downto OUT_RES_BITS));
            end if;
        end if;
    end process out_reg_proc;

    sig_i_o <= not sig_i_reg(OUT_RES_BITS-1) & sig_i_reg(OUT_RES_BITS-2 downto 0);
    sig_q_o <= not sig_q_reg(OUT_RES_BITS-1) & sig_q_reg(OUT_RES_BITS-2 downto 0);

end architecture rtl;
