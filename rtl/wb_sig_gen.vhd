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
        rst_i : in  std_logic;
        clk_i : in  std_logic;
        adr_i : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        cyc_i : in  std_logic;
        stb_i : in  std_logic;
        we_i  : in  std_logic;
        sel_i : in  std_logic_vector(DATA_WIDTH/8-1 downto 0);
        dat_i : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        ack_o : out std_logic;
        dat_o : out std_logic_vector(DATA_WIDTH-1 downto 0);
        
        sig_i_o  : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        sig_q_o  : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        active_o : out std_logic
    );
end entity wb_sig_gen;

architecture rtl of wb_sig_gen is

    signal csr_ftw     : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal csr_pow     : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal csr_amp     : std_logic_vector(15 downto 0);
    signal csr_env     : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal csr_drag    : std_logic_vector(15 downto 0);
    signal csr_valid   : std_logic;
    signal csr_delay   : std_logic_vector(23 downto 0);
    signal trig_ready  : std_logic;

begin

    csrs : sig_gen_csrs generic map (
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
        ftw_o   => csr_ftw,
        pow_o   => csr_pow,
        amp_o   => csr_amp,
        env_o   => csr_env,
        drag_o  => csr_drag,
        valid_o => csr_valid,
        delay_o => csr_delay,
        ready_i => trig_ready
    );

    dds : sig_gen generic map (
        PHA_ACC_BITS => PHA_ACC_BITS
    ) port map (
        clk_i      => clk_i,
        rst_i      => rst_i,
        csr_ftw    => csr_ftw,
        csr_pow    => csr_pow,
        csr_amp    => csr_amp,
        csr_env    => csr_env,
        csr_drag   => csr_drag,
        csr_valid  => csr_valid,
        csr_delay  => csr_delay,
        trig_ready => trig_ready,
        sig_i_o    => sig_i_o,
        sig_q_o    => sig_q_o,
        active_o   => active_o
    );

end architecture rtl;
