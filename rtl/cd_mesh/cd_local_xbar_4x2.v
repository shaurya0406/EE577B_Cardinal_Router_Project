`timescale 1ns/1ps
`ifndef CD_LOCAL_XBAR_4X2_V
`define CD_LOCAL_XBAR_4X2_V

module cd_local_xbar_4x2
#( parameter DATA_W = 64 )
(
  input  wire                  clk,
  input  wire                  reset,

  // ---------------- Request path: routers(4) -> converged(2)
  input  wire  [3:0]           in_si,
  output wire  [3:0]           in_ri,
  input  wire  [4*DATA_W-1:0]  in_di,

  output wire  [1:0]           cv_so,   // to global
  input  wire  [1:0]           cv_ro,
  output wire  [2*DATA_W-1:0]  cv_do,

  // ---------------- Reply path: converged(2) -> routers(4)
  input  wire  [1:0]           cv_si_r, // from global
  output wire  [1:0]           cv_ri_r,
  input  wire  [2*DATA_W-1:0]  cv_di_r,

  output wire  [3:0]           out_so,  // to routers
  input  wire  [3:0]           out_ro,
  output wire  [4*DATA_W-1:0]  out_do
);

  // ===== REQUEST (4 -> 2), RR per output, no loops/ints =====
  wire [DATA_W-1:0] in_d0 = in_di[DATA_W*1-1:DATA_W*0];
  wire [DATA_W-1:0] in_d1 = in_di[DATA_W*2-1:DATA_W*1];
  wire [DATA_W-1:0] in_d2 = in_di[DATA_W*3-1:DATA_W*2];
  wire [DATA_W-1:0] in_d3 = in_di[DATA_W*4-1:DATA_W*3];

  wire [3:0] gnt_o0;
  wire [3:0] gnt_o1;

  rr_arb4 u_rr_o0 (
    .clk(clk), .reset(reset),
    .req(in_si),
    .en (cv_ro[0]),
    .gnt(gnt_o0)
  );

  wire [3:0] in_si_masked_o1 = in_si & ~gnt_o0;

  rr_arb4 u_rr_o1 (
    .clk(clk), .reset(reset),
    .req(in_si_masked_o1),
    .en (cv_ro[1]),
    .gnt(gnt_o1)
  );

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
  assign cv_do[DATA_W*1-1:DATA_W*0]   = mux_o0_d;
  assign cv_do[DATA_W*2-1:DATA_W*1]   = mux_o1_d;

  wire [3:0] in_ri_vec = (gnt_o0 & {4{cv_ro[0]}}) | (gnt_o1 & {4{cv_ro[1]}});
  assign in_ri = in_ri_vec;

  // ===== REPLY (2 -> 4), decode via hdr_fields, conflict+BP =====

  // split reply inputs
  wire [DATA_W-1:0] r0_d = cv_di_r[DATA_W*1-1:DATA_W*0];
  wire [DATA_W-1:0] r1_d = cv_di_r[DATA_W*2-1:DATA_W*1];

  // decode src fields
  wire r0_vc, r0_dx, r0_dy; wire [4:0] r0_rsv; wire [3:0] r0_hx, r0_hy; wire [7:0] r0_x, r0_y;
  wire r1_vc, r1_dx, r1_dy; wire [4:0] r1_rsv; wire [3:0] r1_hx, r1_hy; wire [7:0] r1_x, r1_y;

  hdr_fields u_hdr_r0 (
    .pkt (r0_d), .vc(r0_vc), .dx(r0_dx), .dy(r0_dy),
    .rsv(r0_rsv), .hx(r0_hx), .hy(r0_hy), .srcx(r0_x), .srcy(r0_y)
  );
  hdr_fields u_hdr_r1 (
    .pkt (r1_d), .vc(r1_vc), .dx(r1_dx), .dy(r1_dy),
    .rsv(r1_rsv), .hx(r1_hx), .hy(r1_hy), .srcx(r1_x), .srcy(r1_y)
  );

  // tile index inside quadrant from LSBs of srcx/srcy
  wire x0 = r0_x[0];
  wire y0 = r0_y[0];
  wire x1 = r1_x[0];
  wire y1 = r1_y[0];

  // one-hot target per reply input: (x,y) => out{0..3}
  wire [3:0] tgt0 = (y0==1'b0 && x0==1'b0) ? 4'b0001 :
                    (y0==1'b0 && x0==1'b1) ? 4'b0010 :
                    (y0==1'b1 && x0==1'b0) ? 4'b0100 :
                                              4'b1000;

  wire [3:0] tgt1 = (y1==1'b0 && x1==1'b0) ? 4'b0001 :
                    (y1==1'b0 && x1==1'b1) ? 4'b0010 :
                    (y1==1'b1 && x1==1'b0) ? 4'b0100 :
                                              4'b1000;

  // per-output ready mask
  wire rdy0 = out_ro[0];
  wire rdy1 = out_ro[1];
  wire rdy2 = out_ro[2];
  wire rdy3 = out_ro[3];

  // fixed priority: input0 over input1
  wire w0_o0 = cv_si_r[0] & tgt0[0] & rdy0;
  wire w1_o0 = cv_si_r[1] & tgt1[0] & rdy0 & ~w0_o0;

  wire w0_o1 = cv_si_r[0] & tgt0[1] & rdy1;
  wire w1_o1 = cv_si_r[1] & tgt1[1] & rdy1 & ~w0_o1;

  wire w0_o2 = cv_si_r[0] & tgt0[2] & rdy2;
  wire w1_o2 = cv_si_r[1] & tgt1[2] & rdy2 & ~w0_o2;

  wire w0_o3 = cv_si_r[0] & tgt0[3] & rdy3;
  wire w1_o3 = cv_si_r[1] & tgt1[3] & rdy3 & ~w0_o3;

  // any fire per output
  wire f_o0 = w0_o0 | w1_o0;
  wire f_o1 = w0_o1 | w1_o1;
  wire f_o2 = w0_o2 | w1_o2;
  wire f_o3 = w0_o3 | w1_o3;

  assign out_so = {f_o3, f_o2, f_o1, f_o0};

  // data muxes (no double-drive)
  assign out_do[DATA_W*1-1:DATA_W*0]   = w1_o0 ? r1_d : (w0_o0 ? r0_d : {DATA_W{1'b0}});
  assign out_do[DATA_W*2-1:DATA_W*1]   = w1_o1 ? r1_d : (w0_o1 ? r0_d : {DATA_W{1'b0}});
  assign out_do[DATA_W*3-1:DATA_W*2]   = w1_o2 ? r1_d : (w0_o2 ? r0_d : {DATA_W{1'b0}});
  assign out_do[DATA_W*4-1:DATA_W*3]   = w1_o3 ? r1_d : (w0_o3 ? r0_d : {DATA_W{1'b0}});

  // backpressure to reply inputs: ready iff it actually won on some out
  wire i0_win = w0_o0 | w0_o1 | w0_o2 | w0_o3;
  wire i1_win = w1_o0 | w1_o1 | w1_o2 | w1_o3;
  assign cv_ri_r = { i1_win, i0_win };

endmodule
`endif
