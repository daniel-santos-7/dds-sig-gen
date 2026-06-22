library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.sine_lut_pkg.all;

entity sin_pac is
    port (
        rst_i : in  std_logic;
        clk_i : in  std_logic;
        adr_i : in  std_logic_vector(LUT_ADDR_BITS+1 downto 0);
        sin_o : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        cos_o : out std_logic_vector(OUT_RES_BITS-1 downto 0)
    );
end entity sin_pac;

architecture rtl of sin_pac is

    signal sin_pointer : std_logic_vector(LUT_ADDR_BITS-1 downto 0);
    signal cos_pointer : std_logic_vector(LUT_ADDR_BITS-1 downto 0);
    
    signal sin_neg : std_logic;
    signal cos_neg : std_logic;

    signal sin_val_reg : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal cos_val_reg : std_logic_vector(OUT_RES_BITS-1 downto 0);

    signal sin_neg_reg : std_logic;
    signal cos_neg_reg : std_logic;

    signal sin_mux : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal cos_mux : std_logic_vector(OUT_RES_BITS-1 downto 0);

    signal sin_reg : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal cos_reg : std_logic_vector(OUT_RES_BITS-1 downto 0);

begin

    sin_pointer <= not adr_i(LUT_ADDR_BITS-1 downto 0) when adr_i(LUT_ADDR_BITS) = '1' else adr_i(LUT_ADDR_BITS-1 downto 0);
    cos_pointer <= not adr_i(LUT_ADDR_BITS-1 downto 0) when adr_i(LUT_ADDR_BITS) = '0' else adr_i(LUT_ADDR_BITS-1 downto 0);

    sin_neg <= adr_i(LUT_ADDR_BITS + 1);
    cos_neg <= adr_i(LUT_ADDR_BITS + 1) xor adr_i(LUT_ADDR_BITS);

    val_reg_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                sin_val_reg <= (others => '0');
                cos_val_reg <= (others => '0');
            else
                sin_val_reg <= SINE_TABLE(to_integer(unsigned(sin_pointer)));
                cos_val_reg <= SINE_TABLE(to_integer(unsigned(cos_pointer)));
            end if;
        end if;
    end process val_reg_proc;

    neg_reg_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                sin_neg_reg <= '0';
                cos_neg_reg <= '0';
            else
                sin_neg_reg <= sin_neg;
                cos_neg_reg <= cos_neg;
            end if;
        end if;
    end process neg_reg_proc;

    sin_mux <= std_logic_vector(unsigned(not sin_val_reg) + 1) when sin_neg_reg = '1' else sin_val_reg;
    cos_mux <= std_logic_vector(unsigned(not cos_val_reg) + 1) when cos_neg_reg = '1' else cos_val_reg;

    reg_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                sin_reg <= (others => '0');
                cos_reg <= (others => '0');
            else
                sin_reg <= sin_mux;
                cos_reg <= cos_mux;
            end if;
        end if;
    end process reg_proc;

    sin_o <= sin_reg;
    cos_o <= cos_reg;

end architecture rtl;
