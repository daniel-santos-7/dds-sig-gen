library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.sig_gen_pkg.all;
use work.sig_gen_tb_pkg.all;
use work.sine_lut_pkg.LUT_ADDR_BITS;
use work.sine_lut_pkg.OUT_RES_BITS;

entity sig_gen_tb is
    generic (
        PHA_ACC_BITS  : natural := 32;
        CLK_FREQUENCY : natural := 50e6;
        OUT_FREQUENCY : natural := 1e6
    );
end sig_gen_tb;

architecture tb of sig_gen_tb is

    constant CLK_PERIOD : time := (1 sec / CLK_FREQUENCY);
    constant FULL_AMP : std_logic_vector(OUT_RES_BITS-1 downto 0) := (others => '1');
    constant HALF_AMP : std_logic_vector(OUT_RES_BITS-1 downto 0) := std_logic_vector(to_unsigned(2**(OUT_RES_BITS-1)-1, OUT_RES_BITS));
    constant ZERO_PHA : std_logic_vector(PHA_ACC_BITS-1 downto 0) := (others => '0');
    constant QUARTER_PHA : std_logic_vector(PHA_ACC_BITS-1 downto 0) := std_logic_vector(to_unsigned(2**(PHA_ACC_BITS-2), PHA_ACC_BITS));
    constant THREE_QUARTER_PHA : std_logic_vector(PHA_ACC_BITS-1 downto 0) := std_logic_vector(unsigned(QUARTER_PHA) + unsigned(QUARTER_PHA) + unsigned(QUARTER_PHA));
    constant EXPECTED_PERIOD_CYCLES : natural := CLK_FREQUENCY / OUT_FREQUENCY;

    signal clk_en : boolean := false;

    signal clk_i : std_logic := '0';

    signal dut_if : sig_gen_dut_if_t;
    signal sig_o : std_logic_vector(OUT_RES_BITS-1 downto 0);

    constant PHA_INC : std_logic_vector(PHA_ACC_BITS-1 downto 0) := calc_phase_increment(PHA_ACC_BITS, CLK_FREQUENCY, OUT_FREQUENCY);

    constant OUT_PERIOD : time := (1 sec / OUT_FREQUENCY);

    function has_unknown(slv : std_logic_vector) return boolean is
    begin
        for i in slv'range loop
            if slv(i) /= '0' and slv(i) /= '1' then
                return true;
            end if;
        end loop;
        return false;
    end function has_unknown;

begin

    -- Instantiate the unit under test --
    uut : sig_gen generic map (
        PHA_ACC_BITS => PHA_ACC_BITS
    ) port map (
        clk_i => clk_i,
        rst_i => dut_if.rst_i,
        we_i  => dut_if.we_i,
        inc_i => dut_if.inc_i,
        pha_i => dut_if.pha_i,
        amp_i => dut_if.amp_i,
        sig_o => sig_o
    );

    -- Clock generation --
    clk_i <= not clk_i after (CLK_PERIOD/2) when clk_en else '0';

    -- Test stimulus --
    stim_process : process
        variable sample : integer;
        variable prev_sample : integer;
        variable cycle_cnt : natural;
        variable first_cross_cycle : natural;
        variable second_cross_cycle : natural;
        variable cross_count : natural;
        variable peak_full : integer;
        variable peak_half : integer;
        variable settle_cycles : natural;
    begin
        clk_en <= true;
        initialize(dut_if);
        reset(clk_i, dut_if);

        -- Phase check: quarter-wave should be positive, three-quarter should be negative.
        write_data(clk_i, dut_if, (others => '0'), QUARTER_PHA, FULL_AMP);
        for i in 1 to 4 loop
            wait until rising_edge(clk_i);
        end loop;
        settle_cycles := 0;
        while has_unknown(sig_o) loop
            wait until rising_edge(clk_i);
            settle_cycles := settle_cycles + 1;
            assert settle_cycles < 32
                report "sig_o did not settle to known value (quarter phase)"
                severity failure;
        end loop;
        assert not has_unknown(sig_o)
            report "sig_o contains unknown value after phase setup (quarter phase)"
            severity failure;
        assert to_integer(signed(sig_o)) > 0
            report "phase check failed: quarter phase did not produce positive output"
            severity failure;

        write_data(clk_i, dut_if, (others => '0'), THREE_QUARTER_PHA, FULL_AMP);
        for i in 1 to 4 loop
            wait until rising_edge(clk_i);
        end loop;
        settle_cycles := 0;
        while has_unknown(sig_o) loop
            wait until rising_edge(clk_i);
            settle_cycles := settle_cycles + 1;
            assert settle_cycles < 32
                report "sig_o did not settle to known value (three-quarter phase)"
                severity failure;
        end loop;
        assert not has_unknown(sig_o)
            report "sig_o contains unknown value after phase setup (three-quarter phase)"
            severity failure;
        assert to_integer(signed(sig_o)) < 0
            report "phase check failed: three-quarter phase did not produce negative output"
            severity failure;

        -- Frequency check: measure cycles between two positive-going zero crossings.
        write_data(clk_i, dut_if, PHA_INC, ZERO_PHA, FULL_AMP);
        for i in 1 to 8 loop
            wait until rising_edge(clk_i);
        end loop;
        settle_cycles := 0;
        while has_unknown(sig_o) loop
            wait until rising_edge(clk_i);
            settle_cycles := settle_cycles + 1;
            assert settle_cycles < 32
                report "sig_o did not settle to known value (frequency check)"
                severity failure;
        end loop;

        prev_sample := to_integer(signed(sig_o));
        cycle_cnt := 0;
        cross_count := 0;
        first_cross_cycle := 0;
        second_cross_cycle := 0;

        while cross_count < 2 loop
            wait until rising_edge(clk_i);
            cycle_cnt := cycle_cnt + 1;
            assert not has_unknown(sig_o)
                report "sig_o contains unknown value during frequency check"
                severity failure;
            sample := to_integer(signed(sig_o));
            if prev_sample <= 0 and sample > 0 then
                cross_count := cross_count + 1;
                if cross_count = 1 then
                    first_cross_cycle := cycle_cnt;
                else
                    second_cross_cycle := cycle_cnt;
                end if;
            end if;
            prev_sample := sample;
            assert cycle_cnt < 500
                report "frequency check failed: could not detect two zero crossings"
                severity failure;
        end loop;

        assert second_cross_cycle - first_cross_cycle >= EXPECTED_PERIOD_CYCLES - 1 and
               second_cross_cycle - first_cross_cycle <= EXPECTED_PERIOD_CYCLES + 1
            report "frequency check failed: measured output period is out of tolerance"
            severity failure;

        -- Amplitude check: half-scale amplitude should reduce peak magnitude ~50%.
        peak_full := 0;
        for i in 1 to 128 loop
            wait until rising_edge(clk_i);
            sample := abs(to_integer(signed(sig_o)));
            if sample > peak_full then
                peak_full := sample;
            end if;
        end loop;

        write_data(clk_i, dut_if, PHA_INC, ZERO_PHA, HALF_AMP);
        for i in 1 to 8 loop
            wait until rising_edge(clk_i);
        end loop;
        settle_cycles := 0;
        while has_unknown(sig_o) loop
            wait until rising_edge(clk_i);
            settle_cycles := settle_cycles + 1;
            assert settle_cycles < 32
                report "sig_o did not settle to known value (amplitude check)"
                severity failure;
        end loop;

        peak_half := 0;
        for i in 1 to 128 loop
            wait until rising_edge(clk_i);
            sample := abs(to_integer(signed(sig_o)));
            if sample > peak_half then
                peak_half := sample;
            end if;
        end loop;

        assert peak_half < peak_full
            report "amplitude check failed: half-scale amplitude did not reduce output peak"
            severity failure;
        assert peak_half >= (peak_full*9)/20 and peak_half <= (peak_full*11)/20
            report "amplitude check failed: half-scale peak is outside expected tolerance"
            severity failure;

        wait for OUT_PERIOD;
        clk_en <= false;
        wait;
    end process stim_process;

end tb;
