//======================================================================
// cd_local_xbar_4x2.v — Local converge-diverge crossbar
// - Request: 4 -> 2 (RR + backpressure)
// - Reply:   2 -> 4 (external one-hot route OR RR fallback)
// - No integers, no for-loops
//======================================================================
`timescale 1ns/1ps
`ifndef CD_LOCAL_XBAR_4X2_V
`define CD_LOCAL_XBAR_4X2_V

module cd_local_xbar_4x2
#(
  parameter DATA_W        = 64,
  parameter ROUTE_EXTERNAL= 1    // 1: use sel_cv* one-hot for reply routing; 0: RR fallback
)
(
  input  wire                  clk,
  input  wire                  reset,

  // ---------------- Request path: routers(4) -> converged(2)
  input  wire  [3:0]           in_si,
  output wire  [3:0]           in_ri,
  input  wire  [4*DATA_W-1:0]  in_di,

  output wire  [1:0]           cv_so,     // to global_xbar
  input  wire  [1:0]           cv_ro,
  output wire  [2*DATA_W-1:0]  cv_do,

  // ---------------- Reply path: converged(2) -> routers(4)
  input  wire  [1:0]           cv_si_r,   // from global_xbar
  output wire  [1:0]           cv_ri_r,
  input  wire  [2*DATA_W-1:0]  cv_di_r,

  output wire  [3:0]           out_so,    // to 4 routers
  input  wire  [3:0]           out_ro,
  output wire  [4*DATA_W-1:0]  out_do,

  // -------- OPTIONAL: external one-hot selects for reply destinations
  // Each is 4'b0001->router0, 4'b0010->router1, 4'b0100->router2, 4'b1000->router3
  input  wire  [3:0]           sel_cv0,   // route for cv_di_r[0]
  input  wire  [3:0]           sel_cv1    // route for cv_di_r[1]
);

  // ====== REQUEST (4->2), unchanged ======
  wire [DATA_W-1:0] in_d0 = in_di[DATA_W*1-1:DATA_W*0];
  wire [DATA_W-1:0] in_d1 = in_di[DATA_W*2-1:DATA_W*1];
  wire [DATA_W-1:0] in_d2 = in_di[DATA_W*3-1:DATA_W*2];
  wire [DATA_W-1:0] in_d3 = in_di[DATA_W*4-1:DATA_W*3];

  wire [3:0] gnt_o0, gnt_o1;
  rr_arb4 u_rr_o0 (.clk(clk), .reset(reset), .req(in_si),              .en(cv_ro[0]), .gnt(gnt_o0));
  rr_arb4 u_rr_o1 (.clk(clk), .reset(reset), .req(in_si & ~gnt_o0),    .en(cv_ro[1]), .gnt(gnt_o1));

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

  wire so0 = (|gnt_o0) & cv_ro[0];
  wire so1 = (|gnt_o1) & cv_ro[1];

  assign cv_so = {so1, so0};
  assign cv_do[DATA_W*1-1:DATA_W*0]     = mux_o0_d;
  assign cv_do[DATA_W*2-1:DATA_W*1]     = mux_o1_d;
  assign in_ri = (gnt_o0 & {4{cv_ro[0]}}) | (gnt_o1 & {4{cv_ro[1]}});

  // ====== REPLY (2->4) ======
  wire [DATA_W-1:0] cv_d0 = cv_di_r[DATA_W*1-1:DATA_W*0];
  wire [DATA_W-1:0] cv_d1 = cv_di_r[DATA_W*2-1:DATA_W*1];

  // ---- Option A: external routing (one-hot)
  wire [3:0] sel0 = (ROUTE_EXTERNAL!=0) ? sel_cv0 : 4'b0000;
  wire [3:0] sel1 = (ROUTE_EXTERNAL!=0) ? sel_cv1 : 4'b0000;

  // ---- Option B: RR fallback (if ROUTE_EXTERNAL==0)
  wire use_rr = (ROUTE_EXTERNAL==0);
  // two tiny 4-way RR arbiters that assign cv0 and cv1 to one of 4 outs each
  wire [3:0] gnt_r0, gnt_r1;
  rr_arb4 u_rr_r0 (.clk(clk), .reset(reset), .req({4{cv_si_r[0]}}), .en(|out_ro), .gnt(gnt_r0)); // picks one out if cv0 valid
  rr_arb4 u_rr_r1 (.clk(clk), .reset(reset), .req({4{cv_si_r[1]}}), .en(|out_ro), .gnt(gnt_r1)); // picks one out if cv1 valid

  wire [3:0] route0 = use_rr ? (gnt_r0 & out_ro) : sel0;
  wire [3:0] route1 = use_rr ? (gnt_r1 & out_ro) : sel1;

  // backpressure to cv inputs: ready only if their chosen output is ready
  // If multiple bits are set (shouldn't happen), any ready bit permits transfer.
  wire cv0_hit = ( (route0[0] & out_ro[0]) | (route0[1] & out_ro[1]) |
                   (route0[2] & out_ro[2]) | (route0[3] & out_ro[3]) );
  wire cv1_hit = ( (route1[0] & out_ro[0]) | (route1[1] & out_ro[1]) |
                   (route1[2] & out_ro[2]) | (route1[3] & out_ro[3]) );

  assign cv_ri_r[0] = cv0_hit;
  assign cv_ri_r[1] = cv1_hit;

  // output valid if selected & input valid & that output ready
  wire so_r0_0 = route0[0] & cv_si_r[0] & out_ro[0];
  wire so_r0_1 = route0[1] & cv_si_r[0] & out_ro[1];
  wire so_r0_2 = route0[2] & cv_si_r[0] & out_ro[2];
  wire so_r0_3 = route0[3] & cv_si_r[0] & out_ro[3];

  wire so_r1_0 = route1[0] & cv_si_r[1] & out_ro[0];
  wire so_r1_1 = route1[1] & cv_si_r[1] & out_ro[1];
  wire so_r1_2 = route1[2] & cv_si_r[1] & out_ro[2];
  wire so_r1_3 = route1[3] & cv_si_r[1] & out_ro[3];

  assign out_so[0] = so_r0_0 | so_r1_0;
  assign out_so[1] = so_r0_1 | so_r1_1;
  assign out_so[2] = so_r0_2 | so_r1_2;
  assign out_so[3] = so_r0_3 | so_r1_3;

  // Data mux per output (if both cv0 and cv1 select same out, cv1 wins here; external decode should avoid conflicts)
  assign out_do[DATA_W*1-1:DATA_W*0]   = (so_r1_0 ? cv_d1 : (so_r0_0 ? cv_d0 : {DATA_W{1'b0}}));
  assign out_do[DATA_W*2-1:DATA_W*1]   = (so_r1_1 ? cv_d1 : (so_r0_1 ? cv_d0 : {DATA_W{1'b0}}));
  assign out_do[DATA_W*3-1:DATA_W*2]   = (so_r1_2 ? cv_d1 : (so_r0_2 ? cv_d0 : {DATA_W{1'b0}}));
  assign out_do[DATA_W*4-1:DATA_W*3]   = (so_r1_3 ? cv_d1 : (so_r0_3 ? cv_d0 : {DATA_W{1'b0}}));

endmodule
`endif
