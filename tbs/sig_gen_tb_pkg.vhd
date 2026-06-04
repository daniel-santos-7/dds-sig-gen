library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use STD.textio.all;

package sig_gen_tb_pkg is

    constant DATA_WIDTH : natural := 32;
    constant ADDR_WIDTH : natural := 4;

    constant REG_INC : std_logic_vector(ADDR_WIDTH-1 downto 0) := x"0";
    constant REG_PHA : std_logic_vector(ADDR_WIDTH-1 downto 0) := x"4";
    constant REG_AMP : std_logic_vector(ADDR_WIDTH-1 downto 0) := x"8";
    constant REG_WE  : std_logic_vector(ADDR_WIDTH-1 downto 0) := x"c";

    type wb_bus is record
        adr_i : std_logic_vector(ADDR_WIDTH-1 downto 0);
        cyc_i : std_logic;
        stb_i : std_logic;
        we_i  : std_logic;
        sel_i : std_logic_vector(DATA_WIDTH/8-1 downto 0);
        dat_i : std_logic_vector(DATA_WIDTH-1 downto 0);
        dat_o : std_logic_vector(DATA_WIDTH-1 downto 0);
        ack_o : std_logic;
    end record wb_bus;

    procedure wb_init (
        signal wb : inout wb_bus
    );

    procedure wb_write (
        signal clk : in std_logic;
        signal wb : inout wb_bus;
        constant adr : std_logic_vector(ADDR_WIDTH-1 downto 0);
        constant dat : std_logic_vector(DATA_WIDTH-1 downto 0)
    );

    procedure wb_write_config (
        signal clk : in std_logic;
        signal wb : inout wb_bus;
        constant inc  : natural;
        constant pha  : natural;
        constant amp  : natural
    );

    procedure write_sample (
        signal clk : in std_logic;
        file f : text;
        signal value : in std_logic_vector;
        constant count : in natural
    );

    procedure wb_reset (
        signal clk : in std_logic;
        signal rst : out std_logic
    );

end package sig_gen_tb_pkg;

package body sig_gen_tb_pkg is

    procedure wb_init (
        signal wb : inout wb_bus
    ) is
    begin
        wb.adr_i <= (others => '0');
        wb.cyc_i <= '0';
        wb.stb_i <= '0';
        wb.we_i  <= '0';
        wb.sel_i <= (others => '0');
        wb.dat_i <= (others => '0');
        wb.dat_o <= (others => 'Z');
        wb.ack_o <= 'Z';
    end procedure wb_init;

    procedure wb_write (
        signal clk   : in std_logic;
        signal wb    : inout wb_bus;
        constant adr : std_logic_vector(ADDR_WIDTH-1 downto 0);
        constant dat : std_logic_vector(DATA_WIDTH-1 downto 0)
    ) is
    begin
        wait until rising_edge(clk);
        wb.adr_i <= adr;
        wb.dat_i <= dat;
        wb.sel_i <= (others => '1');
        wb.cyc_i <= '1';
        wb.stb_i <= '1';
        wb.we_i  <= '1';
        wait until rising_edge(clk) and wb.ack_o = '1';
        wb.cyc_i <= '0';
        wb.stb_i <= '0';
        wb.we_i  <= '0';
        wb.sel_i <= (others => '0');
        wb.dat_i <= (others => '0');
    end procedure wb_write;

    procedure wb_write_config (
        signal clk   : in std_logic;
        signal wb    : inout wb_bus;
        constant inc : natural;
        constant pha : natural;
        constant amp : natural
    ) is
        constant WRITE_COMMAND : std_logic_vector(DATA_WIDTH-1 downto 0) := x"00000001";
    begin
        wb_write(clk, wb, REG_INC, std_logic_vector(to_unsigned(inc, DATA_WIDTH)));
        wb_write(clk, wb, REG_PHA, std_logic_vector(to_unsigned(pha, DATA_WIDTH)));
        wb_write(clk, wb, REG_AMP, std_logic_vector(to_unsigned(amp, DATA_WIDTH)));
        wb_write(clk, wb, REG_WE, WRITE_COMMAND);
    end procedure wb_write_config;

    procedure write_sample (
        signal clk : in std_logic;
        file f : text;
        signal value : in std_logic_vector;
        constant count : in natural
    ) is
        variable l : line;
    begin
        for i in 0 to count-1 loop
            wait until rising_edge(clk);
            write(l, to_integer(unsigned(value)));
            writeline(f, l);
        end loop;
    end procedure write_sample;

    procedure wb_reset (
        signal clk : in std_logic;
        signal rst : out std_logic
    ) is
    begin
        wait until rising_edge(clk);
        rst <= '1';
        wait until rising_edge(clk);
        rst <= '0';
    end procedure wb_reset;

end package body sig_gen_tb_pkg;