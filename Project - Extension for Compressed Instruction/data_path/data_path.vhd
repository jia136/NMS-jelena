library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.datapath_signals_pkg.all;


entity data_path is
   port(
      -- sinhronizacioni signali
      clk                 : in  std_logic;
      reset               : in  std_logic;
      -- interfejs ka memoriji za instrukcije
      instr_mem_address_o : out std_logic_vector(31 downto 0);
      instr_mem_read_i    : in  std_logic_vector(31 downto 0);
      instruction_o       : out std_logic_vector(31 downto 0);
      -- interfejs ka memoriji za podatke
      data_mem_address_o  : out std_logic_vector(31 downto 0);
      data_mem_write_o    : out std_logic_vector(31 downto 0);
      data_mem_read_i     : in  std_logic_vector(31 downto 0);
      -- kontrolni signali
      mem_to_reg_i        : in  std_logic;
      alu_op_i            : in  std_logic_vector(4 downto 0);
      alu_src_a_i         : in  std_logic;
      alu_src_b_i         : in  std_logic;
      pc_next_sel_i       : in  std_logic_vector(1 downto 0);
      rd_we_i             : in  std_logic;
      jump_i              : in  std_logic;
      load_i              : in  std_logic_vector(2 downto 0);
      branch_condition_o  : out std_logic;
      -- kontrolni signali za prosledjivanje operanada u ranije faze protocne obrade
      alu_forward_a_i     : in  std_logic_vector(1 downto 0);
      alu_forward_b_i     : in  std_logic_vector(1 downto 0);
      branch_forward_a_i  : in  std_logic;
      branch_forward_b_i  : in  std_logic;
      jump_forward_a_i    : in  std_logic;
      -- kontrolni signal za resetovanje if/id registra
      if_id_flush_i       : in  std_logic;
      -- kontrolni signali za zaustavljanje protocne obrade
      pc_en_i             : in  std_logic;
      if_id_en_i          : in  std_logic);

end entity;


architecture Behavioral of data_path is
begin

   --***********  Sekvencijalna logika  ******************
   --Programski brojac
   pc_proc : process (clk) is
   begin
      if (rising_edge(clk)) then
         if (reset = '0')then
            pc_reg_if_s <= (others => '0');
         elsif (pc_en_i = '1') then
            pc_reg_if_s <= pc_next_if_s;
         end if;
      end if;
   end process;

   --IF/ID registar
   if_id : process (clk) is
   begin
      if (rising_edge(clk)) then
         if(if_id_en_i = '1')then
            if (reset = '0' or if_id_flush_i = '1')then
               pc_reg_id_s      <= (others => '0');
               pc_adder_id_s    <= (others => '0');
               instruction_id_s <= (others => '0');
            else
               pc_reg_id_s      <= pc_reg_if_s;
               pc_adder_id_s    <= pc_adder_if_s;
               instruction_id_s <= instruction_if_s;
            end if;
         end if;
      end if;
   end process;

   --ID/EX registar
   id_ex : process (clk) is
   begin
      if (rising_edge(clk)) then
         if (reset = '0')then
            pc_adder_ex_s           <= (others => '0');
            rs1_data_ex_s           <= (others => '0');
            rs2_data_ex_s           <= (others => '0');
            immediate_extended_ex_s <= (others => '0');
            rd_address_ex_s         <= (others => '0');
         else
            pc_adder_ex_s           <= pc_adder_id_s;
            rs1_data_ex_s           <= rs1_data_id_s;
            rs2_data_ex_s           <= rs2_data_id_s;
            immediate_extended_ex_s <= immediate_extended_id_s;
            rd_address_ex_s         <= rd_address_id_s;
         end if;
      end if;
   end process;

   --EX/MEM registar
   ex_mem : process (clk) is
   begin
      if (rising_edge(clk)) then
         if (reset = '0')then
            alu_result_mem_s <= (others => '0');
            rs2_data_mem_s   <= (others => '0');
            pc_adder_mem_s   <= (others => '0');
            rd_address_mem_s <= (others => '0');
         else
            alu_result_mem_s <= alu_result_ex_s;
            rs2_data_mem_s   <= alu_forward_b_ex_s;
            pc_adder_mem_s   <= pc_adder_ex_s;
            rd_address_mem_s <= rd_address_ex_s;
         end if;
      end if;
   end process;

   --MEM/WB registar
   mem_wb : process (clk) is
   begin
      if (rising_edge(clk)) then
         if (reset = '0')then
            alu_result_wb_s    <= (others => '0');
            pc_adder_wb_s      <= (others => '0');
            rd_address_wb_s    <= (others => '0');
            data_mem_read_wb_s <= (others => '0');
         else
            alu_result_wb_s    <= alu_result_mem_s;
            pc_adder_wb_s      <= pc_adder_mem_s;
            rd_address_wb_s    <= rd_address_mem_s;
            data_mem_read_wb_s <= data_mem_read_mem_s;
         end if;
      end if;
   end process;


   --***********  Kombinaciona logika  ***************
   -- mux sabirac za uvecavanje programskog brojaca (sledeca instrukcija)
   -- uvecaj za +4 ako je instrukcija 32-bitna, odnosno za +2 ako je 16-bitna
   pc_adder_if_s <= std_logic_vector(unsigned(pc_reg_if_s) + to_unsigned(4, 32)) when compressed_if_s = '0' else
                    std_logic_vector(unsigned(pc_reg_if_s) + to_unsigned(2, 32));

   -- sabirac za uslovne skokove
   branch_adder_id_s <= std_logic_vector(signed(immediate_extended_id_s) + signed(pc_reg_id_s));
   -- sabirac za jump and link skok
   jal_adder_id_s <= std_logic_vector(signed(immediate_extended_id_s) + signed(pc_reg_id_s));
   -- multiplekser za sabirac za jump and link reg skok   
   jalr_adder_id_s <= std_logic_vector(signed(immediate_extended_id_s) + signed(rs1_data_id_s)) and not std_logic_vector(to_signed(1, 32)) when jump_forward_a_i = '0' else
                      std_logic_vector(signed(immediate_extended_id_s) + signed(alu_result_mem_s))and not std_logic_vector(to_signed(1, 32));

   -- multiplekseri za prosledjivanje operanada komparatoru za proveravanje uslova za skok
   branch_condition_a_ex_s <= alu_result_mem_s when branch_forward_a_i = '1' else
                              rs1_data_id_s;
   branch_condition_b_ex_s <= alu_result_mem_s when branch_forward_b_i = '1' else
                              rs2_data_id_s;

   -- provera uslova za skok
   -- MUX koji vrsi proveru uslova skoka
   branch_mux: process(branch_condition_a_ex_s, branch_condition_b_ex_s, instruction_id_s)
   begin
        branch_condition_o <= '0';
        case instruction_id_s(14 downto 12) is
            when "000" =>
                if (signed(branch_condition_a_ex_s) = signed(branch_condition_b_ex_s)) then
                    branch_condition_o <= '1';
                end if;                
            when "001" =>
                if (signed(branch_condition_a_ex_s) /= signed(branch_condition_b_ex_s)) then
                    branch_condition_o <= '1'; 
                end if;
            when "100" =>
                if (signed(branch_condition_a_ex_s) < signed(branch_condition_b_ex_s)) then
                    branch_condition_o <= '1';
                end if;
            when "101" =>
                if (signed(branch_condition_a_ex_s) >= signed(branch_condition_b_ex_s)) then
                    branch_condition_o <= '1';
                end if;
            when "110" =>
                if (unsigned(branch_condition_a_ex_s) < unsigned(branch_condition_b_ex_s)) then
                    branch_condition_o <= '1';
                end if;
            when "111" =>
                if (unsigned(branch_condition_a_ex_s) >= unsigned(branch_condition_b_ex_s)) then
                    branch_condition_o <= '1';
                end if;
            when others =>
                branch_condition_o <= '0';
        end case;     
   end process branch_mux;
   --branch_condition_o <= '1' when (signed(branch_condition_a_ex_s) = signed(branch_condition_b_ex_s)) else
   --                      '0';

   -- multiplekser za azuriranje programskog brojaca
   with pc_next_sel_i select
      pc_next_if_s <= pc_adder_if_s when "00",
      branch_adder_id_s             when "01",
      jal_adder_id_s                when "10",
      jalr_adder_id_s               when others;

   -- multiplekseri za prosledjivanje operanada iz kasnijih faza pajplajna
   alu_forward_a_ex_s <= rd_data_wb_s when alu_forward_a_i = "01" else
                         alu_result_mem_s when alu_forward_a_i = "10" else
                         rs1_data_ex_s;
   alu_forward_b_ex_s <= rd_data_wb_s when alu_forward_b_i = "01" else
                         alu_result_mem_s when alu_forward_b_i = "10" else
                         rs2_data_ex_s;

   -- multiplekser za biranje 'b' operanda alu jedinice
   b_ex_s_process: process(alu_src_b_i,immediate_extended_ex_s, alu_forward_b_ex_s, jump_i)
   begin
        if (jump_i = '1') then
            b_ex_s <= std_logic_vector(to_unsigned(0, 32));
        elsif (alu_src_b_i = '1') then
            b_ex_s <= immediate_extended_ex_s;
        else
            b_ex_s <= alu_forward_b_ex_s;
        end if;
   end process b_ex_s_process;

   -- multiplekser za biranje 'a' operanda alu jedinice
   a_ex_s <= pc_adder_ex_s when alu_src_a_i = '1' else
             alu_forward_a_ex_s;

   -- multiplekser koji selektuje sta se upisuje u odredisni registar(rd_data_wb_s)
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
   
   -- izdvoji adrese opereanada iz 32-bitne instrukcije
   rs1_address_id_s <= instruction_id_s(19 downto 15);
   rs2_address_id_s <= instruction_id_s(24 downto 20);
   rd_address_id_s  <= instruction_id_s(11 downto 7);


   --***********  Instanciranje modula ***********
   -- Dekompresija instrunkcija
   inst_dec: entity work.instruction_decompression
      generic map (
         WIDTH => 32)
      port map(
        inst_i         => instr_mem_read_i,
        compressed     => compressed_if_s,
        dec_inst_o     => instruction_if_s);
   
   -- Registarska banka
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

   -- Jedinice za prosirivanje konstante (immediate)
   immediate_1 : entity work.immediate
      port map (
         instruction_i        => instruction_id_s,
         immediate_extended_o => immediate_extended_id_s);

   -- ALU jedinica
   ALU_1 : entity work.ALU
      generic map (
         WIDTH => 32)
      port map (
         a_i    => a_ex_s,
         b_i    => b_ex_s,
         op_i   => alu_op_i,
         res_o  => alu_result_ex_s,
         zero_o => alu_zero_ex_s,
         of_o   => alu_of_ex_s);

   --***********  Ulazi/Izlazi  ***************
   -- Ka controlpath-u
   instruction_o       <= instruction_id_s;
   -- Sa memorijom za instrukcije
   instr_mem_address_o <= pc_reg_if_s;
   -- Sa memorijom za podatke
   data_mem_address_o  <= alu_result_mem_s;
   data_mem_write_o    <= rs2_data_mem_s;
   data_mem_read_mem_s <= data_mem_read_i;

end architecture;


