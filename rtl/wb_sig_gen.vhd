library IEEE;
use IEEE.std_logic_1164.all;
use work.sig_gen_pkg.all;
use work.sine_lut_pkg.OUT_RES_BITS;

entity wb_sig_gen is
    generic (
        DATA_WIDTH   : natural := 32;
        ADDR_WIDTH   : natural := 3;
        PHA_ACC_BITS : natural := 32
    );
    port (
        rst_i    : in  std_logic;
        clk_i    : in  std_logic;
        adr_i    : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        cyc_i    : in  std_logic;
        stb_i    : in  std_logic;
        we_i     : in  std_logic;
        sel_i    : in  std_logic_vector(DATA_WIDTH/8-1 downto 0);
        dat_i    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        ack_o    : out std_logic;
        dat_o    : out std_logic_vector(DATA_WIDTH-1 downto 0);
        sig_i_o  : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        sig_q_o  : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        active_o : out std_logic
    );
end entity wb_sig_gen;

architecture rtl of wb_sig_gen is

    signal ftw    : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal pow    : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal amp    : std_logic_vector(15 downto 0);
    signal env    : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal drag   : std_logic_vector(15 downto 0);
    signal valid  : std_logic;
    signal start  : std_logic;
    signal delay  : std_logic_vector(23 downto 0);
    signal ready      : std_logic;
    signal pend : std_logic_vector(3 downto 0) := (others => '0');

begin

    wb_sig_gen_sig_gen_csrs : entity work.sig_gen_csrs generic map (
        DATA_WIDTH => DATA_WIDTH
    ) port map (
        rst_i   => rst_i,
        clk_i   => clk_i,
        adr_i   => adr_i,
        cyc_i   => cyc_i,
        stb_i   => stb_i,
        we_i    => we_i,
        sel_i   => sel_i,
        dat_i   => dat_i,
        ack_o   => ack_o,
        dat_o   => dat_o,
        ftw_o   => ftw,
        pow_o   => pow,
        amp_o   => amp,
        env_o   => env,
        drag_o  => drag,
        valid_o => valid,
        start_o => start,
        delay_o => delay,
        ready_i      => ready,
        pend_i => pend
    );

    wb_sig_gen_sig_gen : entity work.sig_gen generic map (
        PHA_ACC_BITS => PHA_ACC_BITS
    ) port map (
        clk_i        => clk_i,
        rst_i        => rst_i,
        start_i      => start,
        ftw_i        => ftw(PHA_ACC_BITS-1 downto 0),
        pow_i        => pow(PHA_ACC_BITS-1 downto 0),
        amp_i        => amp,
        env_i        => env,
        drag_i       => drag,
        valid_i      => valid,
        delay_i      => delay,
        ready_o      => ready,
        sig_i_o      => sig_i_o,
        sig_q_o      => sig_q_o,
        active_o     => active_o
    );

end architecture rtl;
