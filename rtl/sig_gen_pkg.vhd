library IEEE;
use IEEE.std_logic_1164.all;
use work.sine_lut_pkg.LUT_ADDR_BITS;
use work.sine_lut_pkg.OUT_RES_BITS;

package sig_gen_pkg is

    component sine_cos_lut is
        port (
            rst_i : in  std_logic;
            clk_i : in  std_logic;
            adr_i : in  std_logic_vector(LUT_ADDR_BITS+1 downto 0);
            sin_o : out std_logic_vector(OUT_RES_BITS-1 downto 0);
            cos_o : out std_logic_vector(OUT_RES_BITS-1 downto 0)
        );
    end component sine_cos_lut;

    component pha_acc is
        generic (
            PHA_ACC_BITS : natural := 32
        );
        port (
            clk_i : in  std_logic;
            rst_i : in  std_logic;
            we_i  : in  std_logic;
            ftw_i : in  std_logic_vector(PHA_ACC_BITS-1 downto 0);
            pow_i : in  std_logic_vector(PHA_ACC_BITS-1 downto 0);
            val_o : out std_logic_vector(PHA_ACC_BITS-1 downto 0)
        );
    end component pha_acc;

    component env_gen is
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
    end component env_gen;

    component sig_gen_csrs is
        generic (
            DATA_WIDTH : natural := 32
        );
        port (
            rst_i : in  std_logic;
            clk_i : in  std_logic;
            adr_i : in  std_logic_vector(2 downto 0);
            cyc_i : in  std_logic;
            stb_i : in  std_logic;
            we_i  : in  std_logic;
            sel_i : in  std_logic_vector(DATA_WIDTH/8-1 downto 0);
            dat_i : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            ack_o : out std_logic;
            dat_o : out std_logic_vector(DATA_WIDTH-1 downto 0);
            
            ftw_o        : out std_logic_vector(DATA_WIDTH-1 downto 0);
            pow_o        : out std_logic_vector(DATA_WIDTH-1 downto 0);
            amp_o        : out std_logic_vector(15 downto 0);
            env_step_o   : out std_logic_vector(DATA_WIDTH-1 downto 0);
            drag_coeff_o : out std_logic_vector(15 downto 0);
            
            trig_o       : out std_logic;
            delay_o      : out std_logic_vector(23 downto 0);

            busy_i       : in  std_logic;
            pending_i    : in  std_logic
        );
    end component sig_gen_csrs;

    component trig_pending_ctrl is
        port (
            clk_i        : in  std_logic;
            rst_i        : in  std_logic;
            trig_i       : in  std_logic;
            delay_i      : in  std_logic_vector(23 downto 0);
            env_active_i : in  std_logic;
            pulse_o      : out std_logic;
            pending_o    : out std_logic
        );
    end component trig_pending_ctrl;

    component wb_sig_gen is
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
    end component wb_sig_gen;

end package sig_gen_pkg;
