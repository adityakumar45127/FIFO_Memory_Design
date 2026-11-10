# RTL Simulation Guide (Xilinx Vivado XSIM)

> **Environment Note:** Xilinx Vivado / XSIM is not installed on the authoring workstation, so the simulation artifacts (`tb_sync_fifo_sim.wdb`, `fifo_waveforms.vcd`, `xsim_simulation.log`) must be generated locally in Vivado using the scripts provided in this directory.

## 1. Automated Command-Line Simulation (Windows)

Ensure the Xilinx Vivado `bin` directory is available in `PATH` (or run from the **Vivado Tcl Shell** / Vivado Command Prompt), then execute from `simulation/`:

```bat
run_sim.bat
```

Or run the three XSIM commands directly:

```bat
xvlog ../rtl/fifo_ctrl.v ../rtl/fifo_wr_ptr.v ../rtl/fifo_rd_ptr.v ../rtl/fifo_status.v ../rtl/fifo_memory.v ../rtl/sync_fifo_top.v ../testbench/tb_sync_fifo.v
xelab -debug typical tb_sync_fifo -s tb_sync_fifo_sim
xsim tb_sync_fifo_sim -tclbatch run_xsim.tcl -log xsim_simulation.log
```

## 2. Opening Simulation Waveforms in XSIM GUI

After running the batch simulation:

```bat
xsim --gui tb_sync_fifo_sim.wdb -view tb_sync_fifo_behav.wcfg
```

Alternatively, in **Vivado IDE**:
1. Create a new RTL project and add all 6 files from `rtl/` as Design Sources.
2. Add `testbench/tb_sync_fifo.v` as a Simulation Source.
3. Click **Flow Navigator -> Simulation -> Run Simulation -> Run Behavioral Simulation**.
4. Import `simulation/tb_sync_fifo_behav.wcfg` to view grouped clock/reset, write, read, status flags, and internal pointer signals.

## 3. Waveform Analysis Checklist

When inspecting the XSIM waveform window, verify these critical transitions:

| Test Case | Key Signals to Inspect | Expected Waveform Behavior |
| :--- | :--- | :--- |
| **Reset** | `rst`, `empty`, `full`, `rd_data`, `wr_ptr`, `rd_ptr`, `fifo_count` | On rising `clk` with `rst=1`, `empty=1`, `full=0`, `rd_data=8'h00`, `wr_ptr=0`, `rd_ptr=0`, `fifo_count=0` |
| **Single Write/Read** | `wr_en`, `wr_data`, `rd_en`, `rd_data`, `empty` | After write edge, `empty` drops `1 -> 0`; after read edge, `rd_data` updates to `8'hA5` and `empty` returns `0 -> 1` |
| **Full & Overflow** | `fifo_count`, `full`, `wr_en`, `wr_valid`, `wr_ptr` | At `fifo_count=16`, `full=1`; subsequent `wr_en=1` keeps `wr_valid=0` and `wr_ptr` frozen |
| **Empty & Underflow** | `fifo_count`, `empty`, `rd_en`, `rd_valid`, `rd_ptr` | At `fifo_count=0`, `empty=1`; subsequent `rd_en=1` keeps `rd_valid=0`, `rd_ptr` frozen, and `rd_data` stable |
| **Simultaneous R/W** | `wr_en`, `rd_en`, `wr_valid`, `rd_valid`, `fifo_count` | When `0 < fifo_count < 16`, both pointers advance each `clk` while `fifo_count` remains constant |
| **Wraparound** | `wr_ptr`, `rd_ptr` | Both 4-bit pointers transition cleanly from `15` (`4'hF`) back to `0` (`4'h0`) without data loss |

