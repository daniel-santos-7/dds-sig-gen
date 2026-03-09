library IEEE;
library work;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.sine_lut_pkg.OUT_RES_BITS;

package sig_gen_tb_pkg is

    constant PHA_ACC_BITS : natural := 32;
    subtype pha_acc_t is std_logic_vector(PHA_ACC_BITS-1 downto 0);

    type sig_gen_dut_if_t is record
        rst_i : std_logic;
        we_i  : std_logic;
        inc_i : pha_acc_t;
        pha_i : pha_acc_t;
        amp_i : std_logic_vector(OUT_RES_BITS-1 downto 0);
        sig_o : std_logic_vector(OUT_RES_BITS-1 downto 0);
    end record sig_gen_dut_if_t;

    procedure initialize (
        signal dut_if : inout sig_gen_dut_if_t
    );

    procedure reset (
        signal clk_i  : in std_logic;
        signal dut_if : inout sig_gen_dut_if_t
    );

    procedure write_data (
        signal clk_i  : in std_logic;
        signal dut_if : inout sig_gen_dut_if_t;
        constant data : pha_acc_t;
        constant pha  : pha_acc_t := (others => '0');
        constant amp  : std_logic_vector(OUT_RES_BITS-1 downto 0) := (others => '1')
    );

    function calc_phase_increment (
        constant ACC_BITS : natural;
        constant clk_freq : natural;
        constant out_freq : natural
    ) return std_logic_vector;

end package sig_gen_tb_pkg;

package body sig_gen_tb_pkg is

    procedure initialize (
        signal dut_if : inout sig_gen_dut_if_t
    ) is
    begin
        dut_if.rst_i <= '0';
        dut_if.we_i  <= '0';
        dut_if.inc_i <= (others => '0');
        dut_if.pha_i <= (others => '0');
        dut_if.amp_i <= (others => '0');
        dut_if.sig_o <= (others => 'Z');
    end procedure initialize;

    procedure reset (
        signal clk_i  : in std_logic;
        signal dut_if : inout sig_gen_dut_if_t
    ) is
    begin
        wait until rising_edge(clk_i);
        dut_if.rst_i <= '1';
        wait until rising_edge(clk_i);
        dut_if.rst_i <= '0';
    end procedure reset;

    procedure write_data (
        signal clk_i  : in std_logic;
        signal dut_if : inout sig_gen_dut_if_t;
        constant data : pha_acc_t;
        constant pha  : pha_acc_t := (others => '0');
        constant amp  : std_logic_vector(OUT_RES_BITS-1 downto 0) := (others => '1')
    ) is
    begin
        wait until rising_edge(clk_i);
        dut_if.we_i  <= '1';
        dut_if.inc_i <= data;
        dut_if.pha_i <= pha;
        dut_if.amp_i <= amp;
        wait until rising_edge(clk_i);
        dut_if.we_i  <= '0';
    end procedure write_data;

    function calc_phase_increment (
        constant ACC_BITS : natural;
        constant clk_freq : natural;
        constant out_freq : natural
    ) return std_logic_vector is
        constant x : real := real(2 ** ACC_BITS);
        constant y : real := real(clk_freq/out_freq);
    begin
        return std_logic_vector(to_unsigned(integer(x / y), ACC_BITS));
    end function calc_phase_increment;

end package body sig_gen_tb_pkg;
