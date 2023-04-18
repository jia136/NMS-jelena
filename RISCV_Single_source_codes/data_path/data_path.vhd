library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity data_path is
   generic (DATA_WIDTH : positive := 32);
   port(
      -- ********* Globalna sinhronizacija ******************
      clk                 : in  std_logic;
      reset               : in  std_logic;
      -- ********* Interfejs ka Memoriji za instrukcije *****
      instr_mem_address_o : out std_logic_vector(31 downto 0);
      instr_mem_read_i    : in  std_logic_vector(31 downto 0);
      instruction_o       : out std_logic_vector(31 downto 0);
      -- ********* Interfejs ka Memoriji za podatke *****
      data_mem_address_o  : out std_logic_vector(31 downto 0);
      data_mem_write_o    : out std_logic_vector(31 downto 0);
      data_mem_read_i     : in  std_logic_vector(31 downto 0);
      -- ********* Kontrolni signali ************************
      mem_to_reg_i        : in  std_logic;
      alu_op_i            : in  std_logic_vector(4 downto 0);
      pc_next_sel_i       : in  std_logic_vector(1 downto 0);
      alu_src_i           : in  std_logic;
      alu_src_a_i         : in  std_logic_vector(1 downto 0);
      jump_i              : in  std_logic;
      rd_we_i             : in  std_logic;
      load_i              : in std_logic_vector(2 downto 0);
      -- ********* Statusni signali *************************
      branch_condition_o  : out std_logic
    -- ******************************************************
      );

end entity;


architecture Behavioral of data_path is
   --**************REGISTRI*********************************   
   signal pc_reg_s, pc_next_s                   : std_logic_vector (31 downto 0);
   --********************************************************
   --**************SIGNALI***********************************
   signal instruction_s                         : std_logic_vector(31 downto 0);
   signal pc_adder_s                            : std_logic_vector(31 downto 0);
   signal branch_adder_s                        : std_logic_vector(31 downto 0);
   signal rs1_data_s, rs2_data_s, rd_data_s     : std_logic_vector(31 downto 0);
   signal immediate_extended_s, extended_data_s : std_logic_vector(31 downto 0);
   -- AlU signali   
   signal alu_zero_s, alu_of_o_s                : std_logic;
   signal b_s, a_s                              : std_logic_vector(31 downto 0);
   signal alu_result_s                          : std_logic_vector(31 downto 0);
   --Signali grananja (eng. branch signals).   
   signal bcc                                   : std_logic;
   signal jump_link_s                           : std_logic_vector(31 downto 0);
   signal jump_link_reg_s                       : std_logic_vector(31 downto 0);
--********************************************************
begin

   --***********Sekvencijalna logika**********************   
   pc_proc : process (clk) is
   begin
      if (rising_edge(clk)) then
         if (reset = '0')then
            pc_reg_s <= (others => '0');
         else
            pc_reg_s <= pc_next_s;
         end if;
      end if;
   end process;
   --*****************************************************

   --***********Kombinaciona logika***********************
   bcc <= instruction_s(12);
      
   -- sabirac za uvecavanje programskog brojaca (sledeca instrukcija)
   pc_adder_s       <= std_logic_vector(unsigned(pc_reg_s) + to_unsigned(4, DATA_WIDTH));
   -- sabirac za uslovne skokove
   branch_adder_s   <= std_logic_vector(unsigned(immediate_extended_s) + unsigned(pc_reg_s));
   -- sabirac za jump link
   jump_link_s      <= std_logic_vector(unsigned(immediate_extended_s) + unsigned(pc_reg_s));
   -- sabirac za jump link reg
   jump_link_reg_s  <= std_logic_vector(signed(immediate_extended_s) + signed(rs1_data_s)) and not std_logic_vector(to_signed(1, DATA_WIDTH));
   -- Provera uslova skoka
   --branch_condition_o <= '1' when a_s = b_s else
   --                      '0';
   -- MUX koji vrsi proveru uslova skoka
   branch_mux: process(a_s, b_s, instruction_s)
   begin
        case instruction_s(14 downto 12) is
            when "000" =>
                if (a_s = b_s) then
                    branch_condition_o <= '1';
                else
                    branch_condition_o <= '0';
                end if;                
            when "001" =>
                if (a_s = b_s) then
                    branch_condition_o <= '0';
                else
                    branch_condition_o <= '1';
                end if;
            when "100" =>
                if (signed(a_s) < signed(b_s)) then
                    branch_condition_o <= '1';
                else
                    branch_condition_o <= '0';
                end if;
            when "101" =>
                if (signed(a_s) >= signed(b_s)) then
                    branch_condition_o <= '1';
                else
                    branch_condition_o <= '0';
                end if;
            when "110" =>
                if (unsigned(a_s) < unsigned(b_s)) then
                    branch_condition_o <= '1';
                else
                    branch_condition_o <= '0';
                end if;
            when "111" =>
                if (unsigned(a_s) >= unsigned(b_s)) then
                    branch_condition_o <= '1';
                else
                    branch_condition_o <= '0';
                end if;
            when others =>
                branch_condition_o <= '0';
        end case;     
   end process branch_mux;

   -- MUX koji odredjuje sledecu vrednost za programski brojac.
   -- Ako se ne desi skok programski brojac se uvecava za 4.
   with pc_next_sel_i select
      pc_next_s <= pc_adder_s when "00",
      branch_adder_s          when "01",
      jump_link_s             when "10",
      jump_link_reg_s         when others;

   -- MUX koji odredjuje sledecu vrednost za b ulaz ALU jedinice.
   b_s_process: process(alu_src_i, immediate_extended_s, rs2_data_s, jump_i) 
   begin
        if (jump_i = '1') then
            b_s <= std_logic_vector(to_unsigned(4, DATA_WIDTH));
        elsif (alu_src_i = '0') then
            b_s <= rs2_data_s;
        else
            b_s <= immediate_extended_s;
        end if;
   end process b_s_process;
   
   --b_s <= rs2_data_s when alu_src_i = '0' else
   --       immediate_extended_s;

   -- MUX koji odredjuje sledecu vrednost za a ulaz ALU jedinice.
   with alu_src_a_i select
        a_s <= rs1_data_s when "00",
        pc_reg_s          when "01",
        (others => '0')   when others;
        
   --a_s <= rs1_data_s when alu_src_a_i = "00" else 
   --       pc_reg_s;
   -- Azuriranje a ulaza ALU jedinice
   --a_s <= rs1_data_s;

   -- MUX koji odredjuju sta se upisuje u odredisni registar(rd_data_s)
   --rd_data_s <= data_mem_read_i when mem_to_reg_i = '1' else
   --            alu_result_s;
   rd_process: process(mem_to_reg_i, alu_result_s, data_mem_read_i, load_i)
   begin
        if (mem_to_reg_i = '0') then
            rd_data_s <= alu_result_s;
        elsif (load_i = "001") then --LB
            rd_data_s <= (31 downto 8 => data_mem_read_i(7)) & data_mem_read_i(7 downto 0);
        elsif (load_i = "010") then --LH
            rd_data_s <= (31 downto 16 => data_mem_read_i(15)) & data_mem_read_i(15 downto 0);
        elsif (load_i = "011") then --LW
            rd_data_s <= data_mem_read_i;
        elsif (load_i = "100") then --LBU
            rd_data_s <= (31 downto 8 => '0') & data_mem_read_i(7 downto 0);
        elsif (load_i = "101") then --LHU
            rd_data_s <= (31 downto 16 => '0') & data_mem_read_i(15 downto 0);
        else
            rd_data_s <= data_mem_read_i;
        end if;
   end process rd_process;
   --*****************************************************

   --***********Instanciranja*****************************

   --Registarska banka
   register_bank_1 : entity work.register_bank
      generic map (
         WIDTH => 32)
      port map (
         clk           => clk,
         reset         => reset,
         rd_we_i       => rd_we_i,
         rs1_address_i => instruction_s (19 downto 15),
         rs2_address_i => instruction_s (24 downto 20),
         rs1_data_o    => rs1_data_s,
         rs2_data_o    => rs2_data_s,
         rd_address_i  => instruction_s (11 downto 7),
         rd_data_i     => rd_data_s);


   -- Modul za prosirenje immediate polja instrukcije
   immediate_1 : entity work.immediate
      port map (
         instruction_i        => instruction_s,
         immediate_extended_o => immediate_extended_s
         );

   -- Aritmeticko logicka jedinica
   ALU_1 : entity work.ALU
      generic map (
         WIDTH => DATA_WIDTH)
      port map (
         a_i    => a_s,
         b_i    => b_s,
         op_i   => alu_op_i,
         res_o  => alu_result_s,
         zero_o => alu_zero_s,
         of_o   => alu_of_o_s);

   --*****************************************************

   --***********Ulazi/Izlazi******************************
   -- Ka controlpath-u
   instruction_o       <= instruction_s;
   -- Sa memorijom za instrukcije
   instruction_s       <= instr_mem_read_i;
   -- Sa memorijom za podatke
   instr_mem_address_o <= pc_reg_s;
   data_mem_address_o  <= alu_result_s;
   data_mem_write_o    <= rs2_data_s;

end architecture;


