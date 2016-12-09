--
-- Copyright 2016 Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
--
-- @author Matthew Hagerty
-- @author Erik Piehl
--
-- @date Dec 8, 2016
--
-- TMS9900 CPU Core


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;


entity core9900 is
   port (
      clk_i          : in  std_logic;     -- clock
      clk_en_i       : in  std_logic;     -- clock enable
      rst_n_i        : in  std_logic;     -- reset and load PC, active low
   -- Address and data bus
      addr_o         : out std_logic_vector(0 to 15);
      data_o         : out std_logic_vector(0 to 15);
      data_i         : in  std_logic_vector(0 to 15);
      rw_n_o         : out std_logic;     -- read !write

   );
end f18a_gpu;

architecture rtl of f18a_gpu is

   -- Signals

begin

   -- Unsiged 32 / 16 Divider
   inst_divide : entity work.div32x16
   port map (
      clk_i          => clk_i,
      reset_i        => div_reset,     -- active high, forces divider idle
      start_i        => div_start,     -- '1' to load and trigger the divide
      ready_o        => open,          -- '1' when ready, '0' while dividing
      done_o         => div_done,      -- single done tick
      dividend_msb_i => dst_oper,      -- number being divided (dividend) 0 to 4,294,967,295
      dividend_lsb_i => ws_dout,
      divisor_i      => src_oper,      -- divisor 0 to 65,535
      q_o            => div_quo,
      r_o            => div_rmd
   );


end rtl;

