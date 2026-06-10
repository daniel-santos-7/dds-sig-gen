library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;
use STD.textio.all;

package sig_gen_tb_pkg is

    constant DATA_WIDTH : natural := 32;
    constant ADDR_WIDTH : natural := 3;

    type test_case_t is record
        freq_hz    : real;
        phase_deg  : real;
        amp_val    : real;
        pulse_len  : natural;
        drag_coeff : real;
    end record test_case_t;

    type reg_values_t is record
        ftw        : std_logic_vector(31 downto 0);
        pow        : std_logic_vector(31 downto 0);
        amp        : std_logic_vector(31 downto 0);
        env_step   : std_logic_vector(31 downto 0);
        drag_coeff : std_logic_vector(31 downto 0);
    end record reg_values_t;

    constant CLK_FREQ      : real    := 100.0e6;
    constant PHA_ACC_BITS  : natural := 32;

    function img(r : real) return string;
    function to_regs(tv : test_case_t) return reg_values_t;
    procedure write_case_file(file_name : string; tv : test_case_t);
    procedure write_reg_file(file_name : string; regs : reg_values_t);

    constant REG_FTW        : std_logic_vector(ADDR_WIDTH-1 downto 0) := "000"; -- 0x0
    constant REG_POW        : std_logic_vector(ADDR_WIDTH-1 downto 0) := "001"; -- 0x1
    constant REG_AMP        : std_logic_vector(ADDR_WIDTH-1 downto 0) := "010"; -- 0x2
    constant REG_ENV_STEP   : std_logic_vector(ADDR_WIDTH-1 downto 0) := "011"; -- 0x3
    constant REG_DRAG_COEFF : std_logic_vector(ADDR_WIDTH-1 downto 0) := "100"; -- 0x4
    constant REG_TRIG       : std_logic_vector(ADDR_WIDTH-1 downto 0) := "101"; -- 0x5

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

    procedure wb_read (
        signal clk  : in std_logic;
        signal wb   : inout wb_bus;
        constant adr : std_logic_vector(ADDR_WIDTH-1 downto 0);
        variable dat : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );

    procedure wb_write_config (
        signal clk   : in std_logic;
        signal wb    : inout wb_bus;
        constant regs : reg_values_t
    );

    procedure write_iq_sample (
        signal clk : in std_logic;
        constant file_name : in string;
        signal sig_i : in std_logic_vector;
        signal sig_q : in std_logic_vector;
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
        variable step_val : real;
        variable drag_val : integer;
    begin
        -- ENV_STEP: step size so accumulator reaches 2^32 in pulse_len cycles
        -- step = 2^32 / pulse_len
        step_val := (2.0**32) / real(tv.pulse_len);
        
        -- DRAG_COEFF: signed Q1.15
        drag_val := integer(tv.drag_coeff * 32768.0);
        if drag_val > 32767 then drag_val := 32767; end if;
        if drag_val < -32768 then drag_val := -32768; end if;
        
        return (
        ftw        => real_to_slv32(tv.freq_hz / CLK_FREQ * (2.0 ** PHA_ACC_BITS)),
        pow        => real_to_slv32(tv.phase_deg / 360.0 * (2.0 ** PHA_ACC_BITS)),
            amp        => real_to_slv32(tv.amp_val),
            env_step   => std_logic_vector(to_unsigned(integer(step_val), 32)),
            drag_coeff => std_logic_vector(to_signed(drag_val, 32))
        );
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
        write(l, string'("freq_hz: ")   & img(tv.freq_hz)); writeline(f, l);
        write(l, string'("phase_deg: ") & img(tv.phase_deg)); writeline(f, l);
        write(l, string'("amp_val: ")   & img(tv.amp_val)); writeline(f, l);
        write(l, string'("pulse_len: ") & integer'image(tv.pulse_len)); writeline(f, l);
        write(l, string'("drag_coeff: ") & img(tv.drag_coeff)); writeline(f, l);
    end procedure;

    procedure write_reg_file(file_name : string; regs : reg_values_t) is
        file f : text open write_mode is file_name;
        variable l : line;
    begin
        write(l, string'("ftw: 0x")); hwrite(l, to_bitvector(regs.ftw)); writeline(f, l);
        write(l, string'("pow: 0x")); hwrite(l, to_bitvector(regs.pow)); writeline(f, l);
        write(l, string'("amp: 0x")); hwrite(l, to_bitvector(regs.amp)); writeline(f, l);
        write(l, string'("env_step: 0x")); hwrite(l, to_bitvector(regs.env_step)); writeline(f, l);
        write(l, string'("drag_coeff: 0x")); hwrite(l, to_bitvector(regs.drag_coeff)); writeline(f, l);
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

    procedure wb_read (
        signal clk  : in std_logic;
        signal wb   : inout wb_bus;
        constant adr : std_logic_vector(ADDR_WIDTH-1 downto 0);
        variable dat : out std_logic_vector(DATA_WIDTH-1 downto 0)
    ) is
    begin
        wait until rising_edge(clk);
        wb.adr_i <= adr;
        wb.sel_i <= (others => '1');
        wb.cyc_i <= '1';
        wb.stb_i <= '1';
        wb.we_i  <= '0';
        wait until rising_edge(clk) and wb.ack_o = '1';
        dat := wb.dat_o;
        wb.cyc_i <= '0';
        wb.stb_i <= '0';
        wb.sel_i <= (others => '0');
    end procedure wb_read;

    procedure wb_write_config (
        signal clk   : in std_logic;
        signal wb    : inout wb_bus;
        constant regs : reg_values_t
    ) is
        constant WRITE_COMMAND : std_logic_vector(DATA_WIDTH-1 downto 0) := x"00000001";
    begin
        wb_write(clk, wb, REG_FTW, regs.ftw);
        wb_write(clk, wb, REG_POW, regs.pow);
        wb_write(clk, wb, REG_AMP, regs.amp);
        wb_write(clk, wb, REG_ENV_STEP, regs.env_step);
        wb_write(clk, wb, REG_DRAG_COEFF, regs.drag_coeff);
        wb_write(clk, wb, REG_TRIG, WRITE_COMMAND);
    end procedure wb_write_config;

    procedure write_iq_sample (
        signal clk : in std_logic;
        constant file_name : in string;
        signal sig_i : in std_logic_vector;
        signal sig_q : in std_logic_vector;
        constant count : in natural
    ) is
        file f : text open write_mode is file_name;
        variable l : line;
    begin
        for i in 0 to count-1 loop
            wait until rising_edge(clk);
            write(l, to_integer(unsigned(sig_i)));
            write(l, string'(","));
            write(l, to_integer(unsigned(sig_q)));
            writeline(f, l);
        end loop;
    end procedure write_iq_sample;

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