library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.sine_lut_pkg.all;

entity amp_scale is
    port (
        clk_i : in  std_logic;
        rst_i : in  std_logic;
        we_i  : in  std_logic;
        amp_i : in  std_logic_vector(OUT_RES_BITS-1 downto 0);
        sig_i : in  std_logic_vector(OUT_RES_BITS-1 downto 0);
        sig_o : out std_logic_vector(OUT_RES_BITS-1 downto 0)
    );
end entity amp_scale;

architecture rtl of amp_scale is

    signal amp_reg : std_logic_vector(OUT_RES_BITS-1 downto 0);

    signal mul_res : signed(2*OUT_RES_BITS downto 0);

    signal sig_reg : std_logic_vector(OUT_RES_BITS-1 downto 0);

begin

    amp_reg_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                amp_reg <= (others => '0');
            elsif we_i = '1' then
                amp_reg <= amp_i;
            end if;
        end if;
    end process amp_reg_proc;

    mul_res <= signed(sig_i) * signed('0' & amp_reg);

    sig_reg_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                sig_reg <= (others => '0');
            else
                sig_reg <= std_logic_vector(
                    resize(shift_right(mul_res, OUT_RES_BITS), OUT_RES_BITS)
                );
            end if;
        end if;
    end process sig_reg_proc;

    sig_o <= sig_reg;

end architecture rtl;
