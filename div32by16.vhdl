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


entity div32x16 is
   port (
      clk_i          : in  std_logic;
      reset_i        : in  std_logic;                    -- active high, forces divider idle
      start_i        : in  std_logic;                    -- '1' to load and trigger the divide
      ready_o        : out std_logic;                    -- '1' when ready, '0' while dividing
      done_o         : out std_logic;                    -- single done tick
      dividend_msb_i : in  std_logic_vector(0 to 15);    -- MS Word of dividend 0 to FFFE
      dividend_lsb_i : in  std_logic_vector(0 to 15);    -- LS Word of dividend 0 to FFFF
      divisor_i      : in  std_logic_vector(0 to 15);    -- divisor 0 to FFFF
      q_o            : out std_logic_vector(0 to 15);
      r_o            : out std_logic_vector(0 to 15)
   );
end div32x16;

architecture rtl of div32x16 is

   type div_state_t is (ST_IDLE, ST_OP, ST_DONE);
   signal state_r, state_x : div_state_t;

   signal d_r, d_x      : std_logic_vector(0 to 15);  -- registered divisor
   signal rl_r, rl_x    : std_logic_vector(0 to 15);  -- dividend lo 16-bits
   signal rh_r, rh_x    : std_logic_vector(0 to 15);  -- dividend hi 16-bits
   signal msb_r, msb_x  : std_logic;                  -- shifted MS-bit of dividend for 17-bit subtraction
   signal sub17_s       : std_logic_vector(0 to 16);  -- 17-bit unsigned subtraction result
   signal part_s        : std_logic_vector(0 to 15);  -- partial_dividend - divisor
   signal qbit_s        : std_logic;                  -- quotient bit
   signal cnt_r, cnt_x  : integer range 0 to 15;      -- 0 to 15 counter
   signal rdy_r, rdy_x  : std_logic;
   signal dne_r, dne_x  : std_logic;

begin

   -- The circuit implements a long division style divider.  The divisor is subtracted from
   -- the dividend until there are no more dividend bits.  After each subtract and compare,
   -- the dividend registers are shifted-left and the new quotient bit is the shifted-in bit
   -- to the dividend LS-word register (rl).  The MS-bit of rl becomes the shifted-in bit to
   -- the rh register.
   --
   -- When the division is done, rh contains the remainder, and rl contains the quotient.
   --
   -- +--------------------+                   +----------+
   -- |  +------------+    |                   |          |                                                       
   -- |  |            V    V                   V          |                                                       
   -- |  |         +----------+ +---------+  +----+       |     
   -- |  |         > msb & rh | > '0' & d |  > rl |       |     
   -- |  |         +----------+ +---------+  +----+       |     
   -- |  |               |          |          |          |     
   -- |  |          +----+          |          |          |     
   -- |  |          |    |17        |17        |          |     
   -- |  |          |    V          V          |          |     
   -- |  |          | -------------------      |          |     
   -- |  |          | \ 17-bit subtract /      |          |     
   -- |  |          |  -----------------       |          |     
   -- |  |          |   |      |               |          |     
   -- |  |          |   +------|---|>o---+-----|--------+ |     
   -- |  |          |   bit-0  |         |     |   qbit | |     
   -- |  |          |rh        |1..16    |     |        | |     
   -- |  |          V          V         |     |        | |     
   -- |  |       ------------------      |     |        | |     
   -- |  |       \  0   mux    1  /<-----+     |        | |     
   -- |  |        ----------------             |        | |     
   -- |  |               |                     |        | |     
   -- |  |               V                     V        | |     
   -- | +-+  +---------------+  +-+  +---------------+  | |     
   -- | |0|<-|   < 1..15 <   |<-|0|<-|   < 1..15 <   |<-+ |     
   -- | +-+  +---------------+  +-+  +---------------+    |     
   -- |bit-0         |         bit-0         |            |     
   -- +--------------+                       +------------+
   --
   -- The quotient and remainder are 16-bits, thus the 16-bit divisor must be greater than
   -- the 16-bit MS-word of the dividend.  Otherwise the resulting quotient would not fit
   -- in a 16-bit register.  This condition must be checked outside of this circuit and would
   -- be considered an overflow.
   --
   -- For example, with a 8x4 divider, 128 / 8 would yield a quotient of 16 remainder 0.  But
   -- the resulting quotient (16) requires 5-bits, and thus is an overflow:
   --
   --        10000 R 000 (quotient overflows, requires 5-bits)
   -- 1000 | 1000 0000   (dividend is <= MS-word)
   --
   -- But, 127 / 8 yields 15 remainder 7, and is a valid division:
   --
   --        01111 R 111
   -- 1000 | 0111 1111   (dividend > MS-word)
   --
   -- Another example, 128 / 9 yields 14 remainder 2:
   --
   --        01110 R 010
   -- 1001 | 1000 0000   (dividend > MS-word)
   --
   -- Because the divisor must be greater than the MS-word of the dividend, the dividend does
   -- not need to be initialize as double-width with left-padded with zeros.  Also, only 16
   -- clock-cycles are required since the divisor is only 16-bits.

   -- Registered outputs.
   q_o      <= rl_r;
   r_o      <= rh_r;
   ready_o  <= rdy_r;
   done_o   <= dne_r;

   -- Subtract to derive each quotient bit.  A comparison of (partial_dividend >= divisor) is
   -- performed implicitly during the subtraction and the result can be obtained via the MS-bit
   -- of the subtraction result.
   sub17_s  <= (msb_r & rh_r) - ('0' & d_r);
   qbit_s   <= not sub17_s(0);
   part_s   <=
      rh_r when qbit_s = '0' else   -- partial dividend is less than the divisor.
      sub17_s(1 to 16);             -- partial dividend is greater than the divisor.


   -- Division FSM
   process (start_i, dividend_lsb_i, dividend_msb_i,
            state_r, d_r, rl_r, rh_r, msb_r, cnt_r, part_s, qbit_s)
   begin

      -- Default to current values unless changed.
      state_x  <= state_r;
      d_x      <= d_r;
      rl_x     <= rl_r;
      rh_x     <= rh_r;
      msb_x    <= '0';

      rdy_x    <= '1';        -- ready until triggered
      dne_x    <= '0';        -- single-tick done signal
      cnt_x    <= 15;

      case state_r is

      when ST_IDLE =>

         -- Only change rl and rh when triggered so the registers
         -- retain their values after the division operation.
         if start_i = '1' then
            state_x  <= ST_OP;
            d_x      <= divisor_i;
            rl_x     <= dividend_lsb_i;
            rh_x     <= dividend_msb_i;
            rdy_x    <= '0';
         end if;

      when ST_OP =>

         -- rl shifts left and stores the quotient bits.
         rl_x <= rl_r(1 to 15) & qbit_s;

         -- rh shifts the partial dividend left and append the next dividend bit.
         rh_x <= part_s(1 to 15) & rl_r(0);

         -- msb retains the shifted-out bit of rh for the 17-bit subtract.
         msb_x <= part_s(0);

         cnt_x <= cnt_r - 1;
         rdy_x <= '0';

         if cnt_r = 0 then
            state_x <= ST_DONE;
         end if;

      when ST_DONE =>

         -- Final iteration stores the quotient and remainder.
         rl_x     <= rl_r(1 to 15) & qbit_s;
         rh_x     <= part_s;
         dne_x    <= '1';
         state_x  <= ST_IDLE;

      end case;
   end process;

   -- Register Transfer.
   process (clk) begin if rising_edge(clk) then
      if reset_i = '1' then
         state_r <= ST_IDLE;
      else

         state_r  <= state_x;
         d_r      <= d_x;
         rl_r     <= rl_x;
         rh_r     <= rh_x;
         msb_r    <= msb_x;
         rdy_r    <= rdy_x; 
         dne_r    <= rdy_x; 
         cnt_r    <= rdy_x;

      end if;
   end if; end process;

end rtl;
