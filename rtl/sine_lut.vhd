library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.sine_lut_pkg.all;

entity sine_lut is
    port (
        rst_i : in  std_logic;
        clk_i : in  std_logic;
        adr_i : in  std_logic_vector(LUT_ADDR_BITS+1 downto 0);
        sig_o : out std_logic_vector(OUT_RES_BITS-1 downto 0)
    );
end entity sine_lut;

architecture rtl of sine_lut is

    signal pointer : std_logic_vector(LUT_ADDR_BITS-1 downto 0);

    signal sine_val : std_logic_vector(OUT_RES_BITS-1 downto 0);

    signal wave_reg : std_logic_vector(OUT_RES_BITS-1 downto 0);

    signal wave_mux : std_logic_vector(OUT_RES_BITS-1 downto 0);

begin

    pointer <= not adr_i(LUT_ADDR_BITS-1 downto 0) when adr_i(LUT_ADDR_BITS) = '1' else adr_i(LUT_ADDR_BITS-1 downto 0);

    sine_val <= SINE_TABLE(to_integer(unsigned(pointer)));

    wave_mux <= std_logic_vector(unsigned(not sine_val) + 1) when adr_i(LUT_ADDR_BITS + 1) = '1' else sine_val;

    wave_reg_proc : process(rst_i, clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                wave_reg <= (others => '0');
            else
                wave_reg <= wave_mux;
            end if;
        end if ;
    end process wave_reg_proc; -- wave_reg_logic

    -- Assign register to output
    sig_o <= wave_reg;

end architecture rtl;
