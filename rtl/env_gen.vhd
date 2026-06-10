library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.envelope_lut_pkg.all;
use work.sine_lut_pkg.OUT_RES_BITS;

entity env_gen is
    port (
        clk_i        : in  std_logic;
        rst_i        : in  std_logic;
        trigger_i    : in  std_logic;
        step_i       : in  std_logic_vector(31 downto 0);
        drag_coeff_i : in  std_logic_vector(15 downto 0);
        amp_i        : in  std_logic_vector(15 downto 0);

        sine_i_i     : in  std_logic_vector(OUT_RES_BITS-1 downto 0);
        sine_q_i     : in  std_logic_vector(OUT_RES_BITS-1 downto 0);

        sig_i_o      : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        sig_q_o      : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        active_o     : out std_logic
    );
end entity env_gen;

architecture rtl of env_gen is

    signal active : std_logic;
    signal acc    : unsigned(32 downto 0);

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

    mirror_addr <= to_unsigned(2**ENV_LUT_ADDR_BITS - 1, ENV_LUT_ADDR_BITS) - addr;
    eff_addr    <= addr(ENV_LUT_ADDR_BITS-2 downto 0) when addr(ENV_LUT_ADDR_BITS-1) = '0'
                   else mirror_addr(ENV_LUT_ADDR_BITS-2 downto 0);
    drag_neg_s  <= addr(ENV_LUT_ADDR_BITS-1);

    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if active = '1' then
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

    gauss_sgn <= signed('0' & amp_mult(ENV_OUT_RES_BITS+15 downto ENV_OUT_RES_BITS+15-OUT_RES_BITS+1));
    drag_sgn  <= env_q_mult(ENV_OUT_RES_BITS+15 downto ENV_OUT_RES_BITS+15-OUT_RES_BITS);

    mul_i_i <= signed(sine_i_i) * gauss_sgn;
    mul_q_q <= signed(sine_q_i) * drag_sgn;
    mul_i_q <= signed(sine_i_i) * drag_sgn;
    mul_q_i <= signed(sine_q_i) * gauss_sgn;

    sum_i <= mul_i_i - mul_q_q;
    sum_q <= mul_q_i + mul_i_q;

    process(clk_i)
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
    end process;

    sig_i_o <= not sig_i_reg(OUT_RES_BITS-1) & sig_i_reg(OUT_RES_BITS-2 downto 0);
    sig_q_o <= not sig_q_reg(OUT_RES_BITS-1) & sig_q_reg(OUT_RES_BITS-2 downto 0);

end architecture rtl;
