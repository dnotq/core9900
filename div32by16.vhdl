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

   type div_state_t is (st_idle, st_op, st_done);
   signal state_r : div_state_t;
   signal state_x : div_state_t;

   signal rl_r, rl_x          : std_logic_vector(0 to 15);     -- dividend lo 16-bits
   signal rh_r, rh_x          : std_logic_vector(0 to 15);     -- dividend hi 16-bits
   signal msb_r, msb_x        : std_logic;                     -- shifted msb of dividend for 17-bit subtraction
   signal diff    : unsigned(0 to 15);                   -- quotient - divisor difference
   signal sub17   : unsigned(0 to 16);                   -- 17-bit subtraction
   signal q_bit   : std_logic;                           -- quotient bit
   signal d       : unsigned(0 to 15);                   -- divisor register
   signal count_r, count_x    : integer range 0 to 15;         -- 0 to 15 counter
   signal rdy_r, rdy_x        : std_logic;
   signal dne_r, dne_x        : std_logic;

begin

   -- Registered outputs.
   -- The quotient and remainder will never be more than 16-bit.
   q_o      <= rl_r;
   r_o      <= rh_r;
   ready_o  <= rdy_r;
   done_o   <= dne_r;

   -- Compare and subtract to derive each quotient bit.
   sub17 <= (msb & rh) - ('0' & d);

   process (sub17, rh)
   begin
      -- If the partial result is greater than or equal to
      -- the divisor, subtract the divisor and set a '1'
      -- quotient bit for this round.
      if sub17(0) = '0' then
         diff <= sub17(1 to 16);
         q_bit <= '1';

      -- The partial result is smaller than the divisor
      -- so set a '0' quotient bit for this round.
      else
         diff <= rh;
         q_bit <= '0';
      end if;
   end process;

   -- Divide
   process (clk) begin if rising_edge(clk) then
      if reset = '1' then
         div_state <= st_idle;
      else

         rdy <= '1';
         dne <= '0';

         case div_state is

         when st_idle =>

            d <= unsigned(divisor);
            count <= 15;
            msb <= '0';

            -- Only change rl and rh when triggered so the registers
            -- retain their values after the division operation.
            if start = '1' then
               div_state <= st_op;
               rl <= dividend_lsb;
               rh <= unsigned(dividend_msb);
               rdy <= '0';
            end if;

         when st_op =>

            -- rl shifts left and stores the quotient bits.
            rl <= rl(1 to 15) & q_bit;
            -- rh shifts left and stores the difference and next dividend bit.
            rh <= diff(1 to 15) & rl(0);
            -- msb stores the shifted-out bit of rh for the 17-bit subtract.
            msb <= diff(0);

            count <= count - 1;
            rdy <= '0';

            if count = 0 then
               div_state <= st_done;
            end if;

         when st_done =>

            -- Final iteration stores the quotient and remainder.
            rl <= rl(1 to 15) & q_bit;
            rh <= diff;
            dne <= '1';
            div_state <= st_idle;

         end case;
      end if;
   end if; end process;

end rtl;
