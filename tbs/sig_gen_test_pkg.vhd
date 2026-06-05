library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

package sig_gen_test_pkg is

    type test_vector_t is record
        inc : std_logic_vector(31 downto 0);
        pha : std_logic_vector(31 downto 0);
        amp : std_logic_vector(31 downto 0);
    end record test_vector_t;

    type test_vector_array is array (natural range <>) of test_vector_t;
    type real_array is array (natural range <>) of real;

    constant NUM_TESTS     : natural := 128;
    constant CLK_FREQ      : real    := 50.0e6;
    constant PHA_ACC_BITS  : natural := 32;
    constant AMP_MAX       : real    := 4095.0;

    function make_test_vector(f_hz, p_deg, a_pct : real) return test_vector_t;

    function generate_test_vectors (
        freqs   : real_array;
        phases  : real_array;
        amps    : real_array
    ) return test_vector_array;
    function get_test_vector(index : natural) return test_vector_t;

end package sig_gen_test_pkg;

package body sig_gen_test_pkg is

    constant FREQ_HZ   : real_array(0 to 3) := (100000.0, 1000000.0, 10000000.0, 25000000.0);
    constant PHASE_DEG : real_array(0 to 7) := (0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0);
    constant AMP_PCT   : real_array(0 to 3) := (12.5, 50.0, 75.0, 100.0);

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

    function make_test_vector(f_hz, p_deg, a_pct : real) return test_vector_t is
    begin
        return (
            inc => real_to_slv32(f_hz / CLK_FREQ * (2.0 ** PHA_ACC_BITS)),
            pha => real_to_slv32(p_deg / 360.0 * (2.0 ** PHA_ACC_BITS)),
            amp => real_to_slv32(round(a_pct / 100.0 * AMP_MAX))
        );
    end function;

    function generate_test_vectors (
        freqs   : real_array;
        phases  : real_array;
        amps    : real_array
    ) return test_vector_array is
        variable result : test_vector_array(0 to NUM_TESTS-1);
        variable idx : natural := 0;
    begin
        for i in freqs'range loop
            for j in phases'range loop
                for k in amps'range loop
                    result(idx) := make_test_vector(freqs(i), phases(j), amps(k));
                    idx := idx + 1;
                end loop;
            end loop;
        end loop;
        return result;
    end function;

    constant TEST_VECTORS : test_vector_array(0 to NUM_TESTS-1) := generate_test_vectors(FREQ_HZ, PHASE_DEG, AMP_PCT);

    function get_test_vector(index : natural) return test_vector_t is
    begin
        return TEST_VECTORS(index);
    end function;

end package body sig_gen_test_pkg;
