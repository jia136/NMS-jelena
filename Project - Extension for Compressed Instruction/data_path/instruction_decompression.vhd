----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/30/2023 02:16:35 PM
-- Design Name: 
-- Module Name: instruction_decompression - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity instruction_decompression is
    generic (WIDTH: natural := 32);
    Port (inst_i     : in std_logic_vector (WIDTH - 1 downto 0);   --instruction_i
          compressed : out std_logic;                              --if 0 instruction is 32b, else instruction is 16b
          dec_inst_o : out std_logic_vector (WIDTH - 1 downto 0)); --decompressed_instruction_o
end instruction_decompression;

architecture Behavioral of instruction_decompression is
    signal opcode                    : std_logic_vector(1 downto 0);
    signal rs1_rd                    : std_logic_vector(4 downto 0);
    signal rs2                       : std_logic_vector(4 downto 0);
    signal funct3                    : std_logic_vector(2 downto 0);
    signal funct1                    : std_logic;
begin
    opcode  <= inst_i(1 downto 0);
    rs1_rd  <= inst_i(11 downto 7);
    rs2     <= inst_i(6 downto 2);
    funct3  <= inst_i(15 downto 13);
    funct1  <= inst_i(12);
    
    process (opcode, funct3, funct1, rs1_rd, rs2, inst_i) is
    begin
        case opcode is
            when "00" =>
                compressed <= '1';
                if (funct3 = "000") then       
                    if (funct1&rs1_rd&rs2(4 downto 3) = x"00") then    --Illegal instruction                    
                        dec_inst_o <= (others => '0');               
                    else                       --c.addi4spn
                        dec_inst_o <= "00" & inst_i(10 downto 7) & inst_i(12 downto 11) & inst_i(5) & inst_i(6) & "00" & "00010" & "000" & "01" & inst_i(4 downto 2) & "0010011";   
                    end if;
                    
                elsif (funct3 = "001") then    --c.fld is an RV32DC-only instruction, not supported
                    --dec_inst_o <= (31 downto 28 => '0') & inst_i(6 downto 5) & inst_i(12 downto 10) & "000" & "01" & inst_i(9 downto 7) & "011" & "01" & inst_i(4 downto 2) & "0000111"; 
                    dec_inst_o <= (31 downto 7 => '0') & "0010011"; --c.nop
                elsif (funct3 = "010") then    --c.lw
                    dec_inst_o <= (31 downto 27 => '0') & inst_i(5) & inst_i(12 downto 10) & inst_i(6) & "00" & "01" & inst_i(9 downto 7) & "010" & "01" & inst_i(4 downto 2) & "0000011";
                elsif (funct3 = "011") then    --c.flw is an RV32FC-only instruction, not supported
                    --dec_inst_o <= (31 downto 27 => '0') & inst_i(5) & inst_i(12 downto 10) & inst_i(6) & "00" & "01" & inst_i(9 downto 7) & "010" & "01" & inst_i(4 downto 2) & "0000111";
                    dec_inst_o <= (31 downto 7 => '0') & "0010011"; --c.nop
                elsif (funct3 = "101") then    --c.fsd is an RV32DC-only instruction, not supported
                    --dec_inst_o <= (31 downto 28 => '0') & inst_i(6 downto 5) & inst_i(12) & "01" & inst_i(4 downto 2) & "01" & inst_i(9 downto 7) & "011" & inst_i(11 downto 10) & "000" & "0100111";
                    dec_inst_o <= (31 downto 7 => '0') & "0010011"; --c.nop
                elsif (funct3 = "110") then    --c.sw
                    dec_inst_o <= (31 downto 27 => '0') & inst_i(5) & inst_i(12) & "01" & inst_i(4 downto 2) & "01" & inst_i(9 downto 7) & "010" & inst_i(11 downto 10) & inst_i(6) & "00" & "0100011";
                else                           --c.fsw is an RV32FC-only instruction, not supported
                    --dec_inst_o <= (31 downto 27 => '0') & inst_i(5) & inst_i(12) & "01" & inst_i(4 downto 2) & "01" & inst_i(9 downto 7) & "010" & inst_i(11 downto 10) & inst_i(6) & "00" & "0100111";
                    dec_inst_o <= (31 downto 7 => '0') & "0010011"; --c.nop
                end if;
            when "01" =>
                compressed <= '1';
                if (funct3 = "000") then
                    if (funct1&rs2 = "000000") then     --c.nop
                        dec_inst_o <= (31 downto 7 => '0') & "0010011";
                    else                                --c.addi
                        dec_inst_o <= (31 downto 26 => '0') & inst_i(12) & inst_i(6 downto 2) & inst_i(11 downto 7) & "000" & inst_i(11 downto 7) & "0010011";
                    end if;
                elsif (funct3 = "001") then    --c.jal
                    dec_inst_o <= '0' & inst_i(8) & inst_i(10 downto 9) & inst_i(6) & inst_i(7) & inst_i(2) & inst_i(11) & inst_i(5 downto 3) & inst_i(12) & (19 downto 8 => '0') & '1' & "1101111";
                elsif (funct3 = "010") then    --c.li
                    dec_inst_o <= (31 downto 26 => '0') & inst_i(12) & inst_i(6 downto 2) & (19 downto 12 => '0') & inst_i(11 downto 7) & "0010011";
                elsif (funct3 = "011") then
                    if (rs1_rd = "00010") then --c.addi16sp
                        dec_inst_o <= (31 downto 30 => '0') & inst_i(12) & inst_i(4 downto 3) & inst_i(5) & inst_i(2) & inst_i(6)  & (23 downto 20 => '0') & "00010" & "000" & "00010" & "0010011";
                    else                       --c.lui
                        dec_inst_o <= (31 downto 18 => '0') & inst_i(12) & inst_i(6 downto 2) & inst_i(11 downto 7) & "0110111";
                    end if;
                elsif (funct3 = "100") then
                    if (rs1_rd(4 downto 3) = "00") then     --c.srli
                        dec_inst_o <= (31 downto 25 => '0') & inst_i(6 downto 2) & "01" & inst_i(9 downto 7) & "101" & "01" & inst_i(9 downto 7) & "0010011";
                    elsif (rs1_rd(4 downto 3) = "01") then  --c.srai
                        dec_inst_o <= "01" & (29 downto 25 => '0') & inst_i(6 downto 2) & "01" & inst_i(9 downto 7) & "101" & "01" & inst_i(9 downto 7) & "0010011";
                    elsif (rs1_rd(4 downto 3) = "10") then  --c.andi
                        dec_inst_o <= (31 downto 26 => '0') & inst_i(12) & inst_i(6 downto 2) & "01" & inst_i(9 downto 7) & "111" & "01" & inst_i(9 downto 7) & "0010011";
                    else
                        if (rs2(4 downto 3) = "00") then    --c.sub
                            dec_inst_o <= "01" & (29 downto 25 => '0') & "01" & inst_i(4 downto 2) & "01" & inst_i(9 downto 7) & "000" & "01" & inst_i(9 downto 7) & "0110011";  
                        elsif (rs2(4 downto 3) = "01") then --c.xor
                            dec_inst_o <= (31 downto 25 => '0') & "01" & inst_i(4 downto 2) & "01" & inst_i(9 downto 7) & "100" & "01" & inst_i(9 downto 7) & "0110011";
                        elsif (rs2(4 downto 3) = "10") then --c.or
                            dec_inst_o <= (31 downto 25 => '0') & "01" & inst_i(4 downto 2) & "01" & inst_i(9 downto 7) & "110" & "01" & inst_i(9 downto 7) & "0110011";
                        else                                --c.and
                            dec_inst_o <= (31 downto 25 => '0') & "01" & inst_i(4 downto 2) & "01" & inst_i(9 downto 7) & "111" & "01" & inst_i(9 downto 7) & "0110011";                        
                        end if;
                    end if;
                elsif (funct3 = "101") then                 --c.j
                    dec_inst_o <= '0' & inst_i(8) & inst_i(10 downto 9) & inst_i(6) & inst_i(7) & inst_i(2) & inst_i(11) & inst_i(5 downto 3) & inst_i(12) & (19 downto 7 => '0') & "1101111";
                elsif (funct3 = "110") then                 --c.beqz
                    dec_inst_o <= (31 downto 29 => '0') & inst_i(12) & inst_i(6 downto 5) & inst_i(2) & (24 downto 20 => '0') & "01" & inst_i(9 downto 7) & "000" & inst_i(11 downto 10) & inst_i(4 downto 3) & '0' & "1100011";
                else                                        --c.bnez
                    dec_inst_o <= (31 downto 29 => '0') & inst_i(12) & inst_i(6 downto 5) & inst_i(2) & (24 downto 20 => '0') & "01" & inst_i(9 downto 7) & "001" & inst_i(11 downto 10) & inst_i(4 downto 3) & '0' & "1100011";
                end if;
            when "10" =>
                compressed <= '1';
                if (funct3 = "000") then                    --c.slli
                    dec_inst_o <= (31 downto 25 => '0') & inst_i(6 downto 2) & inst_i(11 downto 7) & "001" & inst_i(11 downto 7) & "0010011";
                elsif (funct3 = "001") then                 --c.fldsp is an RV32DC-only instruction, not supported
                    --dec_inst_o <= (31 downto 29 => '0') & inst_i(4 downto 2) & inst_i(12) & inst_i(6 downto 5) & (22 downto 17 => '0') & "10" & "011" & inst_i(11 downto 7) & "0000111";
                    dec_inst_o <= (31 downto 7 => '0') & "0010011"; --c.nop
                elsif (funct3 = "010") then                 --c.lwsp
                    dec_inst_o <= (31 downto 28 => '0') & inst_i(3 downto 2) & inst_i(12) & inst_i(6 downto 4) & (21 downto 17 => '0') & "10" & "010" & inst_i(11 downto 7) & "0000011";
                elsif (funct3 = "011") then                 --c.flwsp is an RV32FC-only instruction, not supported
                    --dec_inst_o <= (31 downto 28 => '0') & inst_i(3 downto 2) & inst_i(12) & inst_i(6 downto 4) & (21 downto 17 => '0') & "01" & "010" & inst_i(11 downto 7) & "0000111";
                    dec_inst_o <= (31 downto 7 => '0') & "0010011"; --c.nop
                elsif (funct3 = "100") then
                    if (funct1 = '0') then
                        if (rs2 = "00000") then             --c.jr
                            dec_inst_o <= (31 downto 20 => '0') & inst_i(11 downto 7) & "000" & (11 downto 7 => '0') & "1100111";
                        else                                --c.mv
                            dec_inst_o <= (31 downto 25 => '0') & inst_i(6 downto 2) & (19 downto 12 => '0') & inst_i(11 downto 7) & "0110011";
                        end if;    
                    else
                        if (rs2 = "00000") then
                            if (rs1_rd = "00000") then      --c.ebreak
                                dec_inst_o <= (31 downto 21 => '0') & '1' & (19 downto 7 => '0') & "1110011";
                            else                            --c.jalr
                                dec_inst_o <= (31 downto 20 => '0') & inst_i(11 downto 7) & "000" & (11 downto 8 => '0') & '1' & "1100111";
                            end if;
                        else                                --c.add
                            dec_inst_o <= (31 downto 25 => '0') & "01" & inst_i(4 downto 2) & "01" & inst_i(9 downto 7) & "000" & "01" & inst_i(9 downto 7) & "0110011";
                        end if;
                    end if;
                elsif (funct3 = "101") then                 --c.fsdsp is an RV32DC-only instruction, not supported
                    --dec_inst_o <= (31 downto 29 => '0') & inst_i(9 downto 7) & inst_i(12) & inst_i(6 downto 2) & "00010" & "011" & inst_i(11 downto 10) & "000" & "0100111";
                    dec_inst_o <= (31 downto 7 => '0') & "0010011"; --c.nop
                elsif (funct3 = "110") then                 --c.swsp
                    dec_inst_o <= (31 downto 28 => '0') & inst_i(8 downto 7) & inst_i(12) & inst_i(6 downto 2) & "00010" & "010" & inst_i(11 downto 9) & "00" & "0100011";
                else                                        --c.fswsp is an RV32FC-only instruction, not supported
                    --dec_inst_o <= (31 downto 28 => '0') & inst_i(8 downto 7) & inst_i(12) & inst_i(6 downto 2) & "00010" & "010" & inst_i(11 downto 9) & "00" & "0100111";
                    dec_inst_o <= (31 downto 7 => '0') & "0010011"; --c.nop
                end if;
            when others =>
                compressed <= '0';
                dec_inst_o <= inst_i;                       --32b instruction
        end case;
    end process;

end Behavioral;
