# VLSI Placement Interview Preparation Guide (Synchronous FIFO)

This guide summarizes common technical interview questions you can answer directly from this project.

## 1. Architecture & Specification Questions

**Q1. Why is `fifo_count` 5 bits wide when `ADDR_WIDTH` is 4 bits?**
- A 16-entry FIFO has **17 possible occupancy states**: `0` (empty) through `16` (full).
- Four bits can only represent `0..15` (`16` states), which cannot distinguish empty (`0`) from full (`16`). Five bits (`[4:0]`) represent `0..31`, cleanly encoding `0` (`5'd0`) and `16` (`5'd16`).

**Q2. What are the two classic ways to detect `full` and `empty` in a synchronous FIFO, and why did this design use an occupancy counter?**
1. **Occupancy counter (`fifo_count`)**: A 5-bit up/down counter increments on write-only, decrements on read-only, and holds on idle or simultaneous R/W. `empty = (count == 0)`, `full = (count == DEPTH)`. Easy to read, supports arbitrary non-power-of-two depths, and isolates pointer logic from status logic.
2. **Extra MSB pointer bit**: Use `(ADDR_WIDTH + 1)`-bit write and read pointers. When the MSB matches and lower bits match, FIFO is empty; when the MSB differs and lower bits match, FIFO is full. Avoids an explicit counter but ties full/empty comparison across two pointer domains.

**Q3. Why is the read output `rd_data` registered inside `fifo_memory` instead of purely combinational (`assign rd_data = mem[rd_addr]`)?**
- Registered read output (`always @(posedge clk) if (rd_en) rd_data <= mem[rd_addr];`) eliminates combinational mux paths to output pins, improving FPGA timing (`Tco`), preventing glitches on `rd_data`, and cleanly resetting `rd_data` to `8'h00`.
- Trade-off: Read latency is 1 clock cycle after `rd_en` is sampled.

**Q4. How do you prevent overflow and underflow?**
- In `fifo_ctrl`: `wr_valid = wr_en & ~full` and `rd_valid = rd_en & ~empty`.
- External writes when `full == 1` never enable memory writes, pointer increments, or occupancy updates.
- External reads when `empty == 1` never enable memory reads, pointer increments, or occupancy decrements.

**Q5. Can a read/write address collision (`wr_addr == rd_addr`) ever happen during simultaneous read and write?**
- No. With `wr_valid = wr_en & ~full` and `rd_valid = rd_en & ~empty`, simultaneous valid read and write only occurs when `0 < fifo_count < 16`. In that strictly partial range, `wr_ptr` and `rd_ptr` can never point to the same address (`wr_ptr == rd_ptr` only occurs at `count == 0` or `count == 16`).

**Q6. What happens if `wr_en == 1` and `rd_en == 1` when the FIFO is full?**
- Because `wr_valid = wr_en & ~full`, `wr_valid = 0` and `rd_valid = 1`. The write is safely blocked (preventing overflow and avoiding a combinational dependency from `rd_en` onto `wr_valid`), while the read pops 1 element so `full` deasserts on the next cycle.

## 2. RTL Coding & Synthesis Questions

**Q7. Why use synchronous reset (`always @(posedge clk) if (rst)`) instead of asynchronous reset?**
- Xilinx 7-series FPGA flip-flops (`FDRE`) natively use synchronous set/reset control inputs (`R`).
- Synchronous reset ensures reset release timing is analyzed directly by Static Timing Analysis (STA) against `clk`, avoids reset-recovery/removal metastability issues, and prevents glitches on reset lines.

**Q8. Why does resetting `mem[0:15]` inside `fifo_memory` result in Flip-Flops (`FDRE`) instead of Block RAM or Distributed LUTRAM in Vivado?**
- Xilinx Distributed RAM (`RAM16X1S`/`RAM32M`) and Block RAM (`RAMB18E1`) do not support clearing all memory contents in a single clock cycle on `rst`.
- Because `fifo_memory` resets every `mem[i]` on `rst == 1`, Vivado maps the 16 × 8 array (128 bits) to slice flip-flops (`FDRE`) + LUT read multiplexers. For a tiny 128-bit FIFO, using FFs uses minimal slice resources (<1% of an Artix-7 XC7A35T) while ensuring zero `X`-propagation in simulation.

**Q9. How do you avoid simulation-synthesis mismatches and Verilog race conditions?**
- Use non-blocking assignments (`<=`) in all sequential `always @(posedge clk)` blocks and blocking/continuous assignments (`assign`) for combinational logic.
- In the testbench, drive stimulus on `negedge clk` and check settled outputs `#1` after `posedge clk` so setup/hold margins are unambiguous.

