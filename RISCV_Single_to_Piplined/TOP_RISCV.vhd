library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity TOP_RISCV is
   generic (DATA_WIDTH : positive := 32);
   port(
      -- ********* Globalna sinhronizacija ******************
      clk                 : in  std_logic;
      reset               : in  std_logic;
      -- ********* Interfejs ka Memoriji za instrukcije *****
      instr_mem_address_o : out std_logic_vector(31 downto 0);
      instr_mem_read_i    : in  std_logic_vector(31 downto 0);
      -- ********* Interfejs ka Memoriji za podatke *********
      data_mem_we_o       : out std_logic_vector(3 downto 0);
      data_mem_address_o  : out std_logic_vector(31 downto 0);
      data_mem_write_o    : out std_logic_vector(31 downto 0);
      data_mem_read_i     : in  std_logic_vector(31 downto 0));
end entity;

architecture structural of TOP_RISCV is
   signal instruction_s      : std_logic_vector(31 downto 0);
   signal mem_to_reg_s       : std_logic;
   signal alu_op_s           : std_logic_vector(4 downto 0);
   signal alu_src_b_s        : std_logic;
   signal alu_src_a_s        : std_logic_vector(1 downto 0);
   signal rd_we_s            : std_logic;
   signal branch_condition_s : std_logic;
   signal jump_s             : std_logic;
   signal load_s             : std_logic_vector(2 downto 0);
   signal pc_next_sel_s      : std_logic_vector(1 downto 0);
begin

   data_path_1 : entity work.data_path
      generic map (
         DATA_WIDTH => DATA_WIDTH)
      port map (
         clk                 => clk,
         reset               => reset,
         instr_mem_address_o => instr_mem_address_o,
         instr_mem_read_i    => instr_mem_read_i,
         instruction_o       => instruction_s,
         data_mem_address_o  => data_mem_address_o,
         data_mem_write_o    => data_mem_write_o,
         data_mem_read_i     => data_mem_read_i,
         mem_to_reg_i        => mem_to_reg_s,
         alu_op_i            => alu_op_s,
         pc_next_sel_i       => pc_next_sel_s,
         alu_src_b_i         => alu_src_b_s,
         alu_src_a_i         => alu_src_a_s, --AUIPC
         rd_we_i             => rd_we_s,
         jump_i              => jump_s, --JAL, JALR
         load_i              => load_s, --LOAD
         branch_condition_o  => branch_condition_s
         );

   control_path_1 : entity work.control_path
      port map (
         clk                => clk,
         reset              => reset,
         instruction_i      => instruction_s,
         mem_to_reg_o       => mem_to_reg_s,
         alu_op_o           => alu_op_s,
         pc_next_sel_o      => pc_next_sel_s,
         alu_src_b_o        => alu_src_b_s,
         alu_src_a_o        => alu_src_a_s, --AUIPC
         rd_we_o            => rd_we_s,
         jump_o             => jump_s, --JAL, JALR
         load_o             => load_s, --LOAD
         branch_condition_i => branch_condition_s,
         data_mem_we_o      => data_mem_we_o
         );
   --************************************


end architecture;


