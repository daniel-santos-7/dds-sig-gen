library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity sig_gen_ctrl is
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
end entity sig_gen_ctrl;

architecture rtl of sig_gen_ctrl is

    type state_t is (IDLE, ACTIVE);
    signal state_reg : state_t;

    signal delay_cnt_reg : unsigned(23 downto 0);
    signal delay_done    : std_logic;
    signal delay_val     : std_logic_vector(23 downto 0);
    signal sync    : std_logic;
    signal ready         : std_logic;

begin

    ctrl_fsm : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                state_reg <= IDLE;
            else
                case state_reg is
                    when IDLE =>
                        if start_i = '1' then
                            state_reg <= ACTIVE;
                        end if;

                    when ACTIVE =>
                        if valid_i = '0' then
                            state_reg <= IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process ctrl_fsm;

    ready <= '1' when state_reg = ACTIVE and done_i = '1' and delay_done = '1' else '0';
    sync  <= ready and valid_i;

    param_reg : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                ftw_o   <= (others => '0');
                pow_o   <= (others => '0');
                amp_o   <= (others => '0');
                env_o   <= (others => '0');
                drag_o  <= (others => '0');
                delay_val <= (others => '0');
            elsif start_i = '1' and state_reg = IDLE then
                ftw_o   <= ftw_i;
                pow_o   <= pow_i;
                amp_o   <= amp_i;
                env_o   <= env_i;
                drag_o  <= drag_i;
                delay_val <= delay_i;
            end if;
        end if;
    end process param_reg;

    delay_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                delay_cnt_reg <= (others => '0');
            elsif sync = '1' then
                delay_cnt_reg <= unsigned(delay_val);
            elsif done_i = '1' and delay_done = '0' then
                delay_cnt_reg <= delay_cnt_reg - 1;
            end if;
        end if;
    end process delay_proc;

    delay_done <= '1' when delay_cnt_reg = 0 else '0';

    ready_o <= ready;
    en_o    <= '1' when state_reg = ACTIVE and done_i = '0' else '0';
    clr_o   <= sync;

end architecture rtl;