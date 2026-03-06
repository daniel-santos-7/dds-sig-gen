library IEEE;
use IEEE.std_logic_1164.all;

package sig_gen_tb_pkg is

    constant WB_DATA_WIDTH : natural := 32;
    constant WB_SEL_WIDTH  : natural := WB_DATA_WIDTH/8;

    subtype wb_sel_t  is std_logic_vector(WB_SEL_WIDTH-1 downto 0);
    subtype wb_data_t is std_logic_vector(WB_DATA_WIDTH-1 downto 0);

    type sig_gen_dut_if_t is record
        rst_i : std_logic;
        cyc_i : std_logic;
        stb_i : std_logic;
        we_i  : std_logic;
        sel_i : wb_sel_t;
        dat_i : wb_data_t;
        ack_o : std_logic;
        dat_o : wb_data_t;
        sig_o : wb_data_t;
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
        constant data : wb_data_t;
        constant sel  : wb_sel_t := (others => '1')
    );

end package sig_gen_tb_pkg;

package body sig_gen_tb_pkg is

    procedure initialize (
        signal dut_if : inout sig_gen_dut_if_t
    ) is
    begin
        dut_if.rst_i <= '0';
        dut_if.cyc_i <= '0';
        dut_if.stb_i <= '0';
        dut_if.we_i  <= '0';
        dut_if.sel_i <= (others => '0');
        dut_if.dat_i <= (others => '0');
        dut_if.ack_o <= 'Z';
        dut_if.dat_o <= (others => 'Z');
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
        constant data : wb_data_t;
        constant sel  : wb_sel_t := (others => '1')
    ) is
    begin
        wait until rising_edge(clk_i);
        dut_if.cyc_i <= '1';
        dut_if.stb_i <= '1';
        dut_if.we_i  <= '1';
        dut_if.sel_i <= sel;
        dut_if.dat_i <= data;

        while dut_if.ack_o = '0' loop
            wait until rising_edge(clk_i);
        end loop;

        dut_if.cyc_i <= '0';
        dut_if.stb_i <= '0';
        dut_if.we_i  <= '0';
    end procedure write_data;

end package body sig_gen_tb_pkg;
