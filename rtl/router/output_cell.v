// outbuf_cell.v
module outbuf_cell (
  input  wire        clk,
  input  wire        reset,
  // Enqueue from internal crossbar
  input  wire        enq,
  input  wire [63:0] d_in,
  input  wire        phase_internal,  // internal phase for this VC
  // Link to neighbor
  output wire        so,
  input  wire        ro,
  output wire [63:0] do,
  input  wire        phase_external,  // external phase for this VC
  // State
  output reg         full,
  output reg  [63:0] q
);
  assign so = phase_external & full & ro;
  assign do = (phase_external & full) ? q : 64'b0;

  always @(posedge clk) begin
    if (reset) begin
      full <= 1'b0;
      q    <= 64'b0;
    end else begin
      // Enqueue during internal phase only
      if (phase_internal & enq & ~full) begin
        q    <= d_in;
        full <= 1'b1;
      end
      // Send on external phase if neighbor ready
      if (phase_external & full & ro) begin
        full <= 1'b0;
      end
    end
  end
endmodule
