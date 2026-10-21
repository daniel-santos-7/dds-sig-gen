----------------------------------------------------------------------
-- DDS Signal Generator
-- developed by: Daniel Santos
-- module: sin_pac
-- description: quarter-wave LUT sine and cosine reconstruction
-- license: MIT
----------------------------------------------------------------------

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

    signal sin_pipe_reg : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal cos_pipe_reg : std_logic_vector(OUT_RES_BITS-1 downto 0);

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

    pipe_reg_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                sin_pipe_reg <= (others => '0');
                cos_pipe_reg <= (others => '0');
            else
                sin_pipe_reg <= sin_reg;
                cos_pipe_reg <= cos_reg;
            end if;
        end if;
    end process pipe_reg_proc;

    sin_o <= sin_pipe_reg;
    cos_o <= cos_pipe_reg;

end architecture rtl;

-- The sine and cosine pointers are always complementary (k and N-1-k), so
-- one of them indexes the lower half of SINE_TABLE and the other the upper
-- half. Each half is read once per cycle, which costs one table's worth of
-- logic instead of two; the octant bit then swaps the pair into sin/cos.

architecture octant of sin_pac is

    signal oct : std_logic;
    signal row : std_logic_vector(LUT_ADDR_BITS-2 downto 0);

    signal swap    : std_logic;
    signal sin_neg : std_logic;
    signal cos_neg : std_logic;

    signal row_reg     : std_logic_vector(LUT_ADDR_BITS-2 downto 0);
    signal swap_reg    : std_logic;
    signal sin_neg_reg : std_logic;
    signal cos_neg_reg : std_logic;

    signal lo_val_reg   : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal hi_val_reg   : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal swap_val_reg : std_logic;
    signal sin_neg_val_reg : std_logic;
    signal cos_neg_val_reg : std_logic;

    signal sin_val : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal cos_val : std_logic_vector(OUT_RES_BITS-1 downto 0);

    signal sin_mux : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal cos_mux : std_logic_vector(OUT_RES_BITS-1 downto 0);

    signal sin_reg : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal cos_reg : std_logic_vector(OUT_RES_BITS-1 downto 0);

begin

    oct <= adr_i(LUT_ADDR_BITS-1);
    row <= not adr_i(LUT_ADDR_BITS-2 downto 0) when oct = '1' else adr_i(LUT_ADDR_BITS-2 downto 0);

    swap    <= oct xor adr_i(LUT_ADDR_BITS);
    sin_neg <= adr_i(LUT_ADDR_BITS + 1);
    cos_neg <= adr_i(LUT_ADDR_BITS + 1) xor adr_i(LUT_ADDR_BITS);

    adr_reg_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                row_reg     <= (others => '0');
                swap_reg    <= '0';
                sin_neg_reg <= '0';
                cos_neg_reg <= '0';
            else
                row_reg     <= row;
                swap_reg    <= swap;
                sin_neg_reg <= sin_neg;
                cos_neg_reg <= cos_neg;
            end if;
        end if;
    end process adr_reg_proc;

    val_reg_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                lo_val_reg      <= (others => '0');
                hi_val_reg      <= (others => '0');
                swap_val_reg    <= '0';
                sin_neg_val_reg <= '0';
                cos_neg_val_reg <= '0';
            else
                lo_val_reg      <= SINE_TABLE(to_integer(unsigned('0' & row_reg)));
                hi_val_reg      <= SINE_TABLE(to_integer(unsigned('1' & not row_reg)));
                swap_val_reg    <= swap_reg;
                sin_neg_val_reg <= sin_neg_reg;
                cos_neg_val_reg <= cos_neg_reg;
            end if;
        end if;
    end process val_reg_proc;

    sin_val <= hi_val_reg when swap_val_reg = '1' else lo_val_reg;
    cos_val <= lo_val_reg when swap_val_reg = '1' else hi_val_reg;

    sin_mux <= std_logic_vector(unsigned(not sin_val) + 1) when sin_neg_val_reg = '1' else sin_val;
    cos_mux <= std_logic_vector(unsigned(not cos_val) + 1) when cos_neg_val_reg = '1' else cos_val;

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

end architecture octant;
