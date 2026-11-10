# Verification Plan (`tb_sync_fifo.v`)

## 1. Testbench Methodology

The testbench `tb_sync_fifo` uses a **self-checking golden reference model** (`ref_mem`, `ref_wr_ptr`, `ref_rd_ptr`, `ref_count`, `ref_rd_data`, `ref_full`, `ref_empty`) evaluated cycle-by-cycle against `sync_fifo_top`.

- **Clock**: `10 ns` period (`100 MHz`, 50% duty cycle).
- **Race-Free Stimulus Timing**: All inputs (`rst`, `wr_en`, `wr_data`, `rd_en`) are driven on `negedge clk` (5 ns setup margin before `posedge clk`).
- **Output Checking**: On every clock cycle (`posedge clk + 1 ns`), `rd_data`, `full`, and `empty` are compared with `===` (4-state equality, catching `X`/`Z` bugs) against the reference model.

## 2. Test Scenarios Matrix

| Test # | Scenario | Stimulus Sequence | Verification Criteria |
| :--- | :--- | :--- | :--- |
| **1** | **Reset Operation** | Assert `rst=1` for 2 clocks while `wr_en=1, rd_en=1, wr_data=0xFF`; release `rst=0` | Reset overrides active enables; `empty=1`, `full=0`, `rd_data=0x00` |
| **2** | **Single Write & Read** | Write `0xA5`; read 1 byte | `empty` drops `1->0` after write; `rd_data==0xA5` and `empty=1` after read |
| **3** | **Multiple Writes** | Write 6 bytes (`0x11, 0x22, ..., 0x66`) | `empty=0`, `full=0` throughout |
| **4** | **Multiple Reads** | Read 6 bytes consecutively | Read sequence strictly equals `0x11..0x66`; `empty=1` on 6th read |
| **5** | **FIFO Full Condition** | Write 16 bytes (`0xD0..0xDF`) | `full=0` on writes 1..15; `full=1`, `empty=0` on write 16 |
| **6** | **Overflow Prevention** | Drive `wr_en=1` with `0xEE, 0xEF, 0xFA` while `full=1` | `full` remains `1`; blocked writes do not overwrite `0xD0..0xDF` |
| **7** | **FIFO Empty Condition** | Read all 16 bytes (`0xD0..0xDF`) | All 16 bytes match expected order; `empty=1`, `full=0` on read 16 |
| **8** | **Underflow Prevention** | Drive `rd_en=1` for 3 clocks while `empty=1`; then write & read `0x5A` | `empty` stays `1`, `rd_data` stays stable, pointer does not advance; subsequent `0x5A` reads cleanly |
| **9** | **Simultaneous Read & Write** | (a) R/W on empty; (b) 6 cycles of R/W at count=3; (c) fill to 16, then R/W on full; drain | Empty R/W writes only; partial R/W preserves count=3 & exact FIFO order; full R/W reads only (`full` -> `0`) without overwrite |
| **10** | **Pointer Wraparound** | Write 12, read 10, write 10 (`wr_ptr`: `12->6`), read 12 (`rd_ptr`: `10->6`), full 16-entry cycle from offset 6 | Both 4-bit pointers wrap `15 -> 0` cleanly; all read bytes match reference queue |

## 3. Pass/Fail Criteria

Simulation passes when:
1. All 10 test phases report `[PASS]`.
2. Every read transaction prints `(MATCH)` between expected and actual `rd_data`.
3. Final summary reports `Total Errors : 0` and `RESULT : ALL TESTS PASSED`.

