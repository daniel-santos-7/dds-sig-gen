library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity seq_ctrl is
    port (
        clk_i       : in  std_logic;
        rst_i       : in  std_logic;

        -- CPU access
        cpu_addr_i  : in  std_logic_vector(2 downto 0);
        cpu_wdata_i : in  std_logic_vector(31 downto 0);
        cpu_we_i    : in  std_logic;
        cpu_rdata_o : out std_logic_vector(31 downto 0);

        -- Working register outputs (to mux in CSR layer)
        ftw_o       : out std_logic_vector(31 downto 0);
        pow_o       : out std_logic_vector(31 downto 0);
        amp_o       : out std_logic_vector(15 downto 0);
        env_o       : out std_logic_vector(31 downto 0);
        drag_o      : out std_logic_vector(15 downto 0);
        delay_o     : out std_logic_vector(23 downto 0);
        valid_o     : out std_logic;

        -- Status
        ready_i     : in  std_logic;
        busy_o      : out std_logic
    );
end entity seq_ctrl;

architecture rtl of seq_ctrl is

    type seq_entry_t is record
        ftw   : std_logic_vector(31 downto 0);
        pow   : std_logic_vector(31 downto 0);
        amp   : std_logic_vector(15 downto 0);
        env   : std_logic_vector(31 downto 0);
        drag  : std_logic_vector(15 downto 0);
        delay : std_logic_vector(23 downto 0);
    end record seq_entry_t;

    type seq_ram_t is array(0 to 7) of seq_entry_t;
    signal seq_ram : seq_ram_t;

    type state_t is (IDLE, LOAD, TRIGGER, WAIT_READY, NEXT_ENTRY, FINISH);
    signal state : state_t := IDLE;

    signal seq_len    : unsigned(2 downto 0) := "001";
    signal entry_ptr  : unsigned(2 downto 0) := (others => '0');
    signal sub_ptr    : unsigned(2 downto 0) := (others => '0');
    signal play_cnt   : unsigned(31 downto 0) := (others => '0');
    signal seq_repeat : std_logic_vector(31 downto 0) := (others => '0');
    signal done       : std_logic := '0';

    signal seq_ftw   : std_logic_vector(31 downto 0) := (others => '0');
    signal seq_pow   : std_logic_vector(31 downto 0) := (others => '0');
    signal seq_amp   : std_logic_vector(15 downto 0) := (others => '0');
    signal seq_env   : std_logic_vector(31 downto 0) := (others => '0');
    signal seq_drag  : std_logic_vector(15 downto 0) := (others => '0');
    signal seq_delay : std_logic_vector(23 downto 0) := (others => '0');

    signal seq_valid : std_logic := '0';
    signal busy_int  : std_logic := '0';

begin

    process(clk_i) is
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                seq_ram    <= (others => (
                    ftw   => (others => '0'),
                    pow   => (others => '0'),
                    amp   => (others => '0'),
                    env   => (others => '0'),
                    drag  => (others => '0'),
                    delay => (others => '0')
                ));
                seq_len    <= "001";
                entry_ptr  <= (others => '0');
                sub_ptr    <= (others => '0');
                play_cnt   <= (others => '0');
                seq_repeat <= (others => '0');
                done       <= '0';
                state      <= IDLE;
                seq_ftw    <= (others => '0');
                seq_pow    <= (others => '0');
                seq_amp    <= (others => '0');
                seq_env    <= (others => '0');
                seq_drag   <= (others => '0');
                seq_delay  <= (others => '0');
                seq_valid  <= '0';

            else
                -- Defaults
                seq_valid <= '0';

                -- CPU writes
                if cpu_we_i = '1' then
                    case cpu_addr_i is
                        when "000" =>  -- SEQ_LEN
                            if cpu_wdata_i(2 downto 0) = "000" then
                                seq_len <= "001";
                            else
                                seq_len <= unsigned(cpu_wdata_i(2 downto 0));
                            end if;
                        when "001" =>  -- SEQ_PTR
                            entry_ptr <= unsigned(cpu_wdata_i(2 downto 0));
                            sub_ptr   <= (others => '0');
                        when "010" =>  -- SEQ_DATA
                            if to_integer(sub_ptr) = 0 then
                                seq_ram(to_integer(entry_ptr)).ftw   <= cpu_wdata_i;
                            elsif to_integer(sub_ptr) = 1 then
                                seq_ram(to_integer(entry_ptr)).pow   <= cpu_wdata_i;
                            elsif to_integer(sub_ptr) = 2 then
                                seq_ram(to_integer(entry_ptr)).amp   <= cpu_wdata_i(15 downto 0);
                            elsif to_integer(sub_ptr) = 3 then
                                seq_ram(to_integer(entry_ptr)).env   <= cpu_wdata_i;
                            elsif to_integer(sub_ptr) = 4 then
                                seq_ram(to_integer(entry_ptr)).drag  <= cpu_wdata_i(15 downto 0);
                            elsif to_integer(sub_ptr) = 5 then
                                seq_ram(to_integer(entry_ptr)).delay <= cpu_wdata_i(23 downto 0);
                            end if;
                            if sub_ptr < 5 then
                                sub_ptr <= sub_ptr + 1;
                            else
                                sub_ptr <= (others => '0');
                            end if;
                        when "011" =>  -- SEQ_CTRL
                            if cpu_wdata_i(0) = '1' and state = IDLE then
                                state     <= LOAD;
                                entry_ptr <= (others => '0');
                                play_cnt  <= unsigned(seq_repeat);
                                done      <= '0';
                            end if;
                        when "100" =>  -- SEQ_REPEAT
                            seq_repeat <= cpu_wdata_i;
                        when others =>
                            null;
                    end case;
                end if;

                -- FSM
                case state is
                    when IDLE =>
                        null;

                    when LOAD =>
                        seq_ftw   <= seq_ram(to_integer(entry_ptr)).ftw;
                        seq_pow   <= seq_ram(to_integer(entry_ptr)).pow;
                        seq_amp   <= seq_ram(to_integer(entry_ptr)).amp;
                        seq_env   <= seq_ram(to_integer(entry_ptr)).env;
                        seq_drag  <= seq_ram(to_integer(entry_ptr)).drag;
                        seq_delay <= seq_ram(to_integer(entry_ptr)).delay;
                        state <= TRIGGER;

                    when TRIGGER =>
                        seq_valid <= '1';
                        state <= WAIT_READY;

                    when WAIT_READY =>
                        if ready_i = '1' then
                            state <= NEXT_ENTRY;
                        end if;

                    when NEXT_ENTRY =>
                        if entry_ptr < seq_len - 1 then
                            entry_ptr <= entry_ptr + 1;
                            state <= LOAD;
                        else
                            if play_cnt = 0 then  -- infinite loop
                                entry_ptr <= (others => '0');
                                state <= LOAD;
                            elsif play_cnt > 1 then
                                play_cnt  <= play_cnt - 1;
                                entry_ptr <= (others => '0');
                                state <= LOAD;
                            else  -- play_cnt = 1, last iteration
                                state <= FINISH;
                            end if;
                        end if;

                    when FINISH =>
                        done <= '1';
                        state <= IDLE;
                end case;

            end if;
        end if;
    end process;

    -- Combinational reads
    with cpu_addr_i select cpu_rdata_o <=
        x"000000" & "00000" & std_logic_vector(seq_len) when "000",
        x"000000" & "00000" & std_logic_vector(entry_ptr) when "001",
        (others => '0')                                   when "010",
        x"000000" & "000000" & done & busy_int when "011",
        seq_repeat                                        when "100",
        (others => '0')                                   when others;

    -- Outputs
    ftw_o   <= seq_ftw;
    pow_o   <= seq_pow;
    amp_o   <= seq_amp;
    env_o   <= seq_env;
    drag_o  <= seq_drag;
    delay_o <= seq_delay;
    valid_o <= seq_valid;
    busy_int <= '0' when state = IDLE else '1';
    busy_o  <= busy_int;

end architecture rtl;
