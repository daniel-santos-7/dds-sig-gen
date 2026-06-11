library IEEE;
use IEEE.std_logic_1164.all;

entity sig_gen_csrs is
    generic (
        DATA_WIDTH : natural := 32
    );
    port (
        rst_i   : in  std_logic;
        clk_i   : in  std_logic;
        adr_i   : in  std_logic_vector(2 downto 0);
        cyc_i   : in  std_logic;
        stb_i   : in  std_logic;
        we_i    : in  std_logic;
        sel_i   : in  std_logic_vector(DATA_WIDTH/8-1 downto 0);
        dat_i   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        ack_o   : out std_logic;
        dat_o   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        ftw_o   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        pow_o   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        amp_o   : out std_logic_vector(15 downto 0);
        env_o   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        drag_o  : out std_logic_vector(15 downto 0);
        valid_o : out std_logic;
        delay_o : out std_logic_vector(23 downto 0);
        ready_i : in  std_logic
    );
end entity sig_gen_csrs;

architecture rtl of sig_gen_csrs is

    constant REG_FTW   : std_logic_vector(2 downto 0) := "000";
    constant REG_POW   : std_logic_vector(2 downto 0) := "001";
    constant REG_AMP   : std_logic_vector(2 downto 0) := "010";
    constant REG_ENV   : std_logic_vector(2 downto 0) := "011";
    constant REG_DRAG  : std_logic_vector(2 downto 0) := "100";
    constant REG_DELAY : std_logic_vector(2 downto 0) := "101";
    constant REG_TRIG  : std_logic_vector(2 downto 0) := "110";

    signal csr_req : std_logic;
    signal ack_reg : std_logic;
    signal dat_reg : std_logic_vector(DATA_WIDTH-1 downto 0);
    
    signal ftw_reg  : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal pow_reg  : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal amp_reg  : std_logic_vector(15 downto 0);
    signal env_reg  : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal drag_reg : std_logic_vector(15 downto 0);
    
    signal valid_reg : std_logic;
    signal delay_reg : std_logic_vector(23 downto 0);

begin

    csr_req <= cyc_i and stb_i;

    ack_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                ack_reg <= '0';
            else
                ack_reg <= csr_req and not ack_reg;
            end if;
        end if;
    end process ack_proc;

    write_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                ftw_reg   <= (others => '0');
                pow_reg   <= (others => '0');
                amp_reg   <= (others => '0');
                env_reg   <= (others => '0');
                drag_reg  <= (others => '0');
                delay_reg <= (others => '0');
                valid_reg <= '0';
            else
                -- Clear autonomously when trig_ctrl accepts the trigger
                if valid_reg = '1' and ready_i = '1' then
                    valid_reg <= '0';
                end if;

                -- Bus write
                if csr_req = '1' and ack_reg = '0' and we_i = '1' then
                    case adr_i is
                        when REG_FTW =>
                            for i in 0 to 3 loop
                                if sel_i(i) = '1' then
                                    ftw_reg(8*i+7 downto 8*i) <= dat_i(8*i+7 downto 8*i);
                                end if;
                            end loop;
                        when REG_POW =>
                            for i in 0 to 3 loop
                                if sel_i(i) = '1' then
                                    pow_reg(8*i+7 downto 8*i) <= dat_i(8*i+7 downto 8*i);
                                end if;
                            end loop;
                        when REG_AMP =>
                            for i in 0 to 1 loop
                                if sel_i(i) = '1' then
                                    amp_reg(8*i+7 downto 8*i) <= dat_i(8*i+7 downto 8*i);
                                end if;
                            end loop;
                        when REG_ENV =>
                            for i in 0 to 3 loop
                                if sel_i(i) = '1' then
                                    env_reg(8*i+7 downto 8*i) <= dat_i(8*i+7 downto 8*i);
                                end if;
                            end loop;
                        when REG_DRAG =>
                            for i in 0 to 1 loop
                                if sel_i(i) = '1' then
                                    drag_reg(8*i+7 downto 8*i) <= dat_i(8*i+7 downto 8*i);
                                end if;
                            end loop;
                        when REG_DELAY =>
                            for i in 0 to 2 loop
                                if sel_i(i) = '1' then
                                    delay_reg(8*i+7 downto 8*i) <= dat_i(8*i+7 downto 8*i);
                                end if;
                            end loop;
                        when REG_TRIG =>
                            if sel_i(0) = '1' and dat_i(0) = '1' then
                                valid_reg <= '1';
                            end if;
                        when others =>
                            null;
                    end case;
                end if;
            end if;
        end if;
    end process write_proc;

    read_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                dat_reg <= (others => '0');
            else
                if csr_req = '1' and ack_reg = '0' then
                    case adr_i is
                        when REG_FTW   => dat_reg <= ftw_reg;
                        when REG_POW   => dat_reg <= pow_reg;
                        when REG_AMP   => dat_reg <= x"0000" & amp_reg;
                        when REG_ENV   => dat_reg <= env_reg;
                        when REG_DRAG  => dat_reg <= x"0000" & drag_reg;
                        when REG_TRIG  => dat_reg <= x"000000" & "00000" & '0' & ready_i & valid_reg;
                        when REG_DELAY => dat_reg <= x"00" & delay_reg;
                        when others    => dat_reg <= (others => '0');
                    end case;
                end if;
            end if;
        end if;
    end process read_proc;

    -- Output assignments --
    dat_o   <= dat_reg;
    ack_o   <= ack_reg;
    ftw_o   <= ftw_reg;
    pow_o   <= pow_reg;
    amp_o   <= amp_reg;
    env_o   <= env_reg;
    drag_o  <= drag_reg;
    delay_o <= delay_reg;
    valid_o <= valid_reg;

end architecture rtl;