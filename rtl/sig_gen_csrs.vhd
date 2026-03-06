library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity sig_gen_csrs is
    generic (
        DATA_WIDTH : natural := 32
    );
    port (
        rst_i : in  std_logic;
        clk_i : in  std_logic;
        cyc_i : in  std_logic;
        stb_i : in  std_logic;
        we_i  : in  std_logic;
        sel_i : in  std_logic_vector(DATA_WIDTH/8-1 downto 0);
        dat_i : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        ack_o : out std_logic;
        dat_o : out std_logic_vector(DATA_WIDTH-1 downto 0);
        inc_o : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity sig_gen_csrs;

architecture rtl of sig_gen_csrs is

    signal inc_en : std_logic;

    signal inc_reg : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

    inc_en <= stb_i and we_i;

    inc_reg_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                inc_reg <= (others => '0');
            elsif inc_en = '1' then
                for i in 0 to 3 loop
                    if sel_i(i) = '1' then
                        inc_reg(i*8+7 downto i*8) <= dat_i(i*8+7 downto i*8);
                    end if;
                end loop;
            end if;
        end if;
    end process inc_reg_proc; -- inc_reg_proc

    ack_o <= stb_i;
    dat_o <= inc_reg;
    inc_o <= inc_reg;

end architecture rtl;
