library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;
use STD.textio.all;

package sig_gen_test_pkg is

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

end package sig_gen_test_pkg;

package body sig_gen_test_pkg is

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
        variable regs : reg_values_t;
    begin
        regs := to_regs(tv);
        write(l, string'("test_index: ") & integer'image(tv.test_index));
        writeline(f, l);
        write(l, string'("freq_hz: ")   & img(tv.freq_hz));
        writeline(f, l);
        write(l, string'("phase_deg: ") & img(tv.phase_deg));
        writeline(f, l);
        write(l, string'("amp_pct: ")   & img(tv.amp_pct));
        writeline(f, l);
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

end package body sig_gen_test_pkg;
