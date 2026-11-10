//------------------------------------------------------------------------------
// Module      : sync_fifo_top
// Description : Top-level 8-bit x 16-depth Synchronous FIFO integrating control,
//               write pointer, read pointer, status flags, and memory array.
//------------------------------------------------------------------------------
module sync_fifo_top #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16,
    parameter ADDR_WIDTH = 4
)(
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire                  full,
    output wire                  empty
);

    localparam COUNT_WIDTH = ADDR_WIDTH + 1;

    wire                   mem_wr_en;
    wire                   mem_rd_en;
    wire                   wr_ptr_inc;
    wire                   rd_ptr_inc;
    wire                   count_wr_en;
    wire                   count_rd_en;
    wire [ADDR_WIDTH-1:0]  wr_ptr;
    wire [ADDR_WIDTH-1:0]  rd_ptr;
    wire [COUNT_WIDTH-1:0] fifo_count;

    // 1. FIFO Control Logic
    fifo_ctrl u_fifo_ctrl (
        .wr_en       (wr_en),
        .rd_en       (rd_en),
        .full        (full),
        .empty       (empty),
        .mem_wr_en   (mem_wr_en),
        .mem_rd_en   (mem_rd_en),
        .wr_ptr_inc  (wr_ptr_inc),
        .rd_ptr_inc  (rd_ptr_inc),
        .count_wr_en (count_wr_en),
        .count_rd_en (count_rd_en)
    );

    // 2. Write Pointer Logic
    fifo_wr_ptr #(
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_fifo_wr_ptr (
        .clk    (clk),
        .rst    (rst),
        .wr_inc (wr_ptr_inc),
        .wr_ptr (wr_ptr)
    );

    // 3. Read Pointer Logic
    fifo_rd_ptr #(
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_fifo_rd_ptr (
        .clk    (clk),
        .rst    (rst),
        .rd_inc (rd_ptr_inc),
        .rd_ptr (rd_ptr)
    );

    // 4. Full and Empty Detection
    fifo_status #(
        .DEPTH       (DEPTH),
        .COUNT_WIDTH (COUNT_WIDTH)
    ) u_fifo_status (
        .clk        (clk),
        .rst        (rst),
        .wr_valid   (count_wr_en),
        .rd_valid   (count_rd_en),
        .fifo_count (fifo_count),
        .full       (full),
        .empty      (empty)
    );

    // 5. FIFO Memory Array
    fifo_memory #(
        .DATA_WIDTH (DATA_WIDTH),
        .DEPTH      (DEPTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_fifo_memory (
        .clk     (clk),
        .rst     (rst),
        .wr_en   (mem_wr_en),
        .wr_addr (wr_ptr),
        .wr_data (wr_data),
        .rd_en   (mem_rd_en),
        .rd_addr (rd_ptr),
        .rd_data (rd_data)
    );

endmodule

