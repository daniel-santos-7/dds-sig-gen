library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;
use STD.textio.all;

package sig_gen_tb_pkg is

    constant DATA_WIDTH : natural := 32;
    constant ADDR_WIDTH : natural := 4;

    type test_case_t is record
        test_index : natural;
        freq_hz    : real;
        phase_deg  : real;
        amp_pct    : real;
    end record test_case_t;

    type reg_values_t is record
        inc : std_logic_vector(31 downto 0);
        pha : std_logic_vector(31 downto 0);
        amp : std_logic_vector(31 downto 0);
    end record reg_values_t;

    constant CLK_FREQ      : real    := 50.0e6;
    constant PHA_ACC_BITS  : natural := 32;
    constant AMP_MAX       : real    := 4095.0;

    function img(r : real) return string;
    impure function get_test_case(index : natural; csv_file : string) return test_case_t;
    function to_regs(tv : test_case_t) return reg_values_t;
    procedure write_case_file(file_name : string; tv : test_case_t);
    procedure write_reg_file(file_name : string; regs : reg_values_t);

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
        signal clk   : in std_logic;
        signal wb    : inout wb_bus;
        constant inc  : std_logic_vector(31 downto 0);
        constant pha  : std_logic_vector(31 downto 0);
        constant amp  : std_logic_vector(31 downto 0)
    );

    procedure write_sample (
        signal clk : in std_logic;
        constant file_name : in string;
        signal value : in std_logic_vector;
        constant count : in natural
    );

    procedure wb_reset (
        signal clk : in std_logic;
        signal rst : out std_logic
    );

end package sig_gen_tb_pkg;

package body sig_gen_tb_pkg is

    function real_to_slv32(val : real) return std_logic_vector is
        variable result : unsigned(31 downto 0) := (others => '0');
        variable v : real := val;
    begin
        for i in 0 to 31 loop
            if v >= 2.0 ** (31 - i) then
                result(31 - i) := '1';
                v := v - 2.0 ** (31 - i);
            end if;
        end loop;
        return std_logic_vector(result);
    end function;

    function to_regs(tv : test_case_t) return reg_values_t is
    begin
        return (
            inc => real_to_slv32(tv.freq_hz / CLK_FREQ * (2.0 ** PHA_ACC_BITS)),
            pha => real_to_slv32(tv.phase_deg / 360.0 * (2.0 ** PHA_ACC_BITS)),
            amp => real_to_slv32(round(tv.amp_pct / 100.0 * AMP_MAX))
        );
    end function;

    impure function get_test_case(index : natural; csv_file : string) return test_case_t is
        file f : text;
        variable l : line;
        variable comma : character;
        variable idx_int : integer;
        variable freq : real;
        variable phase : real;
        variable amp : real;
        variable good : boolean;
    begin
        file_open(f, csv_file, read_mode);

        readline(f, l);

        for i in 0 to index loop
            readline(f, l);
        end loop;

        read(l, idx_int, good);
        read(l, comma);
        read(l, freq, good);
        read(l, comma);
        read(l, phase, good);
        read(l, comma);
        read(l, amp, good);

        file_close(f);

        return (test_index => idx_int, freq_hz => freq, phase_deg => phase, amp_pct => amp);
    end function;

    function img(r : real) return string is
        variable n : integer;
    begin
        if r = 0.0 then return "0"; end if;
        n := integer(r);
        if real(n) = r then return integer'image(n); end if;
        n := integer(r * 10.0);
        if real(n) / 10.0 = r then
            return integer'image(n / 10) & "." & integer'image(abs(n mod 10));
        end if;
        return real'image(r);
    end function;

    procedure write_case_file(file_name : string; tv : test_case_t) is
        file f : text open write_mode is file_name;
        variable l : line;
    begin
        write(l, string'("test_index: ") & integer'image(tv.test_index));
        writeline(f, l);
        write(l, string'("freq_hz: ")   & img(tv.freq_hz));
        writeline(f, l);
        write(l, string'("phase_deg: ") & img(tv.phase_deg));
        writeline(f, l);
        write(l, string'("amp_pct: ")   & img(tv.amp_pct));
        writeline(f, l);
    end procedure;

    procedure write_reg_file(file_name : string; regs : reg_values_t) is
        file f : text open write_mode is file_name;
        variable l : line;
    begin
        write(l, string'("inc: 0x"));
        hwrite(l, to_bitvector(regs.inc));
        writeline(f, l);
        write(l, string'("pha: 0x"));
        hwrite(l, to_bitvector(regs.pha));
        writeline(f, l);
        write(l, string'("amp: 0x"));
        hwrite(l, to_bitvector(regs.amp));
        writeline(f, l);
    end procedure;

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
        constant inc : std_logic_vector(31 downto 0);
        constant pha : std_logic_vector(31 downto 0);
        constant amp : std_logic_vector(31 downto 0)
    ) is
        constant WRITE_COMMAND : std_logic_vector(DATA_WIDTH-1 downto 0) := x"00000001";
    begin
        wb_write(clk, wb, REG_INC, inc);
        wb_write(clk, wb, REG_PHA, pha);
        wb_write(clk, wb, REG_AMP, amp);
        wb_write(clk, wb, REG_WE, WRITE_COMMAND);
    end procedure wb_write_config;

    procedure write_sample (
        signal clk : in std_logic;
        constant file_name : in string;
        signal value : in std_logic_vector;
        constant count : in natural
    ) is
        file f : text open write_mode is file_name;
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