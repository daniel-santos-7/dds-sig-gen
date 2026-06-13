library IEEE;
use IEEE.std_logic_1164.all;
use work.sig_gen_pkg.all;
use work.sine_lut_pkg.LUT_ADDR_BITS;
use work.sine_lut_pkg.OUT_RES_BITS;
use work.envelope_lut_pkg.ENV_LUT_ADDR_BITS;

entity sig_gen is
    generic (
        PHA_ACC_BITS : natural := 32
    );
    port (
        clk_i    : in  std_logic;
        rst_i    : in  std_logic;
        ftw_i    : in  std_logic_vector(PHA_ACC_BITS-1 downto 0);
        pow_i    : in  std_logic_vector(PHA_ACC_BITS-1 downto 0);
        amp_i    : in  std_logic_vector(15 downto 0);
        env_i    : in  std_logic_vector(31 downto 0);
        drag_i   : in  std_logic_vector(15 downto 0);
        valid_i  : in  std_logic;
        delay_i  : in  std_logic_vector(23 downto 0);
        ready_o  : out std_logic;
        sig_i_o  : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        sig_q_o  : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        active_o : out std_logic
    );
end entity sig_gen;

architecture rtl of sig_gen is

    signal env_seq_sync   : std_logic;
    signal env_seq_addr   : std_logic_vector(ENV_LUT_ADDR_BITS-1 downto 0);
    signal env_seq_active : std_logic;

    signal env_gen_gauss : std_logic_vector(OUT_RES_BITS downto 0);
    signal env_gen_drag  : std_logic_vector(OUT_RES_BITS downto 0);

    signal pha_acc_val  : std_logic_vector(PHA_ACC_BITS-1 downto 0);
    signal sin_pac_addr : std_logic_vector(LUT_ADDR_BITS+1 downto 0);
    signal sin_pac_sin  : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal sin_pac_cos  : std_logic_vector(OUT_RES_BITS-1 downto 0);

begin

    sig_gen_env_seq : env_seq port map (
        clk_i    => clk_i,
        rst_i    => rst_i,
        valid_i  => valid_i,
        delay_i  => delay_i,
        step_i   => env_i,
        sync_o   => env_seq_sync,
        addr_o   => env_seq_addr,
        active_o => env_seq_active,
        ready_o  => ready_o
    );

    sig_gen_pha_acc : pha_acc generic map (
        PHA_ACC_BITS => PHA_ACC_BITS
    ) port map (
        clk_i  => clk_i,
        rst_i  => rst_i,
        sync_i => env_seq_sync,
        ftw_i  => ftw_i,
        pow_i  => pow_i,
        val_o  => pha_acc_val
    );

    sin_pac_addr <= pha_acc_val(PHA_ACC_BITS-1 downto PHA_ACC_BITS-LUT_ADDR_BITS-2);

    sig_gen_sin_pac : sin_pac port map (
        rst_i => rst_i,
        clk_i => clk_i,
        adr_i => sin_pac_addr,
        sin_o => sin_pac_sin,
        cos_o => sin_pac_cos
    );

    sig_gen_env_gen : env_gen port map (
        clk_i    => clk_i,
        rst_i    => rst_i,
        adr_i    => env_seq_addr,
        active_i => env_seq_active,
        drag_i   => drag_i,
        amp_i    => amp_i,
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

    active_o <= env_seq_active;

end architecture rtl;
