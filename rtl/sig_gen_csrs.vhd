library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity sig_gen_csrs is
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
        
        pulse_o  : out std_logic;
        busy_i   : in  std_logic
    );
end entity sig_gen_csrs;

architecture rtl of sig_gen_csrs is

    constant REG_FTW        : std_logic_vector(2 downto 0) := "000";
    constant REG_POW        : std_logic_vector(2 downto 0) := "001";
    constant REG_AMP        : std_logic_vector(2 downto 0) := "010";
    constant REG_ENV_STEP   : std_logic_vector(2 downto 0) := "011";
    constant REG_DRAG_COEFF : std_logic_vector(2 downto 0) := "100";
    constant REG_TRIG       : std_logic_vector(2 downto 0) := "101";

    signal ack_reg : std_logic;
    signal dat_reg : std_logic_vector(DATA_WIDTH-1 downto 0);
    
    signal ftw_reg        : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal pow_reg        : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal amp_reg        : std_logic_vector(15 downto 0);
    signal env_step_reg   : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal drag_coeff_reg : std_logic_vector(15 downto 0);
    
    signal trig_reg       : std_logic;
    signal delay_reg      : std_logic_vector(23 downto 0);
    signal trig_pending   : std_logic;
    signal trig_pulse_del : std_logic;
    signal env_active_d   : std_logic;
    signal delay_counter  : unsigned(23 downto 0);

begin

    pulse_o <= (trig_reg and not busy_i and not trig_pending) or trig_pulse_del;

    csr_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                ack_reg <= '0';
                dat_reg <= (others => '0');
                ftw_reg <= (others => '0');
                pow_reg <= (others => '0');
                amp_reg <= (others => '0');
                env_step_reg <= (others => '0');
                drag_coeff_reg <= (others => '0');
                delay_reg <= (others => '0');
                trig_reg <= '0';
            else
                ack_reg <= cyc_i and stb_i and not ack_reg;
                trig_reg <= '0';

                if cyc_i = '1' and stb_i = '1' and ack_reg = '0' then
                    case adr_i is
                        when REG_FTW =>
                            if we_i = '1' then
                                for i in 0 to 3 loop
                                    if sel_i(i) = '1' then
                                        ftw_reg(8*i+7 downto 8*i) <= dat_i(8*i+7 downto 8*i);
                                    end if;
                                end loop;
                            end if;
                            dat_reg <= ftw_reg;

                        when REG_POW =>
                            if we_i = '1' then
                                for i in 0 to 3 loop
                                    if sel_i(i) = '1' then
                                        pow_reg(8*i+7 downto 8*i) <= dat_i(8*i+7 downto 8*i);
                                    end if;
                                end loop;
                            end if;
                            dat_reg <= pow_reg;

                        when REG_AMP =>
                            if we_i = '1' then
                                for i in 0 to 1 loop
                                    if sel_i(i) = '1' then
                                        amp_reg(8*i+7 downto 8*i) <= dat_i(8*i+7 downto 8*i);
                                    end if;
                                end loop;
                            end if;
                            dat_reg <= x"0000" & amp_reg;

                        when REG_ENV_STEP =>
                            if we_i = '1' then
                                for i in 0 to 3 loop
                                    if sel_i(i) = '1' then
                                        env_step_reg(8*i+7 downto 8*i) <= dat_i(8*i+7 downto 8*i);
                                    end if;
                                end loop;
                            end if;
                            dat_reg <= env_step_reg;

                        when REG_DRAG_COEFF =>
                            if we_i = '1' then
                                for i in 0 to 1 loop
                                    if sel_i(i) = '1' then
                                        drag_coeff_reg(8*i+7 downto 8*i) <= dat_i(8*i+7 downto 8*i);
                                    end if;
                                end loop;
                            end if;
                            dat_reg <= x"0000" & drag_coeff_reg;

                        when REG_TRIG =>
                            if we_i = '1' then
                                trig_reg <= sel_i(0) and dat_i(0);
                                for i in 1 to 3 loop
                                    if sel_i(i) = '1' then
                                        delay_reg(8*(i-1)+7 downto 8*(i-1)) <= dat_i(8*i+7 downto 8*i);
                                    end if;
                                end loop;
                            end if;
                            dat_reg <= delay_reg & "00000" & trig_pending & busy_i & trig_reg;

                        when others =>
                            dat_reg <= (others => '0');
                    end case;
                end if;
            end if;
        end if;
    end process csr_proc;

    pending_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                trig_pending   <= '0';
                trig_pulse_del <= '0';
                delay_counter  <= (others => '0');
                env_active_d   <= '0';
            else
                trig_pulse_del <= '0';
                env_active_d <= busy_i;

                if trig_reg = '1' and busy_i = '1' then
                    trig_pending <= '1';
                end if;

                if env_active_d = '1' and busy_i = '0' and trig_pending = '1' then
                    if unsigned(delay_reg) = 0 then
                        trig_pulse_del <= '1';
                        trig_pending   <= '0';
                    else
                        delay_counter <= unsigned(delay_reg);
                    end if;
                elsif delay_counter > 0 then
                    delay_counter <= delay_counter - 1;
                    if delay_counter = 1 then
                        trig_pulse_del <= '1';
                        trig_pending   <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process pending_proc;

    ack_o <= ack_reg;
    dat_o <= dat_reg;
    
    ftw_o        <= ftw_reg;
    pow_o        <= pow_reg;
    amp_o        <= amp_reg;
    env_step_o   <= env_step_reg;
    drag_coeff_o <= drag_coeff_reg;

end architecture rtl;
