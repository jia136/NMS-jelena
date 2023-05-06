----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/03/2023 11:01:59 AM
-- Design Name: 
-- Module Name: compressed_decoder_tb - Behavioral
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
use std.textio.all;
use work.txt_util.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity compressed_decoder_tb is
--  Port ( );
end compressed_decoder_tb;

architecture Behavioral of compressed_decoder_tb is

   file RISCV_instructions_input: text open read_mode is "../../../../../RISCV_tb/risc_instructions.txt";
   file RISCV_instructions_verif: text open read_mode is "../../../../../RISCV_tb/risc_verif.txt";

   signal clk: std_logic := '0';
   signal reset: std_logic;
   
   signal compressed_s    : std_logic;
   signal inst_i_s        : std_logic_vector(31 downto 0);
   signal dec_inst_o_s    : std_logic_vector(31 downto 0);
   signal inst_verif_s    : std_logic_vector(31 downto 0);

begin
    
    com_decoder_comp:
    entity work.instruction_decompression(behavioral)
        port map(inst_i => inst_i_s,
                 compressed => compressed_s,
                 dec_inst_o => dec_inst_o_s);
                 
    clk_proc: process
    begin
        clk <= '1', '0' after 100 ns;
        wait for 200 ns;
    end process;
    
    stim_proc: process
        variable row: line;
        variable tmp32: std_logic_vector(31 downto 0);
        variable tmp16: std_logic_vector(15 downto 0);
    begin
        inst_i_s <= (others => '0');
        while (not endfile(RISCV_instructions_input))loop
            readline(RISCV_instructions_input, row);
            if (row'length > 16) then
                --instrukcija je 32-bitna
                tmp32 := to_std_logic_vector(string(row));
                inst_i_s <= tmp32;
            else
                --instrukcija je 16-bitna
                tmp16 := to_std_logic_vector(string(row));
                inst_i_s <= ( 31 downto 16 => '0') & tmp16;
            end if;
         wait until falling_edge(clk);
        end loop;
        wait;      
    end process stim_proc;

    check_proc: process
        variable row: line;
        variable tmp: std_logic_vector(31 downto 0);
    begin
        inst_verif_s <= (others => '0');
        while (not endfile(RISCV_instructions_verif))loop
            readline(RISCV_instructions_verif, row);
            tmp := to_std_logic_vector(string(row));
            inst_verif_s <= tmp;
            if (unsigned(inst_verif_s) /= unsigned(dec_inst_o_s)) then
                report "Instruction mismatch!" severity warning;
            end if;
            wait until falling_edge(clk);         
        end loop;
        wait;
    end process check_proc;
    
end Behavioral;
