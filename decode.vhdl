--
-- Copyright 2016 Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)
--
-- @author Matthew Hagerty
-- @author Erik Piehl
--
-- @date Jan 12, 2016
--
-- TMS9900 CPU Core
--
-- Decode and Control


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;


entity decode is
   generic (
      MEMCYCLE_COUNT : natural range 1 to 100 := 33      -- One memory cycle in 10ns counts
   );
   port (
      clk_i          : in  std_logic;
      reset_n_i      : in  std_logic;                    -- active low
      ready_i        : in  std_logic;                    -- active high, memory will be ready for read/write during the next cycle
      wait_o         : out std_logic;                    -- active high, indicates the 9900 is in a wait-state due to ready being low
      iaq_o          : out std_logic;                    -- active high, indicates the 9900 is fetching an instruction
      
   -- Memory interface
--      bsel_n_o       : out std_logic_vector(0 to 1);     -- 11=read, 01=MSB write, 10=LSB write, 00=WORD write
--      addr_o         : out std_logic_vector(0 to 15);    -- A0 = MSbit
--      din_i          : in  std_logic_vector(0 to 15);    -- D0 = MSbit
--      dout_o         : out std_logic_vector(0 to 15);    -- D0 = MSbit
      we_n_o         : out std_logic;                    -- active low
      dbin_o         : out std_logic;                    -- active high when reading the data bus
      memen_n_o      : out std_logic;                    -- active low, indicates addr contains a valid memory address

      -- ir_r_i         : in  std_logic_vector(0 to 15);    -- Instruction Register

      -- byte_s_o       : out std_logic;                    -- byte selector
      -- Td_s_o         : out std_logic_vector(0 to 1);     -- destination mode: Td
      -- Dc_s_o         : out std_logic_vector(0 to 3);     -- destination: D or C
      -- Ts_s_o         : out std_logic_vector(0 to 1);     -- source mode: Ts
      -- Sw_s_o         : out std_logic_vector(0 to 3);     -- source: S or W
      -- C_s_o          : out std_logic_vector(0 to 3);     -- count: C
      -- jmp_disp_s_o   : out std_logic_vector(0 to 7);     -- jump displacement
      -- Rn_s_o         : out std_logic_vector(0 to 3);     -- selected register

      -- Internal control signals
      ctl_wp_sel_s_o : out std_logic                     -- workspace register select
   );
end decode;

architecture rtl of decode is

   constant MEMCYC_CNT              : std_logic_vector(0 to 6) := std_logic_vector(to_unsigned(MEMCYCLE_COUNT-1, 7));

   -- Microcode constants
   constant EN_n                    : std_logic := '0';  -- Enable low
   constant ENA                     : std_logic := '1';  -- Enable high
   constant nop                     : std_logic := '0';  -- No-Op, inactive low
   constant nop_n                   : std_logic := '1';  -- No-Op, inactive high
   constant MCODE_BRA               : std_logic := '1';
   constant MCODE_RET               : std_logic := '1';
   constant NEXT_OP                 : std_logic_vector(0 to 9)  := "0000000000";
   constant RET_OP                  : std_logic_vector(0 to 9)  := "0000000001";
   constant BRA_RESET_VEC           : std_logic_vector(0 to 9)  := "1000000000";
   constant BRA_FETCH_VEC           : std_logic_vector(0 to 9)  := "1000000100";
   constant UNUSED                  : std_logic_vector(0 to 20) := "000000000000000000000";

   -- Microcode ROM 512x36 (18Kbits block RAM)
   type microcode_t is array (0 to 511) of std_logic_vector(0 to 35);
   signal microcode : microcode_t := (

   -- 0..25  : 26-bits of control
   -- 26     : 1-bit microcode address instruction:
   --          0 : LS-bit of address determines action: (0) increment, (1) return
   --          1 : Jump to absolute address, push current address on microcode stack
   -- 27..35 : 9-bits microcode address
   --
   -- reset op:
   -- RESET   LOAD   !MEMEN     !WE    IAQ            ADDR/OP
       nop  &  nop &  EN_n   &  EN_n & nop & UNUSED & NEXT_OP,
       nop  &  nop &  nop_n  & nop_n & nop & UNUSED & NEXT_OP,
       nop  &  nop &  nop_n  & nop_n & nop & UNUSED & BRA_FETCH_VEC,
       nop  &  nop &  nop_n  & nop_n & nop & UNUSED & BRA_RESET_VEC,

   -- init op:

   -- fetch op:
   -- RESET   LOAD   !MEMEN     !WE    IAQ            ADDR/OP
       nop  &  nop &   EN_n  & nop_n & ENA & UNUSED & NEXT_OP,
       nop  &  nop &  nop_n  & nop_n & nop & UNUSED & RET_OP,

   -- jump to reset:
   -- RESET   LOAD   !MEMEN     !WE    IAQ            ADDR/OP
       nop  &  nop &  nop_n  & nop_n & nop & UNUSED & BRA_RESET_VEC,
      others => (others => '0')
   );

   -- Microcode control
   signal ctl_memen_n_s                : std_logic;                  -- Memory Enable, active low
   signal ctl_we_n_s                   : std_logic;                  -- Write Enable, active low
   signal ctl_iaq_s                    : std_logic;                  -- Instruction Acquisition, active high

   signal ctl_mcode_addr_type_s        : std_logic;                  -- Type of microcode address
   signal ctl_mcode_addr_next_s        : std_logic_vector(0 to 8);   -- Next microcode address
   signal mcode_out_s                  : std_logic_vector(0 to 35);  -- Microcode output word

   signal mcode_en_s                   : std_logic;                  -- Microcode address enable
   signal mcode_r, mcode_x             : std_logic_vector(0 to 8);   -- Microcode address
   signal mcode_stack_r, mcode_stack_x : std_logic_vector(0 to 8);   -- One-address stack


   -- Memory cycle FSM
   type memory_t is (MEM_SELECT, MEM_CYCLE);
   signal memcycle_r, memcycle_x       : memory_t;                   -- Memory cycle state
   signal cycle_cnt_r, cycle_cnt_x     : std_logic_vector(0 to 6);   -- Memory cycle counter

   -- Memory control signals, registered
   signal memen_n_r, memen_n_x         : std_logic;
   signal dbin_r, dbin_x               : std_logic;
   signal we_n_r, we_n_x               : std_logic;
   signal iaq_r, iaq_x                 : std_logic;
   signal wait_r, wait_x               : std_logic;                  -- Registers mcode_en_s for the wait signal


begin


   -- Internal control output signals.
   ctl_wp_sel_s_o <= mcode_out_s(2);

   -- Registered memory signals suitable to drive real external memories.
   iaq_o          <= iaq_r;               -- active high, indicates the 9900 is fetching an instruction
   we_n_o         <= we_n_r;              -- active low
   dbin_o         <= dbin_r;              -- active high when reading the data bus
   memen_n_o      <= memen_n_r;           -- active low, indicates addr contains a valid memory address
   wait_o         <= wait_r;              -- active high, indicates the 9900 is in a wait-state due to ready being low 

   
   -- Opcode Formats
   --
   --          0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |10 |11 |12 |13 |14 |15 |
   --         ---------------------------------------------------------------+
   -- 1 arith  1 |opcode | B |  Td   |       D       |  Ts   |       S       |
   -- 2 arith  0   1 |opc| B |  Td   |       D       |  Ts   |       S       |
   -- 3 math   0   0   1 | --opcode- |     D or C    |  Ts   |       S       |
   -- 4 jump   0   0   0   1 | ----opcode--- |     signed displacement       |
   -- 5 shift  0   0   0   0   1 | --opcode- |       C       |       W       |
   -- 5 stack* 0   0   0   0   1 | 1 ------opcode--- | Ts/Td |      S/D      |
   -- 6 pgm    0   0   0   0   0   1 | ----opcode--- |  Ts   |       S       |
   -- 7 ctrl   0   0   0   0   0   0   1 | ----opcode--- |     not used      |
   -- 7 ctrl   0   0   0   0   0   0   1 | opcode & immd | X |       W       |
   --
   -- The stack format is new for added opcodes.  The original four shift
   -- opcodes have a 3-bit opcode, but only two-bits are needed to select
   -- the shift operation.  Therefore bit-5 is always '0'.  Setting bit-5
   -- to a '1' allows detection of the new instructions and modifies the
   -- remaining bits to specify the src or dst of the operation, since the
   -- stack always works with R15.



   -- The byte operator only exists in 8 instructions and is always bit 3.
--   byte_s_o       <= ir_r_i(3);           -- byte selector
--   Td_s_o         <= ir_r_i(4 to 5);      -- destination mode: Td
--   Dc_s_o         <= ir_r_i(6 to 9);      -- destination: D or C
--   Ts_s_o         <= ir_r_i(10 to 11);    -- source mode: Ts
--   Sw_s_o         <= ir_r_i(12 to 15);    -- source: S or W
--   C_s_o          <= ir_r_i(8 to 11);     -- count: C
--   jmp_disp_s_o   <= ir_r_i(8 to 15);     -- jump displacement


   -- Choose between source, destination, and fixed register values.
--   RegisterSelect : process (ctl_reg_sel_s, Sw_s_o, Dc_s_o)
--   begin
--      case ctl_reg_sel_s is
--      when REG_11    => Rn_s_o <= x"B";
--      when REG_12    => Rn_s_o <= x"C";
--      when REG_13    => Rn_s_o <= x"D";
--      when REG_14    => Rn_s_o <= x"E";
--      when REG_15    => Rn_s_o <= x"F";
--     when REG_Dc    => Rn_s_o <= Dc_s_o;
--      when others    => Rn_s_o <= Sw_s_o;
--      end case;
--   end process;


   -- Microcode FSM register transfer
   --
   MicrocodeRT :
   process (clk_i)
   begin if rising_edge(clk_i) then
      if reset_n_i = '0' then

         mcode_r        <= (others => '0');
         mcode_stack_r  <= (others => '0');

      else

         if mcode_en_s = ENA then
            mcode_r        <= mcode_x;
            mcode_stack_r  <= mcode_stack_x;
         end if;

      end if;
   end if;
   end process;

   -- Infer Block RAM with unregistered output.  Should not infer RAM on LUTs
   -- because the address is registered.
   -- Microcode read.  Accessed every cycle.
   mcode_out_s <= microcode(to_integer(unsigned(mcode_r)));

   -- Microcode signal distribution.  Signal names for convenience.
   ctl_memen_n_s              <= mcode_out_s(2);
   ctl_we_n_s                 <= mcode_out_s(3);
   ctl_iaq_s                  <= mcode_out_s(4);
   ctl_mcode_addr_type_s      <= mcode_out_s(26);
   ctl_mcode_addr_next_s      <= mcode_out_s(27 to 35);

   -- Disable the microcode address register during a memory cycle.
   mcode_en_s <= ctl_memen_n_s when cycle_cnt_x /= 0 else ENA;

   -- Microcode next state logic
   --
   MicrocodeCycle :
   process (mcode_r, mcode_stack_r, ctl_mcode_addr_type_s, ctl_mcode_addr_next_s)
   begin

      mcode_x <= mcode_r;
      mcode_stack_x <= mcode_stack_r;

      -- Priority encoder to determine next microcode state.


      -- Test for microcode absolute address branch.
      if ctl_mcode_addr_type_s = MCODE_BRA then
         mcode_x <= ctl_mcode_addr_next_s;
         -- Store the return address as the next microcode instruction after
         -- the branch instruction.
         mcode_stack_x <= mcode_r + 1;

      -- Test for microcode return op.
      elsif ctl_mcode_addr_next_s(8) = MCODE_RET then
         -- The return address is stored on the stack.
         mcode_x <= mcode_stack_r;

      -- Default, next microcode instruction.
      else
         mcode_x <= mcode_r + 1;

      end if;
   end process;


   -- Memory cycle FSM register transfer
   --
   MemoryCycleRT :
   process (clk_i)
   begin if rising_edge(clk_i) then
      if reset_n_i = '0' then

         memcycle_r  <= MEM_SELECT;
         cycle_cnt_r <= MEMCYC_CNT;
         memen_n_r   <= nop_n;
         dbin_r      <= nop;
         we_n_r      <= nop_n;
         iaq_r       <= nop;

      else

         memcycle_r  <= memcycle_x;
         cycle_cnt_r <= cycle_cnt_x;
         memen_n_r   <= memen_n_x;
         dbin_r      <= dbin_x;
         we_n_r      <= we_n_x;
         iaq_r       <= iaq_x;
         wait_r      <= wait_x;

      end if;
   end if;
   end process;

   -- Wait output when microcode addressing is paused and ready in low.
   wait_x <= not (mcode_en_s or ready_i);

   -- Memory cycle next state logic
   --
   MemoryCycle :
   process (memcycle_r, cycle_cnt_r, memen_n_r, dbin_r, we_n_r,
            ctl_memen_n_s, ctl_we_n_s, ctl_iaq_s,
            ready_i)
   begin

      memcycle_x  <= memcycle_r;
      cycle_cnt_x <= cycle_cnt_r;
      memen_n_x   <= memen_n_r;
      dbin_x      <= dbin_r;
      we_n_x      <= we_n_r;
      iaq_x       <= iaq_r;

      -- Hold the counter if the ready input goes low, but only if
      -- there are enough counts per memory cycle.
      if MEMCYC_CNT > 0 and ready_i = '1' then
         cycle_cnt_x <= cycle_cnt_r - 1;
      end if;

      
      case memcycle_r is

      when MEM_SELECT =>

         cycle_cnt_x <= MEMCYC_CNT;

         if ctl_memen_n_s = EN_n then

            memcycle_x  <= MEM_CYCLE;
            memen_n_x   <= ctl_memen_n_s;
            we_n_x      <= ctl_we_n_s;
            dbin_x      <= ctl_we_n_s;
            iaq_x       <= ctl_iaq_s;

         end if;

      when MEM_CYCLE =>

         if cycle_cnt_r = 0 then

            memcycle_x  <= MEM_SELECT;
            memen_n_x   <= nop_n;
            dbin_x      <= nop;
            we_n_x      <= nop_n;
            iaq_x       <= nop;

         end if;

      end case;

   end process;


end rtl;
