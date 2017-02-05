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
-- Notes:
--
-- If used in a real system with external signals, it is up to the implementor to
-- synchronize inputs to the clock as necessary.
--
-- clk_i must be 100MHz.
--
-- ready_i is not available if MEMCYCLE_COUNT is 0 (10ns memory cycle).  Otherwise it must
-- be active 10ns before the end of a memory cycle.


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;


entity core9900 is
   generic (
      MEMCYCLE_COUNT : natural range 1 to 100 := 33      -- One memory cycle in 10ns counts
   );
   port (
      clk_i          : in  std_logic;
      reset_n_i      : in  std_logic;                    -- active low, load WP from >0000 and PC from >0002
      load_n_i       : in  std_logic;                    -- active low, load WP from >FFFC and PC from >FFFE
      hold_n_i       : in  std_logic;                    -- active low, external hold request for bus control
      holda_o        : out std_logic;                    -- active high, acknowledge the hold_n request
      ready_i        : in  std_logic;                    -- active high, memory will be ready for read/write during the next cycle
      wait_o         : out std_logic;                    -- active high, indicates the 9900 is in a wait-state due to ready being low
      iaq_o          : out std_logic;                    -- active high, indicates the 9900 is fetching an instruction
   -- Memory interface
      bsel_n_o       : out std_logic_vector(0 to 1);     -- 11=read, 01=MSB write, 10=LSB write, 00=WORD write
      addr_o         : out std_logic_vector(0 to 15);    -- A0 = MSbit
      din_i          : in  std_logic_vector(0 to 15);    -- D0 = MSbit
      dout_o         : out std_logic_vector(0 to 15);    -- D0 = MSbit
      we_n_o         : out std_logic;                    -- active low
      dbin_o         : out std_logic;                    -- active high when reading the data bus
      memen_n_o      : out std_logic;                    -- active low, indicates addr contains a valid memory address
   -- CRU interface
      cruclk_o       : out std_logic;                    -- active high, cruout is valid or A0-A2 should be decoded
      cruout_o       : out std_logic;                    -- CRU data out, valid when cruclk goes high
      cruin_i        : in  std_logic;                    -- CRU data in. A3-A14 specify the external bit to be sampled
   -- Interrupt interface
      intreq_n_i     : in  std_logic;                    -- active low, loads interrupt code from ic0-ic3
      ic_i           : in  std_logic_vector(0 to 3)      -- IC0 = MSbit, LLLH=highest priority, HHHH=lowest priority
   );
end core9900;

architecture rtl of core9900 is

   -- Instruction Fields
   signal byte_s                    : std_logic;                     -- byte selector
   signal Td_s                      : std_logic_vector(0 to 1);      -- destination mode: Td
   signal Dc_s                      : std_logic_vector(0 to 3);      -- destination: D or C
   signal Ts_s                      : std_logic_vector(0 to 1);      -- source mode: Ts
   signal Sw_s                      : std_logic_vector(0 to 3);      -- source: S or W
   signal C_s                       : std_logic_vector(0 to 3);      -- count: C
   signal jmp_disp_s                : std_logic_vector(0 to 7);      -- jump displacement
   signal Rn_s                      : std_logic_vector(0 to 3);      -- selected register

   -- Control Signals
   signal ctl_wp_sel_s              : std_logic := '0';              -- workspace pointer select

   -- Data Path
   signal wp_reg_addr_s             : std_logic_vector(0 to 15);

begin

   -- Decoder and Control
   inst_decode : entity work.decode
   generic map (
      MEMCYCLE_COUNT => MEMCYCLE_COUNT
   )
   port map (
      clk_i          => clk_i,
      reset_n_i      => reset_n_i,        -- active low
      ready_i        => ready_i,          -- active high, memory will be ready for read/write during the next cycle
      wait_o         => wait_o,           -- active high, indicates the 9900 is in a wait-state due to ready being low
      iaq_o          => iaq_o,            -- active high, indicates the 9900 is fetching an instruction

      -- External memory interface
      we_n_o         => we_n_o,           -- active low
      dbin_o         => dbin_o,           -- active high when reading the data bus
      memen_n_o      => memen_n_o,        -- active low, indicates addr contains a valid memory address

      -- Internal control signals
      ctl_wp_sel_s_o => ctl_wp_sel_s
   );




   -- Data Paths

   -- Workspace Pointer control decode and next state value.
   -- WorkspacePointer : process (ctl_wp_sel_s, wp_r, din_i)
   -- begin
      -- case ctl_wp_sel_s is
      -- when WP_DIN    => wp_x <= din_i;
      -- when others    => wp_x <= wp_r;
      -- end case;
   -- end process;

   -- -- Dedicated adder for register addressing.
   -- wp_reg_addr_s <= wp_r + ("00000000000" & Rn_s & "0");

   -- Unsigned 32 / 16 Divider
   -- inst_divide : entity work.div32x16
   -- port map (
      -- clk_i          => clk_i,
      -- reset_i        => div_reset,     -- active high, forces divider idle
      -- start_i        => div_start,     -- '1' to load and trigger the divide
      -- ready_o        => open,          -- '1' when ready, '0' while dividing
      -- done_o         => div_done,      -- single done tick
      -- dividend_msb_i => dst_oper,      -- number being divided (dividend) 0 to 4,294,967,295
      -- dividend_lsb_i => ws_dout,
      -- divisor_i      => src_oper,      -- divisor 0 to 65,535
      -- q_o            => div_quo,
      -- r_o            => div_rmd
   -- );

end rtl;

