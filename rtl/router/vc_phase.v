// vc_phase.v
module vc_phase (
  input  wire clk,
  input  wire reset,   // active-high synchronous
  output reg  polarity // 0=even, 1=odd
);
  always @(posedge clk) begin
    if (reset) polarity <= 1'b0;
    else       polarity <= ~polarity;
  end
endmodule
