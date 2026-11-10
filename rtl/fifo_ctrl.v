//------------------------------------------------------------------------------
// Module      : fifo_ctrl
// Description : FIFO control logic generating qualified write and read enables
//               to prevent overflow when full and underflow when empty.
//------------------------------------------------------------------------------
module fifo_ctrl (
    input  wire wr_en,
    input  wire rd_en,
    input  wire full,
    input  wire empty,
    output wire mem_wr_en,
    output wire mem_rd_en,
    output wire wr_ptr_inc,
    output wire rd_ptr_inc,
    output wire count_wr_en,
    output wire count_rd_en
);

    wire wr_valid;
    wire rd_valid;

    // Gate external requests against FIFO status flags
    assign wr_valid = wr_en & ~full;
    assign rd_valid = rd_en & ~empty;

    // Qualified write control outputs
    assign mem_wr_en   = wr_valid;
    assign wr_ptr_inc  = wr_valid;
    assign count_wr_en = wr_valid;

    // Qualified read control outputs
    assign mem_rd_en   = rd_valid;
    assign rd_ptr_inc  = rd_valid;
    assign count_rd_en = rd_valid;

endmodule

