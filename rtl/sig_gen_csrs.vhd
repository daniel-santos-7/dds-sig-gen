library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity sig_gen_csrs is
    generic (
        DATA_WIDTH : natural := 32;
        ADDR_WIDTH : natural := 5
    );
    port (
        rst_i : in  std_logic;
        clk_i : in  std_logic;
        adr_i : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        cyc_i : in  std_logic;
        stb_i : in  std_logic;
        we_i  : in  std_logic;
        sel_i : in  std_logic_vector(DATA_WIDTH/8-1 downto 0);
        dat_i : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        ack_o : out std_logic;
        dat_o : out std_logic_vector(DATA_WIDTH-1 downto 0);
        
        inc_o        : out std_logic_vector(DATA_WIDTH-1 downto 0);
        pha_o        : out std_logic_vector(DATA_WIDTH-1 downto 0);
        amp_o        : out std_logic_vector(DATA_WIDTH-1 downto 0);
        env_step_o   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        drag_coeff_o : out std_logic_vector(DATA_WIDTH-1 downto 0);
        
        trig_o       : out std_logic
    );
end entity sig_gen_csrs;

architecture rtl of sig_gen_csrs is

    constant BYTE_LANES : natural := DATA_WIDTH / 8;

    constant REG_INC        : integer := 0;
    constant REG_PHA        : integer := 4;
    constant REG_AMP        : integer := 8;
    constant REG_ENV_STEP   : integer := 12;
    constant REG_DRAG_COEFF : integer := 16;
    constant REG_TRIG       : integer := 20;

    signal ack_reg : std_logic;
    signal dat_reg : std_logic_vector(DATA_WIDTH-1 downto 0);
    
    signal inc_reg        : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal pha_reg        : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal amp_reg        : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal env_step_reg   : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal drag_coeff_reg : std_logic_vector(DATA_WIDTH-1 downto 0);
    
    signal trig_reg : std_logic;

    function apply_sel (
        cur : std_logic_vector(DATA_WIDTH-1 downto 0);
        dat : std_logic_vector(DATA_WIDTH-1 downto 0);
        sel : std_logic_vector(BYTE_LANES-1 downto 0)
    ) return std_logic_vector is
        variable res : std_logic_vector(DATA_WIDTH-1 downto 0) := cur;
    begin
        for i in 0 to BYTE_LANES-1 loop
            if sel(i) = '1' then
                res(8*i+7 downto 8*i) := dat(8*i+7 downto 8*i);
            end if;
        end loop;

        return res;
    end function apply_sel;

begin

    csr_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                ack_reg <= '0';
                dat_reg <= (others => '0');
                inc_reg <= (others => '0');
                pha_reg <= (others => '0');
                amp_reg <= (others => '0');
                env_step_reg <= (others => '0');
                drag_coeff_reg <= (others => '0');
                trig_reg <= '0';
            else
                ack_reg <= cyc_i and stb_i and not ack_reg;
                trig_reg <= '0';

                if cyc_i = '1' and stb_i = '1' and ack_reg = '0' then
                    case to_integer(unsigned(adr_i)) is
                        when REG_INC =>
                            if we_i = '1' then
                                inc_reg <= apply_sel(inc_reg, dat_i, sel_i);
                            end if;
                            dat_reg <= inc_reg;

                        when REG_PHA =>
                            if we_i = '1' then
                                pha_reg <= apply_sel(pha_reg, dat_i, sel_i);
                            end if;
                            dat_reg <= pha_reg;

                        when REG_AMP =>
                            if we_i = '1' then
                                amp_reg <= apply_sel(amp_reg, dat_i, sel_i);
                            end if;
                            dat_reg <= amp_reg;

                        when REG_ENV_STEP =>
                            if we_i = '1' then
                                env_step_reg <= apply_sel(env_step_reg, dat_i, sel_i);
                            end if;
                            dat_reg <= env_step_reg;

                        when REG_DRAG_COEFF =>
                            if we_i = '1' then
                                drag_coeff_reg <= apply_sel(drag_coeff_reg, dat_i, sel_i);
                            end if;
                            dat_reg <= drag_coeff_reg;

                        when REG_TRIG =>
                            if we_i = '1' then
                                trig_reg <= sel_i(0) and dat_i(0);
                            end if;
                            dat_reg <= (0 => trig_reg, others => '0');

                        when others =>
                            dat_reg <= (others => '0');
                    end case;
                end if;
            end if;
        end if;
    end process csr_proc;

    ack_o <= ack_reg;
    dat_o <= dat_reg;
    
    inc_o        <= inc_reg;
    pha_o        <= pha_reg;
    amp_o        <= amp_reg;
    env_step_o   <= env_step_reg;
    drag_coeff_o <= drag_coeff_reg;
    
    trig_o       <= trig_reg;

end architecture rtl;
