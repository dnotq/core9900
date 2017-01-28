--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   22:51:32 01/27/2017
-- Design Name:   
-- Module Name:   C:/Users/Matthew/Code/core9900/rtl/testbench/tb_decode.vhdl
-- Project Name:  ise_minispartan6_lx25
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: decode
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY tb_decode IS
END tb_decode;
 
ARCHITECTURE behavior OF tb_decode IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT decode
    PORT(
         clk_i : IN  std_logic;
         reset_n_i : IN  std_logic;
         ir_r_i : IN  std_logic_vector(0 to 15);
         byte_s_o : OUT  std_logic;
         Td_s_o : OUT  std_logic_vector(0 to 1);
         Dc_s_o : OUT  std_logic_vector(0 to 3);
         Ts_s_o : OUT  std_logic_vector(0 to 1);
         Sw_s_o : OUT  std_logic_vector(0 to 3);
         C_s_o : OUT  std_logic_vector(0 to 3);
         jmp_disp_s_o : OUT  std_logic_vector(0 to 7);
         Rn_s_o : OUT  std_logic_vector(0 to 3);
         ctl_wp_sel_s_o : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal clk_i : std_logic := '0';
   signal reset_n_i : std_logic := '0';
   signal ir_r_i : std_logic_vector(0 to 15) := (others => '0');

 	--Outputs
   signal byte_s_o : std_logic;
   signal Td_s_o : std_logic_vector(0 to 1);
   signal Dc_s_o : std_logic_vector(0 to 3);
   signal Ts_s_o : std_logic_vector(0 to 1);
   signal Sw_s_o : std_logic_vector(0 to 3);
   signal C_s_o : std_logic_vector(0 to 3);
   signal jmp_disp_s_o : std_logic_vector(0 to 7);
   signal Rn_s_o : std_logic_vector(0 to 3);
   signal ctl_wp_sel_s_o : std_logic;

   -- Clock period definitions
   constant clk_i_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: decode PORT MAP (
          clk_i => clk_i,
          reset_n_i => reset_n_i,
          ir_r_i => ir_r_i,
          byte_s_o => byte_s_o,
          Td_s_o => Td_s_o,
          Dc_s_o => Dc_s_o,
          Ts_s_o => Ts_s_o,
          Sw_s_o => Sw_s_o,
          C_s_o => C_s_o,
          jmp_disp_s_o => jmp_disp_s_o,
          Rn_s_o => Rn_s_o,
          ctl_wp_sel_s_o => ctl_wp_sel_s_o
        );

   -- Clock process definitions
   clk_i_process :process
   begin
		clk_i <= '0';
		wait for clk_i_period/2;
		clk_i <= '1';
		wait for clk_i_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      reset_n_i <= '0';
      wait for 20 ns;	
      reset_n_i <= '1';

      -- insert stimulus here 

      wait;
   end process;

END;
