library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.envelope_lut_pkg.all;
use work.sine_lut_pkg.OUT_RES_BITS;

entity env_gen is
    generic (
        DRAG_DERIV_EN : boolean := true;
        DRAG_K_SHIFT  : natural := 6
    );
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

    function get_drag_bits return natural is
    begin
        if DRAG_DERIV_EN then
            return ENV_OUT_RES_BITS + DRAG_K_SHIFT;
        else
            return ENV_OUT_RES_BITS;
        end if;
    end function;

    constant DRAG_BITS : natural := get_drag_bits;

    signal lut_pha : std_logic;
    signal lut_adr : unsigned(ENV_LUT_ADDR_BITS-2 downto 0);

    signal gauss_reg : std_logic_vector(ENV_OUT_RES_BITS-1 downto 0);

    signal gauss : std_logic_vector(ENV_OUT_RES_BITS-1 downto 0);
    signal drag  : std_logic_vector(DRAG_BITS-1 downto 0);

    signal gauss_pipe_reg : std_logic_vector(ENV_OUT_RES_BITS-1 downto 0);
    signal drag_pipe_reg  : std_logic_vector(DRAG_BITS-1 downto 0);

    signal amp_mult   : unsigned(ENV_OUT_RES_BITS+15 downto 0);
    signal env_q_mult : signed(DRAG_BITS+15 downto 0);

    signal gauss_out_reg : std_logic_vector(OUT_RES_BITS downto 0);
    signal drag_out_reg  : std_logic_vector(OUT_RES_BITS downto 0);

begin

    lut_pha <= adr_i(ENV_LUT_ADDR_BITS-1);
    lut_adr <= not unsigned(adr_i(ENV_LUT_ADDR_BITS-2 downto 0)) when lut_pha = '1' else unsigned(adr_i(ENV_LUT_ADDR_BITS-2 downto 0));

    orig_gen: if not DRAG_DERIV_EN generate
        signal drag_reg    : std_logic_vector(ENV_OUT_RES_BITS-1 downto 0);
        signal lut_pha_reg : std_logic;
    begin
        phase_proc : process(clk_i)
        begin
            if rising_edge(clk_i) then
                if rst_i = '1' then
                    lut_pha_reg <= '0';
                else
                    lut_pha_reg <= lut_pha;
                end if;
            end if;
        end process phase_proc;

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
        drag  <= std_logic_vector(-signed(drag_reg)) when lut_pha_reg = '1' else drag_reg;
    end generate;

    deriv_gen: if DRAG_DERIV_EN generate
        signal gauss_prev : std_logic_vector(ENV_OUT_RES_BITS-1 downto 0);
        signal drag_diff  : signed(ENV_OUT_RES_BITS-1 downto 0);
    begin
        reg_proc: process(clk_i)
        begin
            if rising_edge(clk_i) then
                if active_i = '1' then
                    gauss_reg <= GAUSS_TABLE(to_integer(lut_adr));
                    gauss_prev <= gauss_reg;
                else
                    gauss_reg <= (others => '0');
                    gauss_prev <= (others => '0');
                end if;
            end if;
        end process reg_proc;
        
        gauss <= gauss_reg;
        drag_diff <= signed(gauss_reg) - signed(gauss_prev);
        drag <= std_logic_vector(resize(drag_diff, DRAG_BITS) sll DRAG_K_SHIFT);
    end generate;

    neg_pipe_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                gauss_pipe_reg <= (others => '0');
                drag_pipe_reg  <= (others => '0');
            else
                gauss_pipe_reg <= gauss;
                drag_pipe_reg  <= drag;
            end if;
        end if;
    end process neg_pipe_proc;

    amp_mult <= unsigned(gauss_pipe_reg) * unsigned(amp_i);
    env_q_mult <= signed(drag_pipe_reg) * signed(drag_i);

    out_reg_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                gauss_out_reg <= (others => '0');
                drag_out_reg  <= (others => '0');
            else
                gauss_out_reg <= '0' & std_logic_vector(amp_mult(ENV_OUT_RES_BITS+14 downto ENV_OUT_RES_BITS+15-OUT_RES_BITS));
                drag_out_reg  <= std_logic_vector(env_q_mult(ENV_OUT_RES_BITS+14 downto ENV_OUT_RES_BITS+15-OUT_RES_BITS-1));
            end if;
        end if;
    end process out_reg_proc;

    gauss_o <= gauss_out_reg;
    drag_o  <= drag_out_reg;

end architecture rtl;