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
        
        we_o         : out std_logic;
        trig_o       : out std_logic
    );
end entity sig_gen_csrs;

architecture rtl of sig_gen_csrs is

    constant BYTE_LANES : natural := DATA_WIDTH / 8;

    constant REG_INC        : unsigned(ADDR_WIDTH-1 downto 0) := to_unsigned(0, ADDR_WIDTH);
    constant REG_PHA        : unsigned(ADDR_WIDTH-1 downto 0) := to_unsigned(4, ADDR_WIDTH);
    constant REG_AMP        : unsigned(ADDR_WIDTH-1 downto 0) := to_unsigned(8, ADDR_WIDTH);
    constant REG_ENV_STEP   : unsigned(ADDR_WIDTH-1 downto 0) := to_unsigned(12, ADDR_WIDTH);
    constant REG_DRAG_COEFF : unsigned(ADDR_WIDTH-1 downto 0) := to_unsigned(16, ADDR_WIDTH);
    constant REG_WE         : unsigned(ADDR_WIDTH-1 downto 0) := to_unsigned(20, ADDR_WIDTH);
    constant REG_TRIG       : unsigned(ADDR_WIDTH-1 downto 0) := to_unsigned(24, ADDR_WIDTH);

    signal ack_reg : std_logic;
    signal dat_reg : std_logic_vector(DATA_WIDTH-1 downto 0);
    
    signal inc_reg        : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal pha_reg        : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal amp_reg        : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal env_step_reg   : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal drag_coeff_reg : std_logic_vector(DATA_WIDTH-1 downto 0);
    
    signal we_reg   : std_logic;
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
                we_reg  <= '0';
                trig_reg <= '0';
            else
                ack_reg <= cyc_i and stb_i and not ack_reg;
                we_reg  <= '0';
                trig_reg <= '0';

                if cyc_i = '1' and stb_i = '1' and ack_reg = '0' then
                    if we_i = '1' then
                        if unsigned(adr_i) = REG_INC then
                            inc_reg <= apply_sel(inc_reg, dat_i, sel_i);
                        elsif unsigned(adr_i) = REG_PHA then
                            pha_reg <= apply_sel(pha_reg, dat_i, sel_i);
                        elsif unsigned(adr_i) = REG_AMP then
                            amp_reg <= apply_sel(amp_reg, dat_i, sel_i);
                        elsif unsigned(adr_i) = REG_ENV_STEP then
                            env_step_reg <= apply_sel(env_step_reg, dat_i, sel_i);
                        elsif unsigned(adr_i) = REG_DRAG_COEFF then
                            drag_coeff_reg <= apply_sel(drag_coeff_reg, dat_i, sel_i);
                        elsif unsigned(adr_i) = REG_WE then
                            we_reg <= sel_i(0) and dat_i(0);
                        elsif unsigned(adr_i) = REG_TRIG then
                            trig_reg <= sel_i(0) and dat_i(0);
                        end if;
                    end if;

                    if unsigned(adr_i) = REG_INC then
                        dat_reg <= inc_reg;
                    elsif unsigned(adr_i) = REG_PHA then
                        dat_reg <= pha_reg;
                    elsif unsigned(adr_i) = REG_AMP then
                        dat_reg <= amp_reg;
                    elsif unsigned(adr_i) = REG_ENV_STEP then
                        dat_reg <= env_step_reg;
                    elsif unsigned(adr_i) = REG_DRAG_COEFF then
                        dat_reg <= drag_coeff_reg;
                    elsif unsigned(adr_i) = REG_WE then
                        dat_reg <= (0 => we_reg, others => '0');
                    elsif unsigned(adr_i) = REG_TRIG then
                        dat_reg <= (0 => trig_reg, others => '0');
                    else
                        dat_reg <= (others => '0');
                    end if;
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
    
    we_o         <= we_reg;
    trig_o       <= trig_reg;

end architecture rtl;
