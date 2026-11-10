//------------------------------------------------------------------------------
// Module      : fifo_rd_ptr
// Description : Read pointer logic with synchronous reset and automatic
//               4-bit modulo-16 wraparound.
//------------------------------------------------------------------------------
module fifo_rd_ptr #(
    parameter ADDR_WIDTH = 4
)(
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  rd_inc,
    output reg  [ADDR_WIDTH-1:0] rd_ptr
);

    localparam [ADDR_WIDTH-1:0] PTR_INC = {{(ADDR_WIDTH-1){1'b0}}, 1'b1};

    always @(posedge clk) begin
        if (rst) begin
            rd_ptr <= {ADDR_WIDTH{1'b0}};
        end else if (rd_inc) begin
            rd_ptr <= rd_ptr + PTR_INC;
        end
    end

endmodule

