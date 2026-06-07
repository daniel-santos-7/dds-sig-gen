library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.sig_gen_pkg.all;
use work.sine_lut_pkg.LUT_ADDR_BITS;
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
    
    signal env_active : std_logic;

    signal pha_val : std_logic_vector(PHA_ACC_BITS-1 downto 0);
    signal addr_q  : std_logic_vector(LUT_ADDR_BITS+1 downto 0);
    signal addr_i  : std_logic_vector(LUT_ADDR_BITS+1 downto 0);
    signal sine_q  : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal sine_i  : std_logic_vector(OUT_RES_BITS-1 downto 0);

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

    u_pha_acc : pha_acc generic map (
        PHA_ACC_BITS => PHA_ACC_BITS
    ) port map (
        clk_i => clk_i,
        rst_i => rst_i,
        we_i  => csr_we,
        inc_i => csr_inc(PHA_ACC_BITS-1 downto 0),
        pha_i => csr_pha(PHA_ACC_BITS-1 downto 0),
        val_o => pha_val
    );

    addr_q <= pha_val(PHA_ACC_BITS-1 downto PHA_ACC_BITS-LUT_ADDR_BITS-2);
    addr_i <= std_logic_vector(unsigned(addr_q) + to_unsigned(2**LUT_ADDR_BITS, LUT_ADDR_BITS+2));

    u_sine_lut_i : sine_lut port map (
        rst_i => rst_i,
        clk_i => clk_i,
        adr_i => addr_i,
        sig_o => sine_i
    );

    u_sine_lut_q : sine_lut port map (
        rst_i => rst_i,
        clk_i => clk_i,
        adr_i => addr_q,
        sig_o => sine_q
    );

    u_env_gen : env_gen port map (
        clk_i        => clk_i,
        rst_i        => rst_i,
        trigger_i    => csr_trig,
        step_i       => csr_env_step,
        drag_coeff_i => csr_drag_coeff(15 downto 0),

        sine_i_i     => sine_i,
        sine_q_i     => sine_q,

        sig_i_o      => sig_i_o,
        sig_q_o      => sig_q_o,
        active_o     => env_active
    );

end architecture rtl;
