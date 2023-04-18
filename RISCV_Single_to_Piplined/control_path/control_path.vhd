library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity control_path is
   port (clk                : in  std_logic;
         reset              : in  std_logic;
         -- ********* Interfejs za prihvat instrukcije iz datapath-a*********
         instruction_i      : in  std_logic_vector (31 downto 0);
         -- ********* Kontrolni intefejs ************************************* 
         mem_to_reg_o       : out std_logic;
         alu_op_o           : out std_logic_vector(4 downto 0);
         pc_next_sel_o      : out std_logic_vector(1 downto 0);         
         alu_src_b_o        : out std_logic;
         alu_src_a_o        : out std_logic_vector(1 downto 0);
         jump_o             : out std_logic;
         rd_we_o            : out std_logic;
         load_o             : out std_logic_vector(2 downto 0);   
         --********** Ulazni Statusni interfejs **************************************
         branch_condition_i : in  std_logic;
         --********** Izlazni Statusni interfejs **************************************
         data_mem_we_o      : out std_logic_vector(3 downto 0)
         );
end entity;


architecture behavioral of control_path is
   --**********ID faza*************************
   signal alu_2bit_op_id_s  : std_logic_vector(1 downto 0) := (others=>'0');
   signal funct3_id_s       : std_logic_vector(2 downto 0) := (others=>'0');
   signal funct7_id_s       : std_logic_vector(6 downto 0) := (others=>'0');
   signal alu_src_a_id_s    : std_logic_vector(1 downto 0) := (others=>'0');
   signal alu_src_b_id_s    : std_logic := '0';
   signal data_mem_we_id_s  : std_logic_vector(3 downto 0) := (others=>'0');
   signal mem_to_reg_id_s   : std_logic := '0';
   signal rd_we_id_s        : std_logic := '0';
   signal branch_id_s       : std_logic := '0';
   signal jump_id_s         : std_logic_vector(1 downto 0) := (others=>'0'); 
   signal load_id_s         : std_logic_vector(2 downto 0) := (others=>'0'); 
   
   --**********EX faza************************
   signal alu_2bit_op_ex_s  : std_logic_vector(1 downto 0) := (others=>'0');
   signal funct3_ex_s       : std_logic_vector(2 downto 0) := (others=>'0');
   signal funct7_ex_s       : std_logic_vector(6 downto 0) := (others=>'0');
   signal alu_src_a_ex_s    : std_logic_vector(1 downto 0) := (others=>'0');
   signal alu_src_b_ex_s    : std_logic := '0';
   signal data_mem_we_ex_s  : std_logic_vector(3 downto 0) := (others=>'0');
   signal mem_to_reg_ex_s   : std_logic := '0';
   signal rd_we_ex_s        : std_logic := '0';
   signal branch_ex_s       : std_logic := '0';
   signal jump_ex_s         : std_logic_vector(1 downto 0) := (others=>'0');
   signal load_ex_s         : std_logic_vector(2 downto 0) := (others=>'0'); 
   
   --*********MEM faza************************
   signal data_mem_we_mem_s : std_logic_vector(3 downto 0) := (others=>'0');
   signal mem_to_reg_mem_s  : std_logic := '0';
   signal rd_we_mem_s       : std_logic := '0';
   
   --*********WB faza*************************
   signal mem_to_reg_wb_s   : std_logic := '0';
   signal rd_we_wb_s        : std_logic := '0';

begin

   --*************Sekvencijalna logika*****************
   --ID/EX registar
   id_ex_proc: process(clk) is
   begin
        if (rising_edge(clk)) then
            if (reset = '0') then
                alu_2bit_op_ex_s  <= (others => '0');
                funct3_ex_s       <= (others => '0');
                funct7_ex_s       <= (others => '0');
                alu_src_a_ex_s    <= (others => '0');
                alu_src_b_ex_s    <= '0';
                data_mem_we_ex_s  <= (others => '0');
                mem_to_reg_ex_s   <= '0';
                rd_we_ex_s        <= '0';
                branch_ex_s       <= '0';
                jump_ex_s         <= (others => '0');
                load_ex_s         <= (others => '0');
            else
                alu_2bit_op_ex_s  <= alu_2bit_op_id_s;
                funct3_ex_s       <= funct3_id_s;
                funct7_ex_s       <= funct7_id_s;
                alu_src_a_ex_s    <= alu_src_a_id_s;
                alu_src_b_ex_s    <= alu_src_b_id_s;
                data_mem_we_ex_s  <= data_mem_we_id_s;
                mem_to_reg_ex_s   <= mem_to_reg_id_s;
                rd_we_ex_s        <= rd_we_id_s;
                branch_ex_s       <= branch_id_s;
                jump_ex_s         <= jump_id_s;
                load_ex_s         <= load_id_s;
            end if;
        end if;
   end process id_ex_proc;
   
   --EX/MEM registar
   ex_mem_proc: process(clk) is
   begin
        if (rising_edge(clk)) then
            if (reset = '0') then
                mem_to_reg_mem_s  <= '0';
                data_mem_we_mem_s <= (others => '0');
                rd_we_mem_s       <= '0';
            else
                mem_to_reg_mem_s  <= mem_to_reg_ex_s;
                data_mem_we_mem_s <= data_mem_we_ex_s;
                rd_we_mem_s       <= rd_we_ex_s;
            end if;
        end if;
   end process ex_mem_proc;

   --MEM/WB registar
   mem_wb_proc: process(clk) is
   begin
        if (rising_edge(clk)) then
            if (reset = '0') then
                mem_to_reg_wb_s <= '0';
                rd_we_wb_s      <= '0';
            else
                mem_to_reg_wb_s <= mem_to_reg_mem_s;
                rd_we_wb_s      <= rd_we_mem_s;
            end if;
        end if;
   end process mem_wb_proc;
   
   --*************Kombinaciona logika*****************
   funct7_id_s <= instruction_i(31 downto 25);
   funct3_id_s <= instruction_i(14 downto 12);
   
   process (branch_condition_i, branch_id_s, jump_id_s)is
   begin
      pc_next_sel_o <= "00";
      if (branch_id_s = '1' and branch_condition_i = '1')then
         pc_next_sel_o <= "01";
      elsif (jump_id_s = "01") then
         pc_next_sel_o <= "10";
      elsif (jump_id_s = "10") then
         pc_next_sel_o <= "11";
      end if;
   end process;
                    
   ctrl_dec : entity work.ctrl_decoder(behavioral)
      port map(
         opcode_i      => instruction_i(6 downto 0),
         funct3_i      => instruction_i(14 downto 12),
         branch_o      => branch_id_s,
         mem_to_reg_o  => mem_to_reg_id_s,
         data_mem_we_o => data_mem_we_id_s,
         alu_src_b_o   => alu_src_b_id_s,
         alu_src_a_o   => alu_src_a_id_s,
         rd_we_o       => rd_we_id_s,
         alu_2bit_op_o => alu_2bit_op_id_s,
         jump_o        => jump_id_s,
         load_o        => load_id_s);

   alu_dec : entity work.alu_decoder(behavioral)
      port map(
         alu_2bit_op_i => alu_2bit_op_ex_s,
         funct3_i      => funct3_ex_s,
         funct7_i      => funct7_ex_s,
         alu_op_o      => alu_op_o);

   --***************Izlazi************************
   data_mem_we_o <= data_mem_we_mem_s;
   mem_to_reg_o  <= mem_to_reg_wb_s;
   alu_src_a_o   <= alu_src_a_ex_s;
   alu_src_b_o   <= alu_src_b_ex_s;
   rd_we_o       <= rd_we_wb_s;
   jump_o        <= jump_ex_s(1) xor jump_ex_s(0);
   load_o        <= load_ex_s;


end architecture;

