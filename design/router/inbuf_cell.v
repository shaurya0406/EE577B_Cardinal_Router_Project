// inbuf_cell.v
module inbuf_cell (
  input  wire        clk,
  input  wire        reset,           // active-high synchronous
  // Link from neighbor (to us)
  input  wire        si,
  output wire        ri,
  input  wire [63:0] di,
  // Phase controls for THIS VC
  input  wire        phase_external,  // 1 when this VC is in external (link) phase
  input  wire        phase_internal,  // 1 when this VC is in internal (forward) phase
  // Router control to pop on internal forward
  input  wire        deq,
  // Buffer state
  output reg         full,
  output reg  [63:0] q
);
  assign ri = phase_external & ~full;

  always @(posedge clk) begin
    if (reset) begin
      full <= 1'b0;
      q    <= 64'b0;
    end else begin
      // Receive from link
      if (si & ri) begin
        q    <= di;
        full <= 1'b1;
      end
      // Dequeue on internal phase
      if (phase_internal & deq) begin
        full <= 1'b0;
      end
    end
  end
endmodule
