library IEEE;
use IEEE.std_logic_1164.all;
use work.sine_lut_pkg.LUT_ADDR_BITS;
use work.sine_lut_pkg.OUT_RES_BITS;
use work.envelope_lut_pkg.ENV_LUT_ADDR_BITS;

package sig_gen_pkg is

    component sin_pac is
        port (
            rst_i : in  std_logic;
            clk_i : in  std_logic;
            adr_i : in  std_logic_vector(LUT_ADDR_BITS+1 downto 0);
            sin_o : out std_logic_vector(OUT_RES_BITS-1 downto 0);
            cos_o : out std_logic_vector(OUT_RES_BITS-1 downto 0)
        );
    end component sin_pac;

    component pha_acc is
        generic (
            PHA_ACC_BITS : natural := 32
        );
        port (
            clk_i  : in  std_logic;
            rst_i  : in  std_logic;
            clr_i : in  std_logic;
            en_i  : in  std_logic;
            ftw_i  : in  std_logic_vector(PHA_ACC_BITS-1 downto 0);
            pow_i  : in  std_logic_vector(PHA_ACC_BITS-1 downto 0);
            adr_o  : out std_logic_vector(LUT_ADDR_BITS+1 downto 0)
        );
    end component pha_acc;

    component env_gen is
        port (
            clk_i        : in  std_logic;
            rst_i        : in  std_logic;
            adr_i        : in  std_logic_vector(ENV_LUT_ADDR_BITS-1 downto 0);
            active_i     : in  std_logic;
            drag_i       : in  std_logic_vector(15 downto 0);
            amp_i        : in  std_logic_vector(15 downto 0);
            gauss_o      : out std_logic_vector(OUT_RES_BITS downto 0);
            drag_o       : out std_logic_vector(OUT_RES_BITS downto 0)
        );
    end component env_gen;

    component iq_mod is
        port (
            clk_i    : in  std_logic;
            rst_i    : in  std_logic;
            gauss_i  : in  std_logic_vector(OUT_RES_BITS downto 0);
            drag_i   : in  std_logic_vector(OUT_RES_BITS downto 0);
            sin_i : in  std_logic_vector(OUT_RES_BITS-1 downto 0);
            cos_i : in  std_logic_vector(OUT_RES_BITS-1 downto 0);
            sig_i_o  : out std_logic_vector(OUT_RES_BITS-1 downto 0);
            sig_q_o  : out std_logic_vector(OUT_RES_BITS-1 downto 0)
        );
    end component iq_mod;

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
            env_o   : out std_logic_vector(DATA_WIDTH-1 downto 0);
            drag_o : out std_logic_vector(15 downto 0);
            
            valid_o  : out std_logic;
            start_o  : out std_logic;
            delay_o  : out std_logic_vector(23 downto 0);
            ready_i  : in  std_logic;
            pend_i   : in  std_logic_vector(3 downto 0)
        );
    end component sig_gen_csrs;

    component env_seq is
        port (
            clk_i    : in  std_logic;
            rst_i    : in  std_logic;
            clr_i    : in  std_logic;
            en_i     : in  std_logic;
            step_i   : in  std_logic_vector(31 downto 0);
            addr_o   : out std_logic_vector(ENV_LUT_ADDR_BITS-1 downto 0);
            done_o   : out std_logic
        );
    end component env_seq;

    component sig_gen_ctrl is
        generic (
            PHA_ACC_BITS : natural := 32
        );
        port (
            clk_i    : in  std_logic;
            rst_i    : in  std_logic;
            start_i  : in  std_logic;
            valid_i  : in  std_logic;
            done_i   : in  std_logic;
            ftw_i    : in  std_logic_vector(PHA_ACC_BITS-1 downto 0);
            pow_i    : in  std_logic_vector(PHA_ACC_BITS-1 downto 0);
            amp_i    : in  std_logic_vector(15 downto 0);
            env_i    : in  std_logic_vector(31 downto 0);
            drag_i   : in  std_logic_vector(15 downto 0);
            delay_i  : in  std_logic_vector(23 downto 0);
            clr_o    : out std_logic;
            ready_o  : out std_logic;
            ftw_o    : out std_logic_vector(PHA_ACC_BITS-1 downto 0);
            pow_o    : out std_logic_vector(PHA_ACC_BITS-1 downto 0);
            amp_o    : out std_logic_vector(15 downto 0);
            env_o    : out std_logic_vector(31 downto 0);
            drag_o   : out std_logic_vector(15 downto 0);
            en_o     : out std_logic
        );
    end component sig_gen_ctrl;

    component sig_gen is
        generic (
            PHA_ACC_BITS : natural := 32;
            FIFO_DEPTH   : natural := 8
        );
        port (
            clk_i       : in  std_logic;
            rst_i       : in  std_logic;
            start_i     : in  std_logic;
            valid_i     : in  std_logic;
            ftw_i       : in  std_logic_vector(PHA_ACC_BITS-1 downto 0);
            pow_i       : in  std_logic_vector(PHA_ACC_BITS-1 downto 0);
            amp_i       : in  std_logic_vector(15 downto 0);
            env_i       : in  std_logic_vector(31 downto 0);
            drag_i      : in  std_logic_vector(15 downto 0);
            delay_i     : in  std_logic_vector(23 downto 0);
            ready_o     : out std_logic;
            pend_o      : out std_logic_vector(3 downto 0);
            sig_i_o     : out std_logic_vector(OUT_RES_BITS-1 downto 0);
            sig_q_o     : out std_logic_vector(OUT_RES_BITS-1 downto 0);
            active_o    : out std_logic
        );
    end component sig_gen;

    component pulse_fifo is
        generic (
            FIFO_DEPTH   : natural := 8;
            PHA_ACC_BITS : natural := 32
        );
        port (
            clk_i   : in  std_logic;
            rst_i   : in  std_logic;
            valid_i : in  std_logic;
            ftw_i   : in  std_logic_vector(PHA_ACC_BITS-1 downto 0);
            pow_i   : in  std_logic_vector(PHA_ACC_BITS-1 downto 0);
            amp_i   : in  std_logic_vector(15 downto 0);
            env_i   : in  std_logic_vector(31 downto 0);
            drag_i  : in  std_logic_vector(15 downto 0);
            delay_i : in  std_logic_vector(23 downto 0);
            ready_o : out std_logic;
            ready_i : in  std_logic;
            valid_o : out std_logic;
            ftw_o   : out std_logic_vector(PHA_ACC_BITS-1 downto 0);
            pow_o   : out std_logic_vector(PHA_ACC_BITS-1 downto 0);
            amp_o   : out std_logic_vector(15 downto 0);
            env_o   : out std_logic_vector(31 downto 0);
            drag_o  : out std_logic_vector(15 downto 0);
            delay_o : out std_logic_vector(23 downto 0);
            pend_o  : out std_logic_vector(3 downto 0)
        );
    end component pulse_fifo;

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
