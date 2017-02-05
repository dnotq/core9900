# Core 9900 Development Journal
Matthew Hagerty


## Thursday Dec 8, 2016

Starting with the divider circuit since I already have this HDL proven and working in the F18A 9900 core.

I decided to make this core as separate files instead of one monolithic file.  Personally I prefer a monolithic design for something like a CPU, but separating the core into modules will make testing each module easier.


## Saturday Dec 17, 2016

I have completely forgotten the details of how the divider works, and realized I very poorly documented it the first time around (I guess I thought it was simple and obvious enough to not need much commenting).  I added some ASCII diagrams and renamed signals to be consistent with my ever-changing conventions.  Some day I'll settle on something. ;-)


## Saturday Jan 28, 2017

I worked out the memory cycle timing and verified the !MEMEN, !WE, DBIN signals.  I also implemented the initial microcode FSM with a 1-depth stack to support a single branch / return.

The main core will run at 100MHz, however the memory cycle length will be controllable by an input signal (the number of 10ns counts in one memory cycle).  This allows the core to maintain somewhat accurate memory timing to the original 9900 (for designs emulating existing systems), but also run at speeds up to 100MHz if desired (who doesn't want to see their classic computer run 33-ish times faster? ;-) )  However, the internal FSM will still have 10ns cycles, so even with simulated memory cycle timing this core will still be faster than the original 9900 for cycles between memory access (i.e. ALU cycles, instruction decode, etc). 

In trying to connect the microcode signals to the memory FSM, I'm became frustrated that the inferred Block RAM is using the buffered output, which is causing problems holding the microcode FSM during a memory cycle.  The Xilinx docs indicate that the unbuffered combinatorial Block RAM output is available, but I might have to use the Xilinx specific form of the module to create the ROM.  I really don't want to do this for two reasons:

1. It greatly complicated writing the microcode in HDL due to the way the module macro accepts initial values, especially since I'm using the parity bits as data and they are initialized separately from the main data.

2. It makes the design more vendor specific.

Leaving it as-is for now while I mull over my options.  I have always considered writing a microcode compiler of sorts, which would make generating the ROM data trivial, but I'm really trying to avoid this.  I'd like to have the microcode human-editable in the HDL.


## Thursday Feb 2, 2017

After some Internet searching I realized that I could infer the Block RAM to use its unbuffered output.  Moving the memory read outside of the clock process is the solution.  I initially thought this would cause the memory to be inferred on LUTs, but keeping the address register inside the clock process produced the desired results.

Originally I had HDL similar to this:

```
   process (clk_i)
   begin if rising_edge(clk_i) then
      mcode_out_r <= microcode(to_integer(unsigned(mcode_x)));
      mcode_r     <= mcode_x;
   end if;
   end process;
```

This is the correct HDL.  The read is outside of the clock process, but the address is registered (it is registered by the Block RAM anyway):

```
   process (clk_i)
   begin if rising_edge(clk_i) then
      mcode_r <= mcode_x;
   end if;
   end process;
   
   mcode_out_s <= microcode(to_integer(unsigned(mcode_r)));
```

I'm happy with this solution since this means the microcode is still cycle efficient compared to a combinatorial decode (which I used in the F18A GPU).  This means that the Block RAM output is now part of the combinatorial path for the next state logic of the microcode, as well as any register select control signals that are not registered.  I'll need to keep this in mind.  This functionality is absolutely necessary for the microcode next-state logic to control the microcode address enable so it can be paused during memory cycles.  However, I may be able to register the other control signal outputs if necessary.


## Saturday Feb 4, 2017

Implemented a top level module and DCM to be able to synthesize the 9900 core.  I wanted to be able to run synthesis to make sure the constructs, particularly the Block ROM where being inferred correctly.  If you don't connect signals back to something tangible (for example, output nets) then the tools eliminate the blocks all together and you end up without any circuit at all.  Took me a while to realize that. ;-)

During synthesis, ISE (14.7) generated a warning against the microcode ROM signal:

> ```WARNING:Xst:2999 - Signal 'microcode', unconnected in block 'decode', is tied to its initial value.```

A quick Internet search indicated that this warning will always be generated when inferring a ROM, and it can be ignored.

Also added the ready, wait, and iaq signals.
