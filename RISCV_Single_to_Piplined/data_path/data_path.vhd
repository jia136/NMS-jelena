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
      alu_src_b_i         : in  std_logic;
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

  --***************IF faza**********************************
   signal pc_reg_if_s             : std_logic_vector (31 downto 0) := (others=>'0');
   signal pc_next_if_s            : std_logic_vector (31 downto 0) := (others=>'0');
   signal pc_adder_if_s           : std_logic_vector (31 downto 0) := (others=>'0');
   signal instruction_if_s        : std_logic_vector (31 downto 0) := (others=>'0');

   --**************ID faza**********************************
   signal pc_reg_id_s             : std_logic_vector (31 downto 0) := (others=>'0');
   signal pc_adder_id_s           : std_logic_vector (31 downto 0) := (others=>'0');
   signal instruction_id_s        : std_logic_vector (31 downto 0) := (others=>'0');
   signal rs1_data_id_s           : std_logic_vector (31 downto 0) := (others=>'0');
   signal rs2_data_id_s           : std_logic_vector (31 downto 0) := (others=>'0');
   signal rs1_address_id_s        : std_logic_vector (4 downto 0) := (others=>'0');
   signal rs2_address_id_s        : std_logic_vector (4 downto 0) := (others=>'0');
   signal rd_address_id_s         : std_logic_vector (4 downto 0) := (others=>'0');
   signal immediate_extended_id_s : std_logic_vector (31 downto 0) := (others=>'0');
   signal branch_adder_id_s       : std_logic_vector (31 downto 0) := (others=>'0');
   signal jl_adder_id_s           : std_logic_vector (31 downto 0) := (others=>'0');
   signal jl_ex_s                 : std_logic := '0';
   signal jlr_adder_id_s          : std_logic_vector (31 downto 0) := (others=>'0');
   signal jlr_ex_s                : std_logic := '0';
   
   --**************EX faza**********************************
   signal pc_adder_ex_s           : std_logic_vector (31 downto 0) := (others=>'0');
   signal instruction_ex_s        : std_logic_vector (31 downto 0) := (others=>'0');
   signal rs1_data_ex_s           : std_logic_vector (31 downto 0) := (others=>'0');
   signal rs2_data_ex_s           : std_logic_vector (31 downto 0) := (others=>'0');
   signal rd_address_ex_s         : std_logic_vector (4 downto 0) := (others=>'0');
   signal a_ex_s                  : std_logic_vector (31 downto 0) := (others=>'0');
   signal b_ex_s                  : std_logic_vector (31 downto 0) := (others=>'0');
   signal alu_result_ex_s         : std_logic_vector (31 downto 0) := (others=>'0');
   signal alu_zero_ex_s           : std_logic := '0';
   signal alu_of_ex_s             : std_logic := '0';
   signal immediate_extended_ex_s : std_logic_vector (31 downto 0) := (others=>'0');
   
   --**************MEM faza*********************************
   signal pc_adder_mem_s          : std_logic_vector (31 downto 0) := (others=>'0');
   signal rs2_data_mem_s          : std_logic_vector (31 downto 0) := (others=>'0'); 
   signal rd_address_mem_s        : std_logic_vector (4 downto 0) := (others=>'0');
   signal alu_result_mem_s        : std_logic_vector (31 downto 0) := (others=>'0');
   signal data_mem_read_mem_s     : std_logic_vector (31 downto 0) := (others=>'0');
   
   --**************WB faza**********************************
   signal pc_adder_wb_s           : std_logic_vector (31 downto 0) := (others=>'0');
   signal rd_data_wb_s            : std_logic_vector (31 downto 0) := (others=>'0');
   signal rd_address_wb_s         : std_logic_vector (4 downto 0) := (others=>'0');
   signal alu_result_wb_s         : std_logic_vector (31 downto 0) := (others=>'0');
   signal data_mem_read_wb_s      : std_logic_vector (31 downto 0) := (others=>'0');
   
--********************************************************
begin

   --***********Sekvencijalna logika**********************
   --PC brojac 
   pc_proc : process (clk) is
   begin
      if (rising_edge(clk)) then
         if (reset = '0')then
            pc_reg_if_s <= (others => '0');
         else
            pc_reg_if_s <= pc_next_if_s;
         end if;
      end if;
   end process;
   
   --IF/ID registar
   if_id_proc: process(clk) is
   begin
        if (rising_edge(clk)) then
            if (reset = '0') then
                pc_reg_id_s      <= (others => '0');
                pc_adder_id_s    <= (others => '0');
                instruction_id_s <= (others => '0');
            else
                pc_reg_id_s      <= pc_reg_if_s;
                pc_adder_id_s    <= pc_adder_if_s;
                instruction_id_s <= instruction_if_s;        
            end if;
        end if;
   end process if_id_proc;
   
   --ID/EX registar
   id_ex_proc: process(clk) is
   begin
        if (rising_edge(clk)) then
            if (reset = '0') then
                pc_adder_ex_s           <= (others => '0');
                instruction_ex_s        <= (others => '0');
                rs1_data_ex_s           <= (others => '0');
                rs2_data_ex_s           <= (others => '0');
                rd_address_ex_s         <= (others => '0');
                immediate_extended_ex_s <= (others => '0');
            else
                pc_adder_ex_s           <= pc_adder_id_s;
                instruction_ex_s        <= instruction_id_s;
                rs1_data_ex_s           <= rs1_data_id_s;
                rs2_data_ex_s           <= rs2_data_id_s;
                rd_address_ex_s         <= rd_address_id_s;
                immediate_extended_ex_s <= immediate_extended_id_s;            
            end if;
        end if;
   end process id_ex_proc;
   
   --EX/MEM registar
   ex_mem_proc: process(clk) is
   begin
        if (rising_edge(clk)) then
            if (reset = '0') then
                pc_adder_mem_s   <= (others => '0');
                rs2_data_mem_s   <= (others => '0');
                rd_address_mem_s <= (others => '0');
                alu_result_mem_s <= (others => '0');
            else
                pc_adder_mem_s   <= pc_adder_ex_s;
                rs2_data_mem_s   <= rs2_data_ex_s;
                rd_address_mem_s <= rd_address_ex_s;
                alu_result_mem_s <= alu_result_ex_s; 
            end if;
        end if;
   end process ex_mem_proc;
   
   --MEM/WB registar
   mem_wb_proc: process(clk) is
   begin
        if (rising_edge(clk)) then
            if (reset = '0') then
                pc_adder_wb_s      <= (others => '0');
                alu_result_wb_s    <= (others => '0');                
                rd_address_wb_s    <= (others => '0');
                data_mem_read_wb_s <= (others => '0');
            else
                pc_adder_wb_s      <= pc_adder_mem_s;
                alu_result_wb_s    <= alu_result_mem_s;                
                rd_address_wb_s    <= rd_address_mem_s;
                data_mem_read_wb_s <= data_mem_read_mem_s;
            end if;
        end if;
   end process mem_wb_proc;   
   --*****************************************************

   --***********Kombinaciona logika***********************
        
   -- sabirac za uvecavanje programskog brojaca (sledeca instrukcija)
   pc_adder_if_s       <= std_logic_vector(unsigned(pc_reg_if_s) + to_unsigned(4, DATA_WIDTH));
   -- sabirac za uslovne skokove
   branch_adder_id_s   <= std_logic_vector(unsigned(immediate_extended_id_s) + unsigned(pc_reg_id_s));
   -- sabirac za jump link
   jl_adder_id_s       <= std_logic_vector(unsigned(immediate_extended_id_s) + unsigned(pc_reg_id_s));
   -- sabirac za jump link reg
   jlr_adder_id_s      <= std_logic_vector(signed(immediate_extended_id_s) + signed(rs1_data_id_s)) and not std_logic_vector(to_signed(1, DATA_WIDTH));

   -- MUX koji vrsi proveru uslova skoka
   branch_mux: process(a_ex_s, b_ex_s, instruction_ex_s)
   begin
        case instruction_ex_s(14 downto 12) is
            when "000" =>
                if (a_ex_s = b_ex_s) then
                    branch_condition_o <= '1';
                else
                    branch_condition_o <= '0';
                end if;                
            when "001" =>
                if (a_ex_s = b_ex_s) then
                    branch_condition_o <= '0';
                else
                    branch_condition_o <= '1';
                end if;
            when "100" =>
                if (signed(a_ex_s) < signed(b_ex_s)) then
                    branch_condition_o <= '1';
                else
                    branch_condition_o <= '0';
                end if;
            when "101" =>
                if (signed(a_ex_s) >= signed(b_ex_s)) then
                    branch_condition_o <= '1';
                else
                    branch_condition_o <= '0';
                end if;
            when "110" =>
                if (unsigned(a_ex_s) < unsigned(b_ex_s)) then
                    branch_condition_o <= '1';
                else
                    branch_condition_o <= '0';
                end if;
            when "111" =>
                if (unsigned(a_ex_s) >= unsigned(b_ex_s)) then
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
      pc_next_if_s <= pc_adder_if_s when "00",
      branch_adder_id_s             when "01",
      jl_adder_id_s                 when "10",
      jlr_adder_id_s                when others;

   -- MUX koji odredjuje sledecu vrednost za b ulaz ALU jedinice.
   b_s_process: process(alu_src_b_i, immediate_extended_ex_s, rs2_data_ex_s, jump_i) 
   begin
        if (jump_i = '1') then
            b_ex_s <= std_logic_vector(to_unsigned(0, DATA_WIDTH));
        elsif (alu_src_b_i = '0') then
            b_ex_s <= rs2_data_ex_s;
        else
            b_ex_s <= immediate_extended_ex_s;
        end if;
   end process b_s_process;

   -- MUX koji odredjuje sledecu vrednost za a ulaz ALU jedinice.
   with alu_src_a_i select
        a_ex_s <= rs1_data_ex_s when "00",
        pc_adder_ex_s           when "01",
        (others => '0')         when others;

   -- MUX koji odredjuju sta se upisuje u odredisni registar(rd_data_wb_s)

   rd_process: process(mem_to_reg_i, alu_result_wb_s, data_mem_read_wb_s, load_i)
   begin
        if (mem_to_reg_i = '0') then
            rd_data_wb_s <= alu_result_wb_s;
        elsif (load_i = "001") then --LB
            rd_data_wb_s <= (31 downto 8 => data_mem_read_wb_s(7)) & data_mem_read_wb_s(7 downto 0);
        elsif (load_i = "010") then --LH
            rd_data_wb_s <= (31 downto 16 => data_mem_read_wb_s(15)) & data_mem_read_wb_s(15 downto 0);
        elsif (load_i = "011") then --LW
            rd_data_wb_s <= data_mem_read_wb_s;
        elsif (load_i = "100") then --LBU
            rd_data_wb_s <= (31 downto 8 => '0') & data_mem_read_wb_s(7 downto 0);
        elsif (load_i = "101") then --LHU
            rd_data_wb_s <= (31 downto 16 => '0') & data_mem_read_wb_s(15 downto 0);
        else
            rd_data_wb_s <= data_mem_read_wb_s;
        end if;
   end process rd_process;
   --*****************************************************

   --***********Instanciranja*****************************
   rs1_address_id_s <= instruction_id_s(19 downto 15);
   rs2_address_id_s <= instruction_id_s(24 downto 20);
   rd_address_id_s  <= instruction_id_s(11 downto 7);
   
   --Registarska banka
   register_bank_1 : entity work.register_bank
      generic map (
         WIDTH => 32)
      port map (
         clk           => clk,
         reset         => reset,
         rd_we_i       => rd_we_i,
         rs1_address_i => rs1_address_id_s,
         rs2_address_i => rs2_address_id_s,
         rs1_data_o    => rs1_data_id_s,
         rs2_data_o    => rs2_data_id_s,
         rd_address_i  => rd_address_wb_s,
         rd_data_i     => rd_data_wb_s);


   -- Modul za prosirenje immediate polja instrukcije
   immediate_1 : entity work.immediate
      port map (
         instruction_i        => instruction_id_s,
         immediate_extended_o => immediate_extended_id_s
         );

   -- Aritmeticko logicka jedinica
   ALU_1 : entity work.ALU
      generic map (
         WIDTH => DATA_WIDTH)
      port map (
         a_i    => a_ex_s,
         b_i    => b_ex_s,
         op_i   => alu_op_i,
         res_o  => alu_result_ex_s,
         zero_o => alu_zero_ex_s,
         of_o   => alu_of_ex_s);

   --*****************************************************

   --***********Ulazi/Izlazi******************************
   -- Ka controlpath-u
   instruction_o       <= instruction_id_s;
   -- Sa memorijom za instrukcije
   instruction_if_s    <= instr_mem_read_i;
   instr_mem_address_o <= pc_reg_if_s;
   -- Sa memorijom za podatke
   data_mem_address_o  <= alu_result_mem_s;
   data_mem_write_o    <= rs2_data_mem_s;
   data_mem_read_mem_s <= data_mem_read_i;
   
end architecture;


