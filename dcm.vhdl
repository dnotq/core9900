--
-- Copyright 2016 Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
--
-- @author Matthew Hagerty
-- @author Erik Piehl
--
-- @date Feb 4, 2017
--

--
-- Xilinx specific DCM.
--
-- Notes:
-- An IBUFG drives a global clock net from an external pin.
-- A BUFG drives a global clock net from an internal signal.


library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;
library UNISIM;
use UNISIM.Vcomponents.ALL;

entity dcm is
   generic (
      BASE_FREQ_G : real := 12.0;                  -- Input frequency in MHz
      CLK_MUL_G   : natural range 1 to 32 := 25;   -- Frequency multiplier
      CLK_DIV_G   : natural range 1 to 32 := 3     -- Frequency divider
   );
   port (
      clk_in      : in std_logic;
      clk_out     : out std_logic
   );
end dcm;

architecture rtl of dcm is

   signal clkfx_s          : std_logic;   -- Positive phase of dcm clock.
   signal clkfx180_s       : std_logic;   -- Negative phase of dcm clock.
   signal clkfx_buf_s      : std_logic;
   signal clkfx180_buf_s   : std_logic;

begin

   -- DCM set up for using the CLKFX and CLKFX180 output ONLY.  If other
   -- outputs are required, the FEEDBACK must be set up and the Xilinx tools
   -- should probably be used to generate the HDL.
   inst_dcm : DCM_SP
   generic map (
      CLKDV_DIVIDE            => 2.0,
      CLKFX_DIVIDE            => CLK_DIV_G,  -- Any integer from 1 to 32
      CLKFX_MULTIPLY          => CLK_MUL_G,  -- Any integer from 1 to 32
      CLKIN_DIVIDE_BY_2       => FALSE,      -- TRUE/FALSE to enable CLKIN divide by two feature
      CLKIN_PERIOD            => 1000.0 / BASE_FREQ_G,   --  Specify period of input clock in ns
      CLKOUT_PHASE_SHIFT      => "NONE",     -- Specify phase shift of NONE, FIXED, or VARIABLE
      CLK_FEEDBACK            => "NONE",     -- Specify clock feedback of NONE, 1X, or 2X
      DESKEW_ADJUST           => "SYSTEM_SYNCHRONOUS",
      DFS_FREQUENCY_MODE      => "LOW",
      DLL_FREQUENCY_MODE      => "LOW",
      DUTY_CYCLE_CORRECTION   => TRUE,
      PHASE_SHIFT             => 0,
      STARTUP_WAIT            => FALSE)
   port map (
      CLKIN    => clk_in,
      RST      => '0',        -- Never reset
      CLKFX    => clkfx_s,
      CLKFX180 => clkfx180_s
   );

   clkfx_bufg_inst : BUFG
   port map (
      I => clkfx_s,
      O => clkfx_buf_s
   );

   clkfx180_bufg_inst : BUFG
   port map (
      I => clkfx180_s,
      O => clkfx180_buf_s
   );

   -- Output
   clk_out <= clkfx_buf_s;

end rtl;
