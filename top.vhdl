--
-- Copyright 2016 Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
--
-- @author Matthew Hagerty
-- @author Erik Piehl
--
-- @date Dec 8, 2016
--
-- Top module for testing the 9900 CPU Core
-- on a MiniSpartan6-plus


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity top is
   port (
      clk_50m0_net   : in  std_logic;
      LEDS           : out std_logic_vector(0 to 4)
   );
end top;

architecture rtl of top is

   signal clk_100m0_s            : std_logic;
   signal reset_n_s              : std_logic;

   signal load_n_s       : std_logic;                    -- active low, load WP from >FFFC and PC from >FFFE
   signal hold_n_s       : std_logic;                    -- active low, external hold request for bus control
   signal holda_s        : std_logic;                    -- active high, acknowledge the hold_n request
   signal ready_s        : std_logic;                    -- active high, memory will be ready for read/write during the next cycle
   signal wait_s         : std_logic;                    -- active high, indicates the 9900 is in a wait-state due to ready being low
   signal iaq_s          : std_logic;                    -- active high, indicates the 9900 is fetching an instruction
   -- Memory interface
   signal bsel_n_s       : std_logic_vector(0 to 1);     -- 11=read, 01=MSB write, 10=LSB write, 00=WORD write
   signal addr_s         : std_logic_vector(0 to 15);    -- A0 = MSbit
   signal din_s          : std_logic_vector(0 to 15);    -- D0 = MSbit
   signal dout_s         : std_logic_vector(0 to 15);    -- D0 = MSbit
   signal we_n_s         : std_logic;                    -- active low
   signal dbin_s         : std_logic;                    -- active high when reading the data bus
   signal memen_n_s      : std_logic;                    -- active low, indicates addr contains a valid memory address
   -- CRU interface
   signal cruclk_s       : std_logic;                    -- active high, cruout is valid or A0-A2 should be decoded
   signal cruout_s       : std_logic;                    -- CRU data out, valid when cruclk goes high
   signal cruin_s        : std_logic;                    -- CRU data in. A3-A14 specify the external bit to be sampled
   -- Interrupt interface
   signal intreq_n_s     : std_logic;                    -- active low, loads interrupt code from ic0-ic3
   signal ic_s           : std_logic_vector(0 to 3);     -- IC0 = MSbit, LLLH=highest priority, HHHH=lowest priority

begin

   reset_n_s   <= '1';
   ready_s     <= '1';
   -- Fake outputs to satisfy synthesis.
   LEDS <= we_n_s & dbin_s & memen_n_s & wait_s & iaq_s;

   
   -- DCM clock.
   inst_dcm : entity work.dcm
   generic map (
      BASE_FREQ_G => 50.0,             -- In MHz
      CLK_MUL_G   => 2,                -- Multiply 1 .. 32
      CLK_DIV_G   => 1                 -- Divide   1 .. 32
   )
   port map (
      clk_in      => clk_50m0_net,
      clk_out     => clk_100m0_s
   );


   -- 9900 CPU
   inst_core9900 : entity work.core9900
   port map (
      clk_i          => clk_100m0_s,
      reset_n_i      => reset_n_s,     -- active low, load WP from >0000 and PC from >0002
      load_n_i       => load_n_s,      -- active low, load WP from >FFFC and PC from >FFFE
      hold_n_i       => hold_n_s,      -- active low, external hold request for bus control
      holda_o        => holda_s,       -- active high, acknowledge the hold_n request
      ready_i        => ready_s,       -- active high, memory will be ready for read/write during the next cycle
      wait_o         => wait_s,        -- active high, indicates the 9900 is in a wait-state due to ready being low
      iaq_o          => iaq_s,         -- active high, indicates the 9900 is fetching an instruction
   -- Memory interface
      bsel_n_o       => bsel_n_s,      -- 11=read, 01=MSB write, 10=LSB write, 00=WORD write
      addr_o         => addr_s,        -- A0 = MSbit
      din_i          => din_s,         -- D0 = MSbit
      dout_o         => dout_s,        -- D0 = MSbit
      we_n_o         => we_n_s,        -- active low
      dbin_o         => dbin_s,        -- active high when reading the data bus
      memen_n_o      => memen_n_s,     -- active low, indicates addr contains a valid memory address
   -- CRU interface
      cruclk_o       => cruclk_s,      -- active high, cruout is valid or A0-A2 should be decoded
      cruout_o       => cruout_s,      -- CRU data out, valid when cruclk goes high
      cruin_i        => cruin_s,       -- CRU data in. A3-A14 specify the external bit to be sampled
   -- Interrupt interface
      intreq_n_i     => intreq_n_s,    -- active low, loads interrupt code from ic0-ic3
      ic_i           => ic_s           -- IC0 = MSbit, LLLH=highest priority, HHHH=lowest priority
   );


end rtl;
