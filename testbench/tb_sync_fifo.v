`timescale 1ns / 1ps
//------------------------------------------------------------------------------
// Testbench   : tb_sync_fifo
// Description : Self-checking Verilog testbench for sync_fifo_top (8-bit x 16).
//               Verifies reset, single/multiple R/W, full/empty flags,
//               overflow/underflow prevention, simultaneous R/W, and pointer
//               wraparound against a behavioral golden reference model.
//------------------------------------------------------------------------------
module tb_sync_fifo;

    localparam DATA_WIDTH = 8;
    localparam DEPTH      = 16;
    localparam ADDR_WIDTH = 4;
    localparam CLK_PERIOD = 10;

    // DUT interface signals
    reg                   clk;
    reg                   rst;
    reg                   wr_en;
    reg  [DATA_WIDTH-1:0] wr_data;
    reg                   rd_en;
    wire [DATA_WIDTH-1:0] rd_data;
    wire                  full;
    wire                  empty;

    // Golden reference FIFO model state
    reg  [DATA_WIDTH-1:0] ref_mem [0:DEPTH-1];
    reg  [ADDR_WIDTH-1:0] ref_wr_ptr;
    reg  [ADDR_WIDTH-1:0] ref_rd_ptr;
    reg  [ADDR_WIDTH:0]   ref_count;
    reg  [DATA_WIDTH-1:0] ref_rd_data;
    reg                   ref_full;
    reg                   ref_empty;

    // Verification counters
    integer error_count;
    integer total_checks;
    integer total_reads;
    integer total_writes;
    integer idx;
    integer k;

    // Instantiate DUT
    sync_fifo_top #(
        .DATA_WIDTH (DATA_WIDTH),
        .DEPTH      (DEPTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) dut (
        .clk     (clk),
        .rst     (rst),
        .wr_en   (wr_en),
        .wr_data (wr_data),
        .rd_en   (rd_en),
        .rd_data (rd_data),
        .full    (full),
        .empty   (empty)
    );

    // Clock generation (100 MHz -> 10 ns period)
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // VCD waveform dump (optional alongside XSIM WDB)
    initial begin
        $dumpfile("fifo_waveforms.vcd");
        $dumpvars(0, tb_sync_fifo);
    end

    // Check DUT outputs against reference model
    task check_outputs;
        input check_rd_log;
        begin
            total_checks = total_checks + 1;

            if (rd_data !== ref_rd_data) begin
                error_count = error_count + 1;
                $display("[FAIL][%0t ns] rd_data mismatch: expected=0x%02h, actual=0x%02h",
                         $time, ref_rd_data, rd_data);
            end else if (check_rd_log) begin
                $display("[READ ][%0t ns] expected=0x%02h, actual=0x%02h (MATCH)",
                         $time, ref_rd_data, rd_data);
            end

            if (full !== ref_full) begin
                error_count = error_count + 1;
                $display("[FAIL][%0t ns] full flag mismatch: expected=%0b, actual=%0b",
                         $time, ref_full, full);
            end

            if (empty !== ref_empty) begin
                error_count = error_count + 1;
                $display("[FAIL][%0t ns] empty flag mismatch: expected=%0b, actual=%0b",
                         $time, ref_empty, empty);
            end
        end
    endtask

    // Apply synchronous reset for num_cycles clock edges
    task apply_reset;
        input [31:0] num_cycles;
        input        drive_en_during_rst;
        integer c;
        begin
            for (c = 0; c < num_cycles; c = c + 1) begin
                @(negedge clk);
                rst     = 1'b1;
                wr_en   = drive_en_during_rst;
                rd_en   = drive_en_during_rst;
                wr_data = drive_en_during_rst ? 8'hFF : 8'h00;

                @(posedge clk);
                #1;
                for (idx = 0; idx < DEPTH; idx = idx + 1) begin
                    ref_mem[idx] = {DATA_WIDTH{1'b0}};
                end
                ref_wr_ptr  = {ADDR_WIDTH{1'b0}};
                ref_rd_ptr  = {ADDR_WIDTH{1'b0}};
                ref_count   = {(ADDR_WIDTH+1){1'b0}};
                ref_rd_data = {DATA_WIDTH{1'b0}};
                ref_empty   = 1'b1;
                ref_full    = 1'b0;
                check_outputs(1'b0);
            end

            // Release reset and verify post-reset idle state
            @(negedge clk);
            rst     = 1'b0;
            wr_en   = 1'b0;
            rd_en   = 1'b0;
            wr_data = 8'h00;

            @(posedge clk);
            #1;
            check_outputs(1'b0);
        end
    endtask

    // Drive one clock cycle of stimulus and verify against golden model
    task step_cycle;
        input                  in_wr_en;
        input [DATA_WIDTH-1:0] in_wr_data;
        input                  in_rd_en;
        reg                    exp_wr_valid;
        reg                    exp_rd_valid;
        begin
            @(negedge clk);
            wr_en   = in_wr_en;
            wr_data = in_wr_data;
            rd_en   = in_rd_en;

            exp_wr_valid = in_wr_en & ~ref_full;
            exp_rd_valid = in_rd_en & ~ref_empty;

            @(posedge clk);
            // Update reference state using pre-edge storage semantics
            if (exp_rd_valid) begin
                ref_rd_data = ref_mem[ref_rd_ptr];
                ref_rd_ptr  = ref_rd_ptr + 4'd1;
                total_reads = total_reads + 1;
            end
            if (exp_wr_valid) begin
                ref_mem[ref_wr_ptr] = in_wr_data;
                ref_wr_ptr   = ref_wr_ptr + 4'd1;
                total_writes = total_writes + 1;
            end

            case ({exp_wr_valid, exp_rd_valid})
                2'b10:   ref_count = ref_count + 5'd1;
                2'b01:   ref_count = ref_count - 5'd1;
                default: ref_count = ref_count;
            endcase

            ref_empty = (ref_count == 5'd0);
            ref_full  = (ref_count == 5'd16);

            #1;
            check_outputs(exp_rd_valid);
        end
    endtask

    // Report status after each test phase
    task report_phase;
        input [8*48-1:0] test_name;
        input [31:0]     prev_errors;
        begin
            if (error_count == prev_errors) begin
                $display("[PASS] %0s (total_checks=%0d)", test_name, total_checks);
            end else begin
                $display("[FAIL] %0s (%0d new errors)", test_name, error_count - prev_errors);
            end
        end
    endtask

    integer prev_err;

    initial begin
        // Initialize testbench signals
        rst          = 1'b0;
        wr_en        = 1'b0;
        wr_data      = 8'h00;
        rd_en        = 1'b0;
        error_count  = 0;
        total_checks = 0;
        total_reads  = 0;
        total_writes = 0;

        $display("====================================================================");
        $display(" Starting Synchronous FIFO (8-bit x 16) Verification");
        $display("====================================================================");

        //----------------------------------------------------------------------
        // Test 1: Reset Operation (including active requests during reset)
        //----------------------------------------------------------------------
        prev_err = error_count;
        $display("\n--- Test 1: Reset Operation ---");
        apply_reset(2, 1'b1);
        if (empty !== 1'b1 || full !== 1'b0 || rd_data !== 8'h00) begin
            error_count = error_count + 1;
            $display("[FAIL] Post-reset flags/data incorrect: empty=%0b full=%0b rd_data=0x%02h",
                     empty, full, rd_data);
        end
        report_phase("Test 1: Reset Operation", prev_err);

        //----------------------------------------------------------------------
        // Test 2: Single Write and Single Read
        //----------------------------------------------------------------------
        prev_err = error_count;
        $display("\n--- Test 2: Single Write and Read ---");
        step_cycle(1'b1, 8'hA5, 1'b0);
        if (empty !== 1'b0 || full !== 1'b0) begin
            error_count = error_count + 1;
            $display("[FAIL] Flags incorrect after single write: empty=%0b full=%0b", empty, full);
        end
        step_cycle(1'b0, 8'h00, 1'b1);
        if (empty !== 1'b1 || full !== 1'b0 || rd_data !== 8'hA5) begin
            error_count = error_count + 1;
            $display("[FAIL] Single read check failed: empty=%0b full=%0b rd_data=0x%02h",
                     empty, full, rd_data);
        end
        report_phase("Test 2: Single Write and Read", prev_err);

        //----------------------------------------------------------------------
        // Test 3: Multiple Write Operations
        //----------------------------------------------------------------------
        prev_err = error_count;
        $display("\n--- Test 3: Multiple Write Operations (6 bytes) ---");
        for (k = 0; k < 6; k = k + 1) begin
            step_cycle(1'b1, 8'h11 * (k[7:0] + 8'd1), 1'b0);
        end
        if (empty !== 1'b0 || full !== 1'b0) begin
            error_count = error_count + 1;
            $display("[FAIL] Unexpected flags after 6 writes: empty=%0b full=%0b", empty, full);
        end
        report_phase("Test 3: Multiple Write Operations", prev_err);

        //----------------------------------------------------------------------
        // Test 4: Multiple Read Operations
        //----------------------------------------------------------------------
        prev_err = error_count;
        $display("\n--- Test 4: Multiple Read Operations (6 bytes) ---");
        for (k = 0; k < 6; k = k + 1) begin
            step_cycle(1'b0, 8'h00, 1'b1);
        end
        if (empty !== 1'b1 || full !== 1'b0) begin
            error_count = error_count + 1;
            $display("[FAIL] FIFO should be empty after draining 6 bytes");
        end
        report_phase("Test 4: Multiple Read Operations", prev_err);

        //----------------------------------------------------------------------
        // Test 5: FIFO Full Condition (Write 16 Locations)
        //----------------------------------------------------------------------
        prev_err = error_count;
        $display("\n--- Test 5: FIFO Full Condition (16 writes) ---");
        for (k = 0; k < DEPTH; k = k + 1) begin
            step_cycle(1'b1, 8'hD0 + k[7:0], 1'b0);
        end
        if (full !== 1'b1 || empty !== 1'b0) begin
            error_count = error_count + 1;
            $display("[FAIL] FIFO full flag not asserted after 16 writes");
        end
        report_phase("Test 5: FIFO Full Condition", prev_err);

        //----------------------------------------------------------------------
        // Test 6: Overflow Prevention (Attempt Writes While Full)
        //----------------------------------------------------------------------
        prev_err = error_count;
        $display("\n--- Test 6: Overflow Prevention ---");
        step_cycle(1'b1, 8'hEE, 1'b0);
        step_cycle(1'b1, 8'hEF, 1'b0);
        step_cycle(1'b1, 8'hFA, 1'b0);
        if (full !== 1'b1 || empty !== 1'b0) begin
            error_count = error_count + 1;
            $display("[FAIL] Flags corrupted during overflow attempt");
        end
        report_phase("Test 6: Overflow Prevention", prev_err);

        //----------------------------------------------------------------------
        // Test 7: FIFO Empty Condition (Drain All 16 Valid Locations)
        //----------------------------------------------------------------------
        prev_err = error_count;
        $display("\n--- Test 7: FIFO Empty Condition (16 reads) ---");
        for (k = 0; k < DEPTH; k = k + 1) begin
            step_cycle(1'b0, 8'h00, 1'b1);
        end
        if (empty !== 1'b1 || full !== 1'b0) begin
            error_count = error_count + 1;
            $display("[FAIL] FIFO empty flag not asserted after 16 reads");
        end
        report_phase("Test 7: FIFO Empty Condition", prev_err);

        //----------------------------------------------------------------------
        // Test 8: Underflow Prevention (Attempt Reads While Empty)
        //----------------------------------------------------------------------
        prev_err = error_count;
        $display("\n--- Test 8: Underflow Prevention ---");
        step_cycle(1'b0, 8'h00, 1'b1);
        step_cycle(1'b0, 8'h00, 1'b1);
        step_cycle(1'b0, 8'h00, 1'b1);
        // Verify pointer did not advance by writing and reading one known byte
        step_cycle(1'b1, 8'h5A, 1'b0);
        step_cycle(1'b0, 8'h00, 1'b1);
        if (rd_data !== 8'h5A || empty !== 1'b1) begin
            error_count = error_count + 1;
            $display("[FAIL] Underflow corrupted read pointer or data");
        end
        report_phase("Test 8: Underflow Prevention", prev_err);

        //----------------------------------------------------------------------
        // Test 9: Simultaneous Read and Write (Empty, Partial, Full Boundaries)
        //----------------------------------------------------------------------
        prev_err = error_count;
        $display("\n--- Test 9: Simultaneous Read and Write ---");
        // 9a: Simultaneous R/W while empty (write accepted, read ignored)
        step_cycle(1'b1, 8'h71, 1'b1);
        if (empty !== 1'b0 || full !== 1'b0) begin
            error_count = error_count + 1;
            $display("[FAIL] Simultaneous R/W on empty failed");
        end

        // Preload 2 more entries (total 3 entries)
        step_cycle(1'b1, 8'h72, 1'b0);
        step_cycle(1'b1, 8'h73, 1'b0);

        // 9b: 6 cycles of simultaneous R/W at partial occupancy (count stays 3)
        for (k = 0; k < 6; k = k + 1) begin
            step_cycle(1'b1, 8'h80 + k[7:0], 1'b1);
        end

        // Fill remaining 13 slots so FIFO becomes full (count = 16)
        for (k = 0; k < 13; k = k + 1) begin
            step_cycle(1'b1, 8'h90 + k[7:0], 1'b0);
        end
        if (full !== 1'b1) begin
            error_count = error_count + 1;
            $display("[FAIL] FIFO did not reach full prior to 9c");
        end

        // 9c: Simultaneous R/W while full (write blocked, read succeeds -> count = 15)
        step_cycle(1'b1, 8'hFE, 1'b1);
        if (full !== 1'b0 || empty !== 1'b0) begin
            error_count = error_count + 1;
            $display("[FAIL] Simultaneous R/W on full failed: full=%0b empty=%0b", full, empty);
        end

        // Drain remaining 15 entries to return to empty
        for (k = 0; k < 15; k = k + 1) begin
            step_cycle(1'b0, 8'h00, 1'b1);
        end
        report_phase("Test 9: Simultaneous Read and Write", prev_err);

        //----------------------------------------------------------------------
        // Test 10: Pointer Wraparound (Modulo-16 Address Wrap for Both Pointers)
        //----------------------------------------------------------------------
        prev_err = error_count;
        $display("\n--- Test 10: Pointer Wraparound ---");
        apply_reset(2, 1'b0);

        // Phase A: Write 12, Read 10 (wr_ptr=12, rd_ptr=10, count=2)
        for (k = 0; k < 12; k = k + 1) begin
            step_cycle(1'b1, 8'h20 + k[7:0], 1'b0);
        end
        for (k = 0; k < 10; k = k + 1) begin
            step_cycle(1'b0, 8'h00, 1'b1);
        end

        // Phase B: Write 10 (wr_ptr wraps 12 -> 15 -> 0 -> 6, count=12)
        for (k = 0; k < 10; k = k + 1) begin
            step_cycle(1'b1, 8'h40 + k[7:0], 1'b0);
        end
        if (dut.u_fifo_wr_ptr.wr_ptr !== 4'd6) begin
            error_count = error_count + 1;
            $display("[FAIL] Write pointer wraparound mismatch: expected=6, actual=%0d",
                     dut.u_fifo_wr_ptr.wr_ptr);
        end

        // Phase C: Read 12 (rd_ptr wraps 10 -> 15 -> 0 -> 6, count=0, empty=1)
        for (k = 0; k < 12; k = k + 1) begin
            step_cycle(1'b0, 8'h00, 1'b1);
        end
        if (dut.u_fifo_rd_ptr.rd_ptr !== 4'd6 || empty !== 1'b1) begin
            error_count = error_count + 1;
            $display("[FAIL] Read pointer wraparound mismatch: rd_ptr=%0d, empty=%0b",
                     dut.u_fifo_rd_ptr.rd_ptr, empty);
        end

        // Phase D: Full 16-entry cycle starting from non-zero wrapped offset (6 -> 15 -> 0 -> 6)
        for (k = 0; k < DEPTH; k = k + 1) begin
            step_cycle(1'b1, 8'hC0 + k[7:0], 1'b0);
        end
        if (full !== 1'b1 || dut.u_fifo_wr_ptr.wr_ptr !== 4'd6) begin
            error_count = error_count + 1;
            $display("[FAIL] Full wraparound write check failed");
        end
        for (k = 0; k < DEPTH; k = k + 1) begin
            step_cycle(1'b0, 8'h00, 1'b1);
        end
        if (empty !== 1'b1 || dut.u_fifo_rd_ptr.rd_ptr !== 4'd6) begin
            error_count = error_count + 1;
            $display("[FAIL] Full wraparound read check failed");
        end
        report_phase("Test 10: Pointer Wraparound", prev_err);

        // Idle cycle before finishing simulation
        step_cycle(1'b0, 8'h00, 1'b0);

        $display("\n====================================================================");
        $display(" Simulation Summary");
        $display("   Total Writes : %0d", total_writes);
        $display("   Total Reads  : %0d", total_reads);
        $display("   Total Checks : %0d", total_checks);
        $display("   Total Errors : %0d", error_count);
        if (error_count == 0) begin
            $display("   RESULT       : ALL TESTS PASSED");
        end else begin
            $display("   RESULT       : TESTS FAILED");
        end
        $display("====================================================================");

        $finish;
    end

endmodule

