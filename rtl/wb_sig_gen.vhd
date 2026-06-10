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
        
        sig_i_o  : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        sig_q_o  : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        active_o : out std_logic
    );
end entity wb_sig_gen;

architecture rtl of wb_sig_gen is

    signal csr_ftw        : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal csr_pow        : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal csr_amp        : std_logic_vector(15 downto 0);
    signal csr_env_step   : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal csr_drag_coeff : std_logic_vector(15 downto 0);
    
    signal csr_trig       : std_logic;
    signal csr_delay      : std_logic_vector(23 downto 0);
    signal trig_pending   : std_logic;
    signal trig_pulse     : std_logic;
    signal trig_pulse_del : std_logic;
    signal env_active_d   : std_logic;
    signal delay_counter  : unsigned(23 downto 0);

    signal env_active : std_logic;

    signal pha_val : std_logic_vector(PHA_ACC_BITS-1 downto 0);
    signal addr    : std_logic_vector(LUT_ADDR_BITS+1 downto 0);
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
        
        ftw_o        => csr_ftw,
        pow_o        => csr_pow,
        amp_o        => csr_amp,
        env_step_o   => csr_env_step,
        drag_coeff_o => csr_drag_coeff,
        trig_o       => csr_trig,
        delay_o      => csr_delay,

        busy_i       => env_active,
        pending_i    => trig_pending
    );

    trig_pulse <= (csr_trig and not env_active and not trig_pending) or trig_pulse_del;

    env_edge_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            env_active_d <= env_active;
        end if;
    end process;

    pending_proc : process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            trig_pending   <= '0';
            delay_counter  <= (others => '0');
            trig_pulse_del <= '0';
        elsif rising_edge(clk_i) then
            trig_pulse_del <= '0';

            if csr_trig = '1' and env_active = '1' then
                trig_pending <= '1';
            end if;

            if env_active_d = '1' and env_active = '0' and trig_pending = '1' then
                if unsigned(csr_delay) = 0 then
                    trig_pulse_del <= '1';
                    trig_pending   <= '0';
                else
                    delay_counter <= unsigned(csr_delay);
                end if;
            elsif delay_counter > 0 then
                delay_counter <= delay_counter - 1;
                if delay_counter = 1 then
                    trig_pulse_del <= '1';
                    trig_pending   <= '0';
                end if;
            end if;
        end if;
    end process;

    u_pha_acc : pha_acc generic map (
        PHA_ACC_BITS => PHA_ACC_BITS
    ) port map (
        clk_i => clk_i,
        rst_i => rst_i,
        we_i  => trig_pulse,
        ftw_i => csr_ftw(PHA_ACC_BITS-1 downto 0),
        pow_i => csr_pow(PHA_ACC_BITS-1 downto 0),
        val_o => pha_val
    );

    addr <= pha_val(PHA_ACC_BITS-1 downto PHA_ACC_BITS-LUT_ADDR_BITS-2);

    u_sine_cos_lut : sine_cos_lut port map (
        rst_i => rst_i,
        clk_i => clk_i,
        adr_i => addr,
        sin_o => sine_q,
        cos_o => sine_i
    );

    u_env_gen : env_gen port map (
        clk_i        => clk_i,
        rst_i        => rst_i,
        trigger_i    => trig_pulse,
        step_i       => csr_env_step,
        drag_coeff_i => csr_drag_coeff,
        amp_i        => csr_amp,

        sine_i_i     => sine_i,
        sine_q_i     => sine_q,

        sig_i_o      => sig_i_o,
        sig_q_o      => sig_q_o,
        active_o     => env_active
    );

    active_o <= env_active;

end architecture rtl;
