--
-- Copyright 2016 Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
--
-- @author Matthew Hagerty
-- @author Erik Piehl
--
-- @date Dec 8, 2016
--
-- TMS9900 CPU Core
--
-- Unsigned 32-bit dividend by 16-bit divisor division circuit.
-- 16-clocks for the div op plus two clocks state change overhead.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

 
ENTITY tb_div32x16 IS
END tb_div32x16;
 
ARCHITECTURE behavior OF tb_div32x16 IS 
 
   -- Unit Under Test (UUT)
   COMPONENT div32x16
   PORT(
      clk_i          : IN  std_logic;
      reset_i        : IN  std_logic;
      start_i        : IN  std_logic;
      ready_o        : OUT  std_logic;
      done_o         : OUT  std_logic;
      dividend_msb_i : IN  std_logic_vector(0 to 15);
      dividend_lsb_i : IN  std_logic_vector(0 to 15);
      divisor_i      : IN  std_logic_vector(0 to 15);
      q_o            : OUT  std_logic_vector(0 to 15);
      r_o            : OUT  std_logic_vector(0 to 15)
      );
   END COMPONENT;
    

   --Inputs
   signal clk_i            : std_logic := '0';
   signal reset_i          : std_logic := '0';
   signal start_i          : std_logic := '0';
   signal dividend_msb_i   : std_logic_vector(0 to 15) := (others => '0');
   signal dividend_lsb_i   : std_logic_vector(0 to 15) := (others => '0');
   signal divisor_i        : std_logic_vector(0 to 15) := (others => '0');

   --Outputs
   signal ready_o          : std_logic;
   signal done_o           : std_logic;
   signal q_o              : std_logic_vector(0 to 15);
   signal r_o              : std_logic_vector(0 to 15);

   -- Clock period definitions
   constant clk_i_period : time := 10 ns;
 
BEGIN
 
   -- Instantiate the Unit Under Test (UUT)
   uut: div32x16 PORT MAP (
      clk_i          => clk_i,
      reset_i        => reset_i,
      start_i        => start_i,
      ready_o        => ready_o,
      done_o         => done_o,
      dividend_msb_i => dividend_msb_i,
      dividend_lsb_i => dividend_lsb_i,
      divisor_i      => divisor_i,
      q_o            => q_o,
      r_o            => r_o
   );

   -- Clock process definitions
   clk_i_process :process
   begin
      clk_i <= '0';
		wait for clk_i_period/2;
		clk_i <= '1';
		wait for clk_i_period/2;
   end process;
 

   stim_proc: process
   begin		
      
      reset_i <= '1';
      start_i <= '0';
      wait for 10 ns;	
      reset_i <= '0';
      
      dividend_msb_i <= x"89AB";
      dividend_lsb_i <= x"CDEF";
      divisor_i <= x"ABCD";
      start_i <= '1';
      wait for 10 ns;
      start_i <= '0';
 
      wait;
   end process;

END;
