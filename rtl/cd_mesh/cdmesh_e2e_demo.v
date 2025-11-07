`timescale 1ns/1ps
`ifndef CDMESH_E2E_DEMO_V
`define CDMESH_E2E_DEMO_V
module cdmesh_e2e_demo
#( parameter DATA_W=64 )
(
  input  wire                 clk,
  input  wire                 reset,

  // Emulated router sources feeding Local0 (4 inputs)
  input  wire  [3:0]          l0_in_si,
  output wire  [3:0]          l0_in_ri,
  input  wire  [4*DATA_W-1:0] l0_in_di,

  // Replies back to those routers
  output wire  [3:0]          l0_out_so,
  input  wire  [3:0]          l0_out_ro,
  output wire  [4*DATA_W-1:0] l0_out_do
);

  // -------- Local0 (Q0)
  wire [1:0] l0_cv_so, l0_cv_ro;
  wire [2*DATA_W-1:0] l0_cv_do;
  wire [1:0] l0_cv_si_r, l0_cv_ri_r;
  wire [2*DATA_W-1:0] l0_cv_di_r;
  wire [3:0] sel_cv0, sel_cv1;

  cd_local_xbar_4x2 #(.DATA_W(DATA_W), .ROUTE_EXTERNAL(1)) u_local0 (
    .clk(clk), .reset(reset),
    .in_si(l0_in_si), .in_ri(l0_in_ri), .in_di(l0_in_di),
    .cv_so(l0_cv_so), .cv_ro(l0_cv_ro), .cv_do(l0_cv_do),
    .cv_si_r(l0_cv_si_r), .cv_ri_r(l0_cv_ri_r), .cv_di_r(l0_cv_di_r),
    .out_so(l0_out_so), .out_ro(l0_out_ro), .out_do(l0_out_do),
    .sel_cv0(sel_cv0), .sel_cv1(sel_cv1)
  );

  // -------- Global (tie Local0→Global inputs [1:0]; others zero)
  wire [7:0] g_in_si;
  wire [7:0] g_in_ri;
  wire [8*DATA_W-1:0] g_in_di;

  assign g_in_si[0] = l0_cv_so[0];
  assign g_in_si[1] = l0_cv_so[1];
  assign g_in_si[7:2] = 6'b0;

  assign l0_cv_ro = { g_in_ri[1], g_in_ri[0] };

  assign g_in_di[DATA_W*1-1:DATA_W*0] = l0_cv_do[DATA_W*1-1:DATA_W*0];
  assign g_in_di[DATA_W*2-1:DATA_W*1] = l0_cv_do[DATA_W*2-1:DATA_W*1];
  assign g_in_di[8*DATA_W-1:2*DATA_W] = { (6*DATA_W){1'b0} };

  // LLC side of global
  wire [3:0] llc_so, llc_ro;
  wire [4*DATA_W-1:0] llc_do;

  // Reply back path from LLC→Global
  wire [3:0] llc_si_r, llc_ri_r;
  wire [4*DATA_W-1:0] llc_di_r;

  // Global outputs to 8 converged links back to locals (we only use [1:0] for Local0)
  wire [7:0] g_out_so, g_out_ro;
  wire [8*DATA_W-1:0] g_out_do;

  // assign l0_cv_si_r = { g_out_so[1], g_out_so[0] };
  // assign g_out_ro[1:0] = { l0_cv_ri_r[1], l0_cv_ri_r[0] };
  // assign g_out_ro[7:2] = 6'b111111; // always ready (unused)

  assign l0_cv_si_r = { g_out_so[1], g_out_so[0] };
  assign g_out_ro   = 8'b1111_1111;  // BREAK LOOP: global reply outs always ready for demo
  // (l0_cv_ri_r is now unused here; that’s fine)


  assign l0_cv_di_r[DATA_W*1-1:DATA_W*0] = g_out_do[DATA_W*1-1:DATA_W*0];
  assign l0_cv_di_r[DATA_W*2-1:DATA_W*1] = g_out_do[DATA_W*2-1:DATA_W*1];

  // -------- Adapters
  wire [7:0] dst_o0, dst_o1, dst_o2, dst_o3;
  cd_global_req_dst_masks #(.DATA_W(DATA_W)) u_reqm (
    .d0(g_in_di[DATA_W*1-1:DATA_W*0]),
    .d1(g_in_di[DATA_W*2-1:DATA_W*1]),
    .d2({DATA_W{1'b0}}), .d3({DATA_W{1'b0}}),
    .d4({DATA_W{1'b0}}), .d5({DATA_W{1'b0}}),
    .d6({DATA_W{1'b0}}), .d7({DATA_W{1'b0}}),
    .dst_o0(dst_o0), .dst_o1(dst_o1), .dst_o2(dst_o2), .dst_o3(dst_o3)
  );

  wire [7:0] dst_r0, dst_r1, dst_r2, dst_r3;
  cd_global_reply_dst_masks #(.DATA_W(DATA_W)) u_repm (
    .l0_di(llc_di_r[DATA_W*1-1:DATA_W*0]),
    .l1_di(llc_di_r[DATA_W*2-1:DATA_W*1]),
    .l2_di(llc_di_r[DATA_W*3-1:DATA_W*2]),
    .l3_di(llc_di_r[DATA_W*4-1:DATA_W*3]),
    .dst_r0(dst_r0), .dst_r1(dst_r1), .dst_r2(dst_r2), .dst_r3(dst_r3)
  );

  cd_local_reply_select #(.DATA_W(DATA_W)) u_locsel (
    .cv0_di(l0_cv_di_r[DATA_W*1-1:DATA_W*0]),
    .cv1_di(l0_cv_di_r[DATA_W*2-1:DATA_W*1]),
    .sel_cv0(sel_cv0), .sel_cv1(sel_cv1)
  );

  // -------- Global Xbar
  cd_global_xbar_8x4 #(.DATA_W(DATA_W)) u_global (
    .clk(clk), .reset(reset),
    .in_si(g_in_si), .in_ri(g_in_ri), .in_di(g_in_di),
    .llc_so(llc_so), .llc_ro(llc_ro), .llc_do(llc_do),
    .dst_o0(dst_o0), .dst_o1(dst_o1), .dst_o2(dst_o2), .dst_o3(dst_o3),
    .llc_si_r(llc_si_r), .llc_ri_r(llc_ri_r), .llc_di_r(llc_di_r),
    .out_so(g_out_so), .out_ro(g_out_ro), .out_do(g_out_do),
    .dst_r0(dst_r0), .dst_r1(dst_r1), .dst_r2(dst_r2), .dst_r3(dst_r3)
  );

  // -------- 4x LLC proxies
  // Always ready
  assign llc_ro = 4'b1111;

  llc_proxy #(.DATA_W(DATA_W), .BURST(2), .LAT(2)) u_llc0 (
    .clk(clk), .reset(reset),
    .si(llc_so[0]), .ri(llc_ro[0]),                      // <-- FIXED
    .di(llc_do[DATA_W*1-1:DATA_W*0]),
    .so(llc_si_r[0]), .ro(1'b1),
    .dout(llc_di_r[DATA_W*1-1:DATA_W*0])
  );
  llc_proxy #(.DATA_W(DATA_W), .BURST(2), .LAT(2)) u_llc1 (
    .clk(clk), .reset(reset),
    .si(llc_so[1]), .ri(llc_ro[1]),                      // <-- FIXED
    .di(llc_do[DATA_W*2-1:DATA_W*1]),
    .so(llc_si_r[1]), .ro(1'b1),
    .dout(llc_di_r[DATA_W*2-1:DATA_W*1])
  );
  llc_proxy #(.DATA_W(DATA_W), .BURST(2), .LAT(2)) u_llc2 (
    .clk(clk), .reset(reset),
    .si(llc_so[2]), .ri(llc_ro[2]),                      // <-- FIXED
    .di(llc_do[DATA_W*3-1:DATA_W*2]),
    .so(llc_si_r[2]), .ro(1'b1),
    .dout(llc_di_r[DATA_W*3-1:DATA_W*2])
  );
  llc_proxy #(.DATA_W(DATA_W), .BURST(2), .LAT(2)) u_llc3 (
    .clk(clk), .reset(reset),
    .si(llc_so[3]), .ri(llc_ro[3]),                      // <-- FIXED
    .di(llc_do[DATA_W*4-1:DATA_W*3]),
    .so(llc_si_r[3]), .ro(1'b1),
    .dout(llc_di_r[DATA_W*4-1:DATA_W*3])
  );


endmodule
`endif
