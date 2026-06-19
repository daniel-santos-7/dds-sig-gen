library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity pulse_fifo is
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
        delay_o : out std_logic_vector(23 downto 0)
    );
end entity pulse_fifo;

architecture rtl of pulse_fifo is

    function clog2(n : natural) return natural is
        variable r : natural := 0;
        variable v : natural := n;
    begin
        while v > 1 loop
            v := v / 2;
            r := r + 1;
        end loop;
        return r;
    end function;

    constant DATA_WIDTH : natural := 2*PHA_ACC_BITS + 88;
    constant PTR_BITS   : natural := clog2(FIFO_DEPTH);
    constant CNT_BITS   : natural := clog2(FIFO_DEPTH + 1);

    type fifo_array_t is array (0 to FIFO_DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);

    signal fifo_mem       : fifo_array_t;
    signal wr_ptr_reg     : unsigned(PTR_BITS-1 downto 0) := (others => '0');
    signal rd_ptr_reg     : unsigned(PTR_BITS-1 downto 0) := (others => '0');
    signal fifo_count_reg : unsigned(CNT_BITS-1 downto 0) := (others => '0');

    signal wr_en     : std_logic;
    signal rd_en     : std_logic;
    signal wr_ready  : std_logic;
    signal rd_valid  : std_logic;
    signal rd_data   : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

    wr_ready <= '0' when fifo_count_reg = FIFO_DEPTH else '1';
    rd_valid <= '1' when fifo_count_reg > 0 else '0';

    ready_o <= wr_ready;
    valid_o <= rd_valid;

    wr_en <= valid_i and wr_ready;
    rd_en <= rd_valid and ready_i;

    wr_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                wr_ptr_reg <= (others => '0');
            elsif wr_en = '1' then
                fifo_mem(to_integer(wr_ptr_reg)) <= ftw_i & pow_i & amp_i & env_i & drag_i & delay_i;
                wr_ptr_reg <= wr_ptr_reg + 1;
            end if;
        end if;
    end process wr_proc;

    rd_data <= fifo_mem(to_integer(rd_ptr_reg));

    rd_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                rd_ptr_reg <= (others => '0');
            elsif rd_en = '1' then
                rd_ptr_reg <= rd_ptr_reg + 1;
            end if;
        end if;
    end process rd_proc;

    count_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                fifo_count_reg <= (others => '0');
            elsif wr_en = '1' and rd_en = '0' then
                fifo_count_reg <= fifo_count_reg + 1;
            elsif rd_en = '1' and wr_en = '0' then
                fifo_count_reg <= fifo_count_reg - 1;
            end if;
        end if;
    end process count_proc;

    ftw_o   <= rd_data(DATA_WIDTH-1 downto DATA_WIDTH-PHA_ACC_BITS);
    pow_o   <= rd_data(DATA_WIDTH-PHA_ACC_BITS-1 downto DATA_WIDTH-2*PHA_ACC_BITS);
    amp_o   <= rd_data(DATA_WIDTH-2*PHA_ACC_BITS-1 downto DATA_WIDTH-2*PHA_ACC_BITS-16);
    env_o   <= rd_data(DATA_WIDTH-2*PHA_ACC_BITS-17 downto DATA_WIDTH-2*PHA_ACC_BITS-48);
    drag_o  <= rd_data(DATA_WIDTH-2*PHA_ACC_BITS-49 downto DATA_WIDTH-2*PHA_ACC_BITS-64);
    delay_o <= rd_data(DATA_WIDTH-2*PHA_ACC_BITS-65 downto 0);

end architecture rtl;