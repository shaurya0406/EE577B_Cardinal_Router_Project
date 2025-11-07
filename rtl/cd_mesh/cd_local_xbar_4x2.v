//======================================================================
// cd_local_xbar_4x2.v — Local converge crossbar (4 -> 2 request)
// - No integer/int, no for-loops; fully unrolled
// - Reply path ports present but stubbed for Phase-1
// - Valid asserts only when downstream ready (cv_ro)
//======================================================================
`timescale 1ns/1ps
`ifndef CD_LOCAL_XBAR_4X2_V
`define CD_LOCAL_XBAR_4X2_V

module cd_local_xbar_4x2
#( parameter DATA_W = 64 )
(
  input  wire                  clk,
  input  wire                  reset,

  // Request path: 4 router inputs -> 2 converged outputs
  input  wire  [3:0]           in_si,
  output wire  [3:0]           in_ri,
  input  wire  [4*DATA_W-1:0]  in_di,

  output wire  [1:0]           cv_so,
  input  wire  [1:0]           cv_ro,
  output wire  [2*DATA_W-1:0]  cv_do,

  // Reply path: 2 converged inputs -> 4 router outputs (Phase-1: stub)
  input  wire  [1:0]           cv_si_r,
  output wire  [1:0]           cv_ri_r,
  input  wire  [2*DATA_W-1:0]  cv_di_r,

  output wire  [3:0]           out_so,
  input  wire  [3:0]           out_ro,
  output wire  [4*DATA_W-1:0]  out_do
);

  // -------- Unpack request inputs
  wire [DATA_W-1:0] in_d0 = in_di[DATA_W*1-1:DATA_W*0];
  wire [DATA_W-1:0] in_d1 = in_di[DATA_W*2-1:DATA_W*1];
  wire [DATA_W-1:0] in_d2 = in_di[DATA_W*3-1:DATA_W*2];
  wire [DATA_W-1:0] in_d3 = in_di[DATA_W*4-1:DATA_W*3];

  // -------- Two independent RR arbiters for the two converged outputs
  wire [3:0] gnt_o0;
  wire [3:0] gnt_o1;

  // o0 arbitrates among all valid inputs (in_si)
  rr_arb4 u_rr_o0 (
    .clk(clk), .reset(reset),
    .req(in_si),
    .en (cv_ro[0]),
    .gnt(gnt_o0)
  );

  // o1 arbitrates among inputs not already granted by o0 (masking ensures no double-grant)
  wire [3:0] in_si_masked_o1 = in_si & ~gnt_o0;
  rr_arb4 u_rr_o1 (
    .clk(clk), .reset(reset),
    .req(in_si_masked_o1),
    .en (cv_ro[1]),
    .gnt(gnt_o1)
  );

  // -------- Data muxing (fully unrolled, no loops)
  wire [DATA_W-1:0] mux_o0_d =
      ({DATA_W{gnt_o0[0]}} & in_d0) |
      ({DATA_W{gnt_o0[1]}} & in_d1) |
      ({DATA_W{gnt_o0[2]}} & in_d2) |
      ({DATA_W{gnt_o0[3]}} & in_d3);

  wire [DATA_W-1:0] mux_o1_d =
      ({DATA_W{gnt_o1[0]}} & in_d0) |
      ({DATA_W{gnt_o1[1]}} & in_d1) |
      ({DATA_W{gnt_o1[2]}} & in_d2) |
      ({DATA_W{gnt_o1[3]}} & in_d3);

  // -------- Drive converged outputs (valid only if downstream ready)
  wire so0 = (|gnt_o0) & cv_ro[0];
  wire so1 = (|gnt_o1) & cv_ro[1];

  assign cv_so                = {so1, so0};
  assign cv_do[DATA_W*1-1:0]  = mux_o0_d;
  assign cv_do[DATA_W*2-1:DATA_W] = mux_o1_d;

  // -------- Backpressure to inputs: ready iff granted on some output and that output is ready
  wire [3:0] in_ri_vec = (gnt_o0 & {4{cv_ro[0]}}) | (gnt_o1 & {4{cv_ro[1]}});
  assign in_ri = in_ri_vec;

  // -------- Reply path (Phase-1: stubbed cleanly)
  assign cv_ri_r = 2'b00;
  assign out_so  = 4'b0000;
  assign out_do  = {4*DATA_W{1'b0}};
  // out_ro observed but unused here

endmodule
`endif
