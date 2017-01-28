# CORE9900
----------
**Copyright 2016 Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)**

Status: Work In Progress

Synthesizable binary-compatible TMS9900 16-bit CPU implemented in VHDL.
Differences from a real 9900:
  * No read-before-write.  A `bsel_n` output has been added so the memory system
    can decode the proper byte to update.
  * No attempt was made to reproduce the original instruction cycle timing.
  * Single-phase clock input active on the rising-edge.


Signal Prefix / Suffix Reference:
  * `_rt`   Defined record type
  * `_t`    Defined type
  * `_i`    Module input
  * `_o`    Module output
  * `_r`    Register
  * `_x`    Combinatorial "next state" signal
  * `_s`    Combinatorial signal
  * `_sel_` Multiplexer select signal
  * `_n_`   Active low signal
  * `_en_`  Enable signal

Bit numbering follows the original TI scheme with the MSbit being numbered as zero, which
is backwards from the industry standard.

Note that this does **not** effect the bit values, i.e. the left-most bit in a byte has a value
of 128, and the left-most bit in a word has a value of 32768, even though those bits are numbered
as bit zero:

|          | 128 |  64 |  32 |  16 |  8  |  4  |  2  |  1  |
| -------- |:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Industry |  7  |  6  |  5  |  4  |  3  |  2  |  1  |  0  |
| TMS9900  |  0  |  1  |  2  |  3  |  4  |  5  |  6  |  7  |


File tab-size is three spaces.

