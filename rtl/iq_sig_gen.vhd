library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.sig_gen_pkg.all;
use work.sine_lut_pkg.LUT_ADDR_BITS;
use work.sine_lut_pkg.OUT_RES_BITS;

entity iq_sig_gen is
    generic (
        PHA_ACC_BITS : natural := 32
    );
    port (
        clk_i   : in  std_logic;
        rst_i   : in  std_logic;
        we_i    : in  std_logic;
        inc_i   : in  std_logic_vector(PHA_ACC_BITS-1 downto 0);
        pha_i   : in  std_logic_vector(PHA_ACC_BITS-1 downto 0);
        
        env_i_i : in  std_logic_vector(OUT_RES_BITS-1 downto 0);
        env_q_i : in  std_logic_vector(OUT_RES_BITS-1 downto 0);
        
        sig_i_o : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        sig_q_o : out std_logic_vector(OUT_RES_BITS-1 downto 0)
    );
end entity iq_sig_gen;

architecture rtl of iq_sig_gen is

    signal pha_val : std_logic_vector(PHA_ACC_BITS-1 downto 0);
    
    signal addr_q : std_logic_vector(LUT_ADDR_BITS+1 downto 0);
    signal addr_i : std_logic_vector(LUT_ADDR_BITS+1 downto 0);
    
    signal sine_q : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal sine_i : std_logic_vector(OUT_RES_BITS-1 downto 0);

begin

    u_pha_acc : pha_acc generic map (
        PHA_ACC_BITS => PHA_ACC_BITS
    ) port map (
        clk_i => clk_i,
        rst_i => rst_i,
        we_i  => we_i,
        inc_i => inc_i,
        pha_i => pha_i,
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

    u_amp_scale_i : amp_scale port map (
        clk_i => clk_i,
        rst_i => rst_i,
        we_i  => '1',
        amp_i => env_i_i,
        sig_i => sine_i,
        sig_o => sig_i_o
    );

    u_amp_scale_q : amp_scale port map (
        clk_i => clk_i,
        rst_i => rst_i,
        we_i  => '1',
        amp_i => env_q_i,
        sig_i => sine_q,
        sig_o => sig_q_o
    );

end architecture rtl;
