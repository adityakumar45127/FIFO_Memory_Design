//------------------------------------------------------------------------------
// Module      : fifo_status
// Description : Full and empty flag detection logic using a synchronous
//               occupancy counter (0 to DEPTH).
//------------------------------------------------------------------------------
module fifo_status #(
    parameter DEPTH       = 16,
    parameter COUNT_WIDTH = 5
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   wr_valid,
    input  wire                   rd_valid,
    output reg  [COUNT_WIDTH-1:0] fifo_count,
    output wire                   full,
    output wire                   empty
);

    localparam [COUNT_WIDTH-1:0] COUNT_ZERO = {COUNT_WIDTH{1'b0}};
    localparam [COUNT_WIDTH-1:0] COUNT_ONE  = {{(COUNT_WIDTH-1){1'b0}}, 1'b1};
    localparam [COUNT_WIDTH-1:0] COUNT_MAX  = DEPTH;

    always @(posedge clk) begin
        if (rst) begin
            fifo_count <= COUNT_ZERO;
        end else begin
            case ({wr_valid, rd_valid})
                2'b10:   fifo_count <= fifo_count + COUNT_ONE; // Write only
                2'b01:   fifo_count <= fifo_count - COUNT_ONE; // Read only
                default: fifo_count <= fifo_count;             // Idle or simultaneous R/W
            endcase
        end
    end

    assign empty = (fifo_count == COUNT_ZERO);
    assign full  = (fifo_count == COUNT_MAX);

endmodule

