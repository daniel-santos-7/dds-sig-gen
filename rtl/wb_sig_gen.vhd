library IEEE;
use IEEE.std_logic_1164.all;
use work.sig_gen_pkg.all;
use work.sine_lut_pkg.OUT_RES_BITS;

entity wb_sig_gen is
    generic (
        DATA_WIDTH   : natural := 32;
        ADDR_WIDTH   : natural := 5;
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
        
        sig_i_o : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        sig_q_o : out std_logic_vector(OUT_RES_BITS-1 downto 0)
    );
end entity wb_sig_gen;

architecture rtl of wb_sig_gen is

    signal csr_inc        : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal csr_pha        : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal csr_amp        : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal csr_env_step   : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal csr_drag_coeff : std_logic_vector(DATA_WIDTH-1 downto 0);
    
    signal csr_we         : std_logic;
    signal csr_trig       : std_logic;
    
    signal env_i : std_logic_vector(15 downto 0);
    signal env_q : std_logic_vector(15 downto 0);
    signal env_active : std_logic;

begin

    u_sig_gen_csrs : sig_gen_csrs generic map (
        DATA_WIDTH => DATA_WIDTH,
        ADDR_WIDTH => ADDR_WIDTH
    ) port map (
        rst_i => rst_i,
        clk_i => clk_i,
        adr_i => adr_i,
        cyc_i => cyc_i,
        stb_i => stb_i,
        we_i  => we_i,
        sel_i => sel_i,
        dat_i => dat_i,
        ack_o => ack_o,
        dat_o => dat_o,
        
        inc_o        => csr_inc,
        pha_o        => csr_pha,
        amp_o        => csr_amp,
        env_step_o   => csr_env_step,
        drag_coeff_o => csr_drag_coeff,
        we_o         => csr_we,
        trig_o       => csr_trig
    );

    u_envelope_gen : envelope_gen port map (
        clk_i        => clk_i,
        rst_i        => rst_i,
        trigger_i    => csr_trig,
        step_i       => csr_env_step,
        drag_coeff_i => csr_drag_coeff(15 downto 0),
        env_i_o      => env_i,
        env_q_o      => env_q,
        active_o     => env_active
    );

    u_iq_sig_gen : iq_sig_gen generic map (
        PHA_ACC_BITS => PHA_ACC_BITS
    ) port map (
        clk_i => clk_i,
        rst_i => rst_i,
        we_i  => csr_we,
        inc_i => csr_inc(PHA_ACC_BITS-1 downto 0),
        pha_i => csr_pha(PHA_ACC_BITS-1 downto 0),
        
        -- scale envelope by amplitude
        env_i_i => env_i(15 downto 16-OUT_RES_BITS), 
        env_q_i => env_q(15 downto 16-OUT_RES_BITS),
        
        sig_i_o => sig_i_o,
        sig_q_o => sig_q_o
    );

end architecture rtl;
