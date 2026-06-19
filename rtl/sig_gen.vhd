library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.sig_gen_pkg.all;
use work.sine_lut_pkg.LUT_ADDR_BITS;
use work.sine_lut_pkg.OUT_RES_BITS;
use work.envelope_lut_pkg.ENV_LUT_ADDR_BITS;

entity sig_gen is
    generic (
        PHA_ACC_BITS : natural := 32;
        FIFO_DEPTH   : natural := 8
    );
    port (
        clk_i    : in  std_logic;
        rst_i    : in  std_logic;
        start_i  : in  std_logic;
        valid_i  : in  std_logic;
        ftw_i    : in  std_logic_vector(PHA_ACC_BITS-1 downto 0);
        pow_i    : in  std_logic_vector(PHA_ACC_BITS-1 downto 0);
        amp_i    : in  std_logic_vector(15 downto 0);
        env_i    : in  std_logic_vector(31 downto 0);
        drag_i   : in  std_logic_vector(15 downto 0);
        delay_i  : in  std_logic_vector(23 downto 0);
        ready_o      : out std_logic;
        pend_o : out std_logic_vector(3 downto 0);
        sig_i_o      : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        sig_q_o      : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        active_o     : out std_logic
    );
end entity sig_gen;

architecture rtl of sig_gen is

    signal pulse_fifo_ftw      : std_logic_vector(PHA_ACC_BITS-1 downto 0);
    signal pulse_fifo_pow      : std_logic_vector(PHA_ACC_BITS-1 downto 0);
    signal pulse_fifo_amp      : std_logic_vector(15 downto 0);
    signal pulse_fifo_env      : std_logic_vector(31 downto 0);
    signal pulse_fifo_drag     : std_logic_vector(15 downto 0);
    signal pulse_fifo_delay    : std_logic_vector(23 downto 0);
    signal pulse_fifo_valid : std_logic;

    signal ctrl_sync     : std_logic;
    signal ctrl_active   : std_logic;
    signal env_seq_addr  : std_logic_vector(ENV_LUT_ADDR_BITS-1 downto 0);
    signal env_seq_done  : std_logic;

    signal ctrl_ftw      : std_logic_vector(PHA_ACC_BITS-1 downto 0);
    signal ctrl_pow      : std_logic_vector(PHA_ACC_BITS-1 downto 0);
    signal ctrl_amp      : std_logic_vector(15 downto 0);
    signal ctrl_env      : std_logic_vector(31 downto 0);
    signal ctrl_drag     : std_logic_vector(15 downto 0);

    signal env_gen_gauss : std_logic_vector(OUT_RES_BITS downto 0);
    signal env_gen_drag  : std_logic_vector(OUT_RES_BITS downto 0);

    signal pha_acc_addr  : std_logic_vector(LUT_ADDR_BITS+1 downto 0);
    signal sin_pac_sin   : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal sin_pac_cos   : std_logic_vector(OUT_RES_BITS-1 downto 0);

    signal pulse_fifo_pend : std_logic_vector(3 downto 0);
    signal ctrl_ready   : std_logic;

begin

    sig_gen_pulse_fifo : entity work.pulse_fifo generic map (
        FIFO_DEPTH   => FIFO_DEPTH,
        PHA_ACC_BITS => PHA_ACC_BITS
    ) port map (
        clk_i   => clk_i,
        rst_i   => rst_i,
        valid_i => valid_i,
        ftw_i   => ftw_i,
        pow_i   => pow_i,
        amp_i   => amp_i,
        env_i   => env_i,
        drag_i  => drag_i,
        delay_i => delay_i,
        ready_o => ready_o,
        ready_i => ctrl_ready,
        valid_o => pulse_fifo_valid,
        ftw_o   => pulse_fifo_ftw,
        pow_o   => pulse_fifo_pow,
        amp_o   => pulse_fifo_amp,
        env_o   => pulse_fifo_env,
        drag_o  => pulse_fifo_drag,
        delay_o      => pulse_fifo_delay,
        pend_o => pulse_fifo_pend
    );

    sig_gen_sig_gen_ctrl : sig_gen_ctrl generic map (
        PHA_ACC_BITS => PHA_ACC_BITS
    ) port map (
        clk_i   => clk_i,
        rst_i   => rst_i,
        start_i => start_i,
        valid_i => pulse_fifo_valid,
        done_i  => env_seq_done,
        ftw_i   => pulse_fifo_ftw,
        pow_i   => pulse_fifo_pow,
        amp_i   => pulse_fifo_amp,
        env_i   => pulse_fifo_env,
        drag_i  => pulse_fifo_drag,
        delay_i => pulse_fifo_delay,
        clr_o   => ctrl_sync,
        ready_o => ctrl_ready,
        ftw_o   => ctrl_ftw,
        pow_o   => ctrl_pow,
        amp_o   => ctrl_amp,
        env_o   => ctrl_env,
        drag_o  => ctrl_drag,
        en_o    => ctrl_active
    );

    sig_gen_env_seq : env_seq port map (
        clk_i    => clk_i,
        rst_i    => rst_i,
        clr_i    => ctrl_sync,
        en_i     => ctrl_active,
        step_i   => ctrl_env,
        addr_o   => env_seq_addr,
        done_o   => env_seq_done
    );

    sig_gen_pha_acc : pha_acc generic map (
        PHA_ACC_BITS => PHA_ACC_BITS
    ) port map (
        clk_i  => clk_i,
        rst_i  => rst_i,
        clr_i  => ctrl_sync,
        en_i   => ctrl_active,
        ftw_i  => ctrl_ftw,
        pow_i  => ctrl_pow,
        adr_o  => pha_acc_addr
    );

    sig_gen_sin_pac : sin_pac port map (
        rst_i => rst_i,
        clk_i => clk_i,
        adr_i => pha_acc_addr,
        sin_o => sin_pac_sin,
        cos_o => sin_pac_cos
    );

    sig_gen_env_gen : env_gen port map (
        clk_i    => clk_i,
        rst_i    => rst_i,
        adr_i    => env_seq_addr,
        active_i => ctrl_active,
        drag_i   => ctrl_drag,
        amp_i    => ctrl_amp,
        gauss_o  => env_gen_gauss,
        drag_o   => env_gen_drag
    );

    sig_gen_iq_mod : iq_mod port map (
        clk_i   => clk_i,
        rst_i   => rst_i,
        gauss_i => env_gen_gauss,
        drag_i  => env_gen_drag,
        sin_i   => sin_pac_sin,
        cos_i   => sin_pac_cos,
        sig_i_o => sig_i_o,
        sig_q_o => sig_q_o
    );

    active_o <= ctrl_active;

    pend_o <= pulse_fifo_pend;

end architecture rtl;
