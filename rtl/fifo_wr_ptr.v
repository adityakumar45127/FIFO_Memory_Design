//------------------------------------------------------------------------------
// Module      : fifo_wr_ptr
// Description : Write pointer logic with synchronous reset and automatic
//               4-bit modulo-16 wraparound.
//------------------------------------------------------------------------------
module fifo_wr_ptr #(
    parameter ADDR_WIDTH = 4
)(
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  wr_inc,
    output reg  [ADDR_WIDTH-1:0] wr_ptr
);

    localparam [ADDR_WIDTH-1:0] PTR_INC = {{(ADDR_WIDTH-1){1'b0}}, 1'b1};

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= {ADDR_WIDTH{1'b0}};
        end else if (wr_inc) begin
            wr_ptr <= wr_ptr + PTR_INC;
        end
    end

endmodule

