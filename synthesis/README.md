# RTL Synthesis Guide (Xilinx Vivado)

> **Environment Note:** Xilinx Vivado is not installed on the authoring workstation, so actual Vivado synthesis reports (`utilization_synth.rpt`, `timing_summary_synth.rpt`, etc.) have not been generated yet and must be produced locally by running Vivado with the Tcl script below.

## 1. Automated Command-Line Synthesis

From `synthesis/`, run in a Vivado Command Prompt / Tcl environment:

```bat
run_synth.bat
```

Or invoke Vivado directly:

```bat
vivado -mode batch -source run_vivado_synth.tcl -log reports/vivado_synth.log -journal reports/vivado_synth.jou
```

To target a different Xilinx FPGA part (default: `xc7a35tcpg236-1`), set `VIVADO_PART` beforehand:

```bat
set VIVADO_PART=xc7a100tcsg324-1
run_synth.bat
```

### Vivado GUI Project Setup (Optional)

To open a full `.xpr` Vivado GUI project (for viewing the Elaborated RTL Schematic, interactive waveforms, and GUI Utilization/Timing views), run in the **Vivado Tcl Console**:

```tcl
cd <path-to-repo>/FIFO_Memory_Design/synthesis
source create_vivado_project.tcl
```

## 2. Generated Reports (`synthesis/reports/`)

| Report File | Contents |
| :--- | :--- |
| `utilization_synth.rpt` | Slice LUTs, Flip-Flops (`FDRE`), Muxes, and per-module hierarchical resource breakdown |
| `timing_summary_synth.rpt` | Setup (`WNS`, `TNS`) and Hold (`WHS`, `THS`) slack summary plus top 10 critical paths against the 100 MHz clock constraint |
| `clock_utilization_synth.rpt` | Clock buffer (`BUFG`) and clock net routing summary |
| `drc_synth.rpt` | Post-synthesis Design Rule Check summary |
| `power_synth.rpt` | Estimated static and dynamic power |
| `sync_fifo_synth.dcp` | Post-synthesis Vivado Design Checkpoint |

## 3. What to Examine in the Reports

1. **Flip-Flop Utilization (`FDRE`)**:
   - `fifo_memory`: 16 locations x 8 bits = 128 FFs + 8 FFs for registered `rd_data` = 136 FFs.
   - `fifo_wr_ptr`: 4 FFs.
   - `fifo_rd_ptr`: 4 FFs.
   - `fifo_status`: 5 FFs (`fifo_count[4:0]`).
   - Total expected flip-flops: ~149 FFs (verify exact post-synthesis count in `utilization_synth.rpt`, including any duplicated control FFs if Vivado performs optimization).
2. **LUT Utilization**:
   - Read-port 16:1 multiplexer (`8` bits wide using `LUT6`/`MUXF7`), write decode/enable logic in `fifo_memory`, incrementers in pointers, 5-bit up/down counter and `full`/`empty` comparators in `fifo_status`, and 2-gate enable qualification in `fifo_ctrl`.
   - Verify zero inferred latches (`Latch` count = 0) and zero `Block RAM` usage (intended small register-array implementation).
3. **Timing Reports (`timing_summary_synth.rpt`)**:
   - Verify `WNS >= 0.000 ns` and `WHS >= 0.000 ns` at 100 MHz (`10.000 ns` period).
   - Inspect the worst setup path (typically either `fifo_count` -> `full`/`empty` -> `wr_valid`/`rd_valid` -> `mem` CE/D, or `rd_ptr` -> 16:1 read mux -> `rd_data` D).

