--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   01:38:43 02/05/2017
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
    GENERIC (
      MEMCYCLE_COUNT : natural range 1 to 100 := 33      -- One memory cycle in 10ns counts
         );
    PORT(
         clk_i : IN  std_logic;
         reset_n_i : IN  std_logic;
         ready_i : IN  std_logic;
         wait_o : OUT  std_logic;
         iaq_o : OUT  std_logic;
         we_n_o : OUT  std_logic;
         dbin_o : OUT  std_logic;
         memen_n_o : OUT  std_logic;
         ctl_wp_sel_s_o : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal clk_i : std_logic := '0';
   signal reset_n_i : std_logic := '0';
   signal ready_i : std_logic := '0';

 	--Outputs
   signal wait_o : std_logic;
   signal iaq_o : std_logic;
   signal we_n_o : std_logic;
   signal dbin_o : std_logic;
   signal memen_n_o : std_logic;
   signal ctl_wp_sel_s_o : std_logic;

   -- Clock period definitions
   constant clk_i_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: decode 
         GENERIC MAP ( MEMCYCLE_COUNT => 2 )
         PORT MAP (
          clk_i => clk_i,
          reset_n_i => reset_n_i,
          ready_i => ready_i,
          wait_o => wait_o,
          iaq_o => iaq_o,
          we_n_o => we_n_o,
          dbin_o => dbin_o,
          memen_n_o => memen_n_o,
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
      wait for 10 ns;
      reset_n_i <= '1';
      ready_i <= '1';
      
      wait for 60 ns;

      wait;
   end process;

END;
