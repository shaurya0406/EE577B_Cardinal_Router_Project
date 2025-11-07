`timescale 1ns/1ps
module outbuf_cell (
  input  wire        clk,
  input  wire        reset,
  // Enqueue from internal crossbar (internal phase only)
  input  wire        enq,
  input  wire [63:0] d_in,
  input  wire        phase_internal,
  // Link to neighbor (external phase only)
  output wire        so,
  input  wire        ro,
  output wire [63:0] dout,
  input  wire        phase_external,
  // State
  output reg         full,
  output reg  [63:0] q
);
  // Link valid only when a real transfer will occur
  assign so   = phase_external & full & ro;
  assign dout = so ? q : 64'b0;

  always @(posedge clk) begin
    if (reset) begin
      full <= 1'b0;
      q    <= 64'b0;
    end else begin
      // Accept from crossbar only in internal phase and only if empty
      if (phase_internal & enq & ~full) begin
        q    <= d_in;
        full <= 1'b1;
      end
      // Consume on the external phase handshake
      if (phase_external & full & ro) begin
        full <= 1'b0;
      end
    end
  end
endmodule
