library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ctrl_decoder is
   port (
      --************ Opcode polje instrukcije************
      opcode_i      : in  std_logic_vector(6 downto 0);
      funct3_i      : in  std_logic_vector(2 downto 0);
      --************ Kontrolni signali*******************
      branch_o      : out std_logic;
      mem_to_reg_o  : out std_logic;
      data_mem_we_o : out std_logic_vector(3 downto 0);
      alu_src_b_o   : out std_logic;
      alu_src_a_o   : out std_logic_vector(1 downto 0);
      rd_we_o       : out std_logic;
      alu_2bit_op_o : out std_logic_vector(1 downto 0);
      jump_o        : out std_logic_vector(1 downto 0);
      load_o        : out std_logic_vector(2 downto 0)
      );
end entity;

architecture behavioral of ctrl_decoder is
begin

   control_dec : process(opcode_i, funct3_i)is
   begin
      --***Podrazumevane vrednost***
      branch_o      <= '0';
      mem_to_reg_o  <= '0';
      data_mem_we_o <= "0000";
      alu_src_b_o   <= '0';
      alu_src_a_o   <= "00";
      rd_we_o       <= '0';
      alu_2bit_op_o <= "00";
      jump_o        <= "00";
      load_o        <= "000";
      --****************************      
      case opcode_i is
         when "0000011" =>               --LOAD, 5v ~ funct3
            alu_2bit_op_o <= "00";
            mem_to_reg_o  <= '1';
            alu_src_b_o   <= '1';
            rd_we_o       <= '1';
            if (funct3_i(2 downto 0) = "000") then --LB
                load_o <= "001";
            elsif(funct3_i(2 downto 0) = "001") then --LH
                load_o <= "010";
            elsif(funct3_i(2 downto 0) = "010") then --LW
                load_o <= "011";
            elsif(funct3_i(2 downto 0) = "100") then --LBU
                load_o <= "100";
            elsif(funct3_i(2 downto 0) = "101") then --LBU
                load_o <= "101";
            end if;
         when "0100011" =>                --STORE, 3v ~ funct3
            alu_2bit_op_o <= "00";
            data_mem_we_o <= "1111";
            alu_src_b_o   <= '1';
            if (funct3_i(2 downto 0) = "000") then --SB
                data_mem_we_o <= "0001";
            elsif (funct3_i(2 downto 0) = "001") then --SH
                data_mem_we_o <= "0011";
            elsif (funct3_i(2 downto 0) = "010") then --SW
                data_mem_we_o <= "1111";
            end if;
         when "0110011" =>                --R type 
            alu_2bit_op_o <= "10";
            rd_we_o       <= '1';
         when "0010011" =>                --I type
            alu_2bit_op_o <= "11";
            alu_src_b_o   <= '1';
            rd_we_o       <= '1';
         when "1100011" =>                --B type BEQ
            alu_2bit_op_o <= "01";
            branch_o      <= '1';
         when "0010111" =>                --U type AUIPC
            alu_2bit_op_o <= "00";
            alu_src_b_o   <= '1';
            alu_src_a_o   <= "01";
            rd_we_o       <= '1';
         when "1101111" =>                --J type JAL
            alu_2bit_op_o <= "00";
            rd_we_o       <= '1';
            jump_o        <= "01";
            alu_src_a_o   <= "01";
         when "1100111" =>                --I type JALR
            alu_2bit_op_o <= "00";
            rd_we_o       <= '1';
            jump_o        <= "10";
            alu_src_a_o   <= "01";
         when "0110111" =>                --U type LUI
            alu_2bit_op_o <= "00";
            alu_src_b_o   <= '1';
            alu_src_a_o   <= "10";
            rd_we_o       <= '1';
         when others =>
      end case;
   end process control_dec;

end architecture;
