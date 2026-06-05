library IEEE;
use IEEE.std_logic_1164.all;

package sig_gen_test_pkg is

    type test_vector_t is record
        inc : std_logic_vector(31 downto 0);
        pha : std_logic_vector(31 downto 0);
        amp : std_logic_vector(31 downto 0);
    end record test_vector_t;

    type test_vector_array is array (natural range <>) of test_vector_t;

    constant NUM_TESTS : natural := 128;

    function generate_test_vectors return test_vector_array;

    function get_test_vector(index : natural) return test_vector_t;

end package sig_gen_test_pkg;

package body sig_gen_test_pkg is

    subtype slv32 is std_logic_vector(31 downto 0);
    type slv32_array is array (natural range <>) of slv32;

    function generate_test_vectors return test_vector_array is
        constant INCS : slv32_array(0 to 3) :=
            (x"0083126F", x"051EB852", x"33333333", x"7FFFFFFF");
        constant PHAS : slv32_array(0 to 7) :=
            (x"00000000", x"10000000", x"20000000", x"30000000",
             x"40000000", x"50000000", x"60000000", x"7FFFFFFF");
        constant AMPS : slv32_array(0 to 3) :=
            (x"00000200", x"00000800", x"00000C00", x"00000FFF");
        variable result : test_vector_array(0 to NUM_TESTS-1);
        variable idx : natural := 0;
    begin
        for i in INCS'range loop
            for j in PHAS'range loop
                for k in AMPS'range loop
                    result(idx) := (inc => INCS(i), pha => PHAS(j), amp => AMPS(k));
                    idx := idx + 1;
                end loop;
            end loop;
        end loop;
        return result;
    end function;

    constant TEST_VECTORS : test_vector_array(0 to NUM_TESTS-1) := generate_test_vectors;

    function get_test_vector(index : natural) return test_vector_t is
    begin
        return TEST_VECTORS(index);
    end function;

end package body sig_gen_test_pkg;
