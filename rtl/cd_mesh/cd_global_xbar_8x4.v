//======================================================================
// cd_global_xbar_8x4.v — REQUEST path (8 -> 4) for CD-mesh global xbar
// - No loops, no integer/int
// - LLC select = Hx[1:0] from hdr_fields (bits [55:52])
//======================================================================
`timescale 1ns/1ps
`ifndef CD_GLOBAL_XBAR_8X4_V
`define CD_GLOBAL_XBAR_8X4_V

module cd_global_xbar_8x4
#( parameter DATA_W = 64 )
(
  input  wire                   clk,
  input  wire                   reset,

  // From 8 converged local req links
  input  wire  [7:0]            in_si,
  output wire  [7:0]            in_ri,
  input  wire  [8*DATA_W-1:0]   in_di,

  // To 4 LLC request inputs
  output wire  [3:0]            llc_so,
  input  wire  [3:0]            llc_ro,
  output wire  [4*DATA_W-1:0]   llc_do,

  // -------- Reply ports (stub for Step 2C) --------
  input  wire  [3:0]            llc_si_r,
  output wire  [3:0]            llc_ri_r,
  input  wire  [4*DATA_W-1:0]   llc_di_r,

  output wire  [7:0]            out_so,
  input  wire  [7:0]            out_ro,
  output wire  [8*DATA_W-1:0]   out_do
);

  // -------- Unpack 8 inputs
  wire [DATA_W-1:0] d0 = in_di[DATA_W*1-1:DATA_W*0];
  wire [DATA_W-1:0] d1 = in_di[DATA_W*2-1:DATA_W*1];
  wire [DATA_W-1:0] d2 = in_di[DATA_W*3-1:DATA_W*2];
  wire [DATA_W-1:0] d3 = in_di[DATA_W*4-1:DATA_W*3];
  wire [DATA_W-1:0] d4 = in_di[DATA_W*5-1:DATA_W*4];
  wire [DATA_W-1:0] d5 = in_di[DATA_W*6-1:DATA_W*5];
  wire [DATA_W-1:0] d6 = in_di[DATA_W*7-1:DATA_W*6];
  wire [DATA_W-1:0] d7 = in_di[DATA_W*8-1:DATA_W*7];

  // -------- Decode Hx[1:0] from each input using hdr_fields
  wire        vc0,dx0,dy0; wire [4:0] rsv0; wire [3:0] hx0,hy0; wire [7:0] sx0,sy0;
  wire        vc1,dx1,dy1; wire [4:0] rsv1; wire [3:0] hx1,hy1; wire [7:0] sx1,sy1;
  wire        vc2,dx2,dy2; wire [4:0] rsv2; wire [3:0] hx2,hy2; wire [7:0] sx2,sy2;
  wire        vc3,dx3,dy3; wire [4:0] rsv3; wire [3:0] hx3,hy3; wire [7:0] sx3,sy3;
  wire        vc4,dx4,dy4; wire [4:0] rsv4; wire [3:0] hx4,hy4; wire [7:0] sx4,sy4;
  wire        vc5,dx5,dy5; wire [4:0] rsv5; wire [3:0] hx5,hy5; wire [7:0] sx5,sy5;
  wire        vc6,dx6,dy6; wire [4:0] rsv6; wire [3:0] hx6,hy6; wire [7:0] sx6,sy6;
  wire        vc7,dx7,dy7; wire [4:0] rsv7; wire [3:0] hx7,hy7; wire [7:0] sx7,sy7;

  hdr_fields u_hdr0(.pkt(d0),.vc(vc0),.dx(dx0),.dy(dy0),.rsv(rsv0),.hx(hx0),.hy(hy0),.srcx(sx0),.srcy(sy0));
  hdr_fields u_hdr1(.pkt(d1),.vc(vc1),.dx(dx1),.dy(dy1),.rsv(rsv1),.hx(hx1),.hy(hy1),.srcx(sx1),.srcy(sy1));
  hdr_fields u_hdr2(.pkt(d2),.vc(vc2),.dx(dx2),.dy(dy2),.rsv(rsv2),.hx(hx2),.hy(hy2),.srcx(sx2),.srcy(sy2));
  hdr_fields u_hdr3(.pkt(d3),.vc(vc3),.dx(dx3),.dy(dy3),.rsv(rsv3),.hx(hx3),.hy(hy3),.srcx(sx3),.srcy(sy3));
  hdr_fields u_hdr4(.pkt(d4),.vc(vc4),.dx(dx4),.dy(dy4),.rsv(rsv4),.hx(hx4),.hy(hy4),.srcx(sx4),.srcy(sy4));
  hdr_fields u_hdr5(.pkt(d5),.vc(vc5),.dx(dx5),.dy(dy5),.rsv(rsv5),.hx(hx5),.hy(hy5),.srcx(sx5),.srcy(sy5));
  hdr_fields u_hdr6(.pkt(d6),.vc(vc6),.dx(dx6),.dy(dy6),.rsv(rsv6),.hx(hx6),.hy(hy6),.srcx(sx6),.srcy(sy6));
  hdr_fields u_hdr7(.pkt(d7),.vc(vc7),.dx(dx7),.dy(dy7),.rsv(rsv7),.hx(hx7),.hy(hy7),.srcx(sx7),.srcy(sy7));

  // One-hot match vectors per LLC output (by Hx[1:0])
  wire [7:0] match0 = { (hx7[1:0]==2'b00), (hx6[1:0]==2'b00), (hx5[1:0]==2'b00), (hx4[1:0]==2'b00),
                        (hx3[1:0]==2'b00), (hx2[1:0]==2'b00), (hx1[1:0]==2'b00), (hx0[1:0]==2'b00) };
  wire [7:0] match1 = { (hx7[1:0]==2'b01), (hx6[1:0]==2'b01), (hx5[1:0]==2'b01), (hx4[1:0]==2'b01),
                        (hx3[1:0]==2'b01), (hx2[1:0]==2'b01), (hx1[1:0]==2'b01), (hx0[1:0]==2'b01) };
  wire [7:0] match2 = { (hx7[1:0]==2'b10), (hx6[1:0]==2'b10), (hx5[1:0]==2'b10), (hx4[1:0]==2'b10),
                        (hx3[1:0]==2'b10), (hx2[1:0]==2'b10), (hx1[1:0]==2'b10), (hx0[1:0]==2'b10) };
  wire [7:0] match3 = { (hx7[1:0]==2'b11), (hx6[1:0]==2'b11), (hx5[1:0]==2'b11), (hx4[1:0]==2'b11),
                        (hx3[1:0]==2'b11), (hx2[1:0]==2'b11), (hx1[1:0]==2'b11), (hx0[1:0]==2'b11) };

  // Requests into each LLC arbiter: only valid inputs that match that LLC
  wire [7:0] req0 = in_si & match0;
  wire [7:0] req1 = in_si & match1;
  wire [7:0] req2 = in_si & match2;
  wire [7:0] req3 = in_si & match3;

  // 8-way round-robin arbiters (enable by llc_ro[o])
  wire [7:0] g0, g1, g2, g3;
  rr_arb8 u_arb0(.clk(clk), .reset(reset), .req(req0), .en(llc_ro[0]), .gnt(g0));
  rr_arb8 u_arb1(.clk(clk), .reset(reset), .req(req1), .en(llc_ro[1]), .gnt(g1));
  rr_arb8 u_arb2(.clk(clk), .reset(reset), .req(req2), .en(llc_ro[2]), .gnt(g2));
  rr_arb8 u_arb3(.clk(clk), .reset(reset), .req(req3), .en(llc_ro[3]), .gnt(g3));

  // Output valids: fire if an input was granted and the LLC is ready
  wire so0 = |g0 & llc_ro[0];
  wire so1 = |g1 & llc_ro[1];
  wire so2 = |g2 & llc_ro[2];
  wire so3 = |g3 & llc_ro[3];
  assign llc_so = {so3,so2,so1,so0};

  // Data muxes per LLC (no loops)
  wire [DATA_W-1:0] d_mux0 =
      ({DATA_W{g0[0]}} & d0) | ({DATA_W{g0[1]}} & d1) | ({DATA_W{g0[2]}} & d2) | ({DATA_W{g0[3]}} & d3) |
      ({DATA_W{g0[4]}} & d4) | ({DATA_W{g0[5]}} & d5) | ({DATA_W{g0[6]}} & d6) | ({DATA_W{g0[7]}} & d7);

  wire [DATA_W-1:0] d_mux1 =
      ({DATA_W{g1[0]}} & d0) | ({DATA_W{g1[1]}} & d1) | ({DATA_W{g1[2]}} & d2) | ({DATA_W{g1[3]}} & d3) |
      ({DATA_W{g1[4]}} & d4) | ({DATA_W{g1[5]}} & d5) | ({DATA_W{g1[6]}} & d6) | ({DATA_W{g1[7]}} & d7);

  wire [DATA_W-1:0] d_mux2 =
      ({DATA_W{g2[0]}} & d0) | ({DATA_W{g2[1]}} & d1) | ({DATA_W{g2[2]}} & d2) | ({DATA_W{g2[3]}} & d3) |
      ({DATA_W{g2[4]}} & d4) | ({DATA_W{g2[5]}} & d5) | ({DATA_W{g2[6]}} & d6) | ({DATA_W{g2[7]}} & d7);

  wire [DATA_W-1:0] d_mux3 =
      ({DATA_W{g3[0]}} & d0) | ({DATA_W{g3[1]}} & d1) | ({DATA_W{g3[2]}} & d2) | ({DATA_W{g3[3]}} & d3) |
      ({DATA_W{g3[4]}} & d4) | ({DATA_W{g3[5]}} & d5) | ({DATA_W{g3[6]}} & d6) | ({DATA_W{g3[7]}} & d7);

  assign llc_do[DATA_W*1-1:DATA_W*0]   = d_mux0;
  assign llc_do[DATA_W*2-1:DATA_W*1]   = d_mux1;
  assign llc_do[DATA_W*3-1:DATA_W*2]   = d_mux2;
  assign llc_do[DATA_W*4-1:DATA_W*3]   = d_mux3;

  // Backpressure to inputs: ready if it won on its destination and that LLC is ready
  wire [7:0] in_ri0 = g0 & {8{llc_ro[0]}};
  wire [7:0] in_ri1 = g1 & {8{llc_ro[1]}};
  wire [7:0] in_ri2 = g2 & {8{llc_ro[2]}};
  wire [7:0] in_ri3 = g3 & {8{llc_ro[3]}};
  assign in_ri = in_ri0 | in_ri1 | in_ri2 | in_ri3;

  // // -------- Reply path STUB (filled in Step 2C) --------
  // assign llc_ri_r = 4'b0000;
  // assign out_so   = 8'b0000_0000;
  // assign out_do   = {8*DATA_W{1'b0}};
  // // out_ro observed but unused here

    // ======================== REPLY PATH (4 -> 8) =========================
  // Unpack 4 reply inputs (from LLCs)
  wire [DATA_W-1:0] r0 = llc_di_r[DATA_W*1-1:DATA_W*0];
  wire [DATA_W-1:0] r1 = llc_di_r[DATA_W*2-1:DATA_W*1];
  wire [DATA_W-1:0] r2 = llc_di_r[DATA_W*3-1:DATA_W*2];
  wire [DATA_W-1:0] r3 = llc_di_r[DATA_W*4-1:DATA_W*3];

  // Decode source coords
  // wire v0,dx0,dy0; wire [4:0] rv0; wire [3:0] hx0,hy0; wire [7:0] sx0,sy0;
  // wire v1,dx1,dy1; wire [4:0] rv1; wire [3:0] hx1,hy1; wire [7:0] sx1,sy1;
  // wire v2,dx2,dy2; wire [4:0] rv2; wire [3:0] hx2,hy2; wire [7:0] sx2,sy2;
  // wire v3,dx3,dy3; wire [4:0] rv3; wire [3:0] hx3,hy3; wire [7:0] sx3,sy3;
  hdr_fields uh0(.pkt(r0),.vc(v0),.dx(dx0),.dy(dy0),.rsv(rv0),.hx(hx0),.hy(hy0),.srcx(sx0),.srcy(sy0));
  hdr_fields uh1(.pkt(r1),.vc(v1),.dx(dx1),.dy(dy1),.rsv(rv1),.hx(hx1),.hy(hy1),.srcx(sx1),.srcy(sy1));
  hdr_fields uh2(.pkt(r2),.vc(v2),.dx(dx2),.dy(dy2),.rsv(rv2),.hx(hx2),.hy(hy2),.srcx(sx2),.srcy(sy2));
  hdr_fields uh3(.pkt(r3),.vc(v3),.dx(dx3),.dy(dy3),.rsv(rv3),.hx(hx3),.hy(hy3),.srcx(sx3),.srcy(sy3));

  // Quadrant base = {sy[1], sx[1]} * 2 ; per-quadrant link select = sy[0]
  wire [2:0] base0 = ({sy0[1], sx0[1]}==2'b00) ? 3'd0 :
                     ({sy0[1], sx0[1]}==2'b01) ? 3'd2 :
                     ({sy0[1], sx0[1]}==2'b10) ? 3'd4 : 3'd6;
  wire [2:0] base1 = ({sy1[1], sx1[1]}==2'b00) ? 3'd0 :
                     ({sy1[1], sx1[1]}==2'b01) ? 3'd2 :
                     ({sy1[1], sx1[1]}==2'b10) ? 3'd4 : 3'd6;
  wire [2:0] base2 = ({sy2[1], sx2[1]}==2'b00) ? 3'd0 :
                     ({sy2[1], sx2[1]}==2'b01) ? 3'd2 :
                     ({sy2[1], sx2[1]}==2'b10) ? 3'd4 : 3'd6;
  wire [2:0] base3 = ({sy3[1], sx3[1]}==2'b00) ? 3'd0 :
                     ({sy3[1], sx3[1]}==2'b01) ? 3'd2 :
                     ({sy3[1], sx3[1]}==2'b10) ? 3'd4 : 3'd6;

  wire [2:0] idx0 = base0 + {2'b00, sy0[0]}; // 0..7
  wire [2:0] idx1 = base1 + {2'b00, sy1[0]};
  wire [2:0] idx2 = base2 + {2'b00, sy2[0]};
  wire [2:0] idx3 = base3 + {2'b00, sy3[0]};

  // One-hot targets for each reply input (8 outputs)
  wire [7:0] t0 = (idx0==3'd0)?8'b0000_0001:(idx0==3'd1)?8'b0000_0010:(idx0==3'd2)?8'b0000_0100:(idx0==3'd3)?8'b0000_1000:
                  (idx0==3'd4)?8'b0001_0000:(idx0==3'd5)?8'b0010_0000:(idx0==3'd6)?8'b0100_0000:8'b1000_0000;
  wire [7:0] t1 = (idx1==3'd0)?8'b0000_0001:(idx1==3'd1)?8'b0000_0010:(idx1==3'd2)?8'b0000_0100:(idx1==3'd3)?8'b0000_1000:
                  (idx1==3'd4)?8'b0001_0000:(idx1==3'd5)?8'b0010_0000:(idx1==3'd6)?8'b0100_0000:8'b1000_0000;
  wire [7:0] t2 = (idx2==3'd0)?8'b0000_0001:(idx2==3'd1)?8'b0000_0010:(idx2==3'd2)?8'b0000_0100:(idx2==3'd3)?8'b0000_1000:
                  (idx2==3'd4)?8'b0001_0000:(idx2==3'd5)?8'b0010_0000:(idx2==3'd6)?8'b0100_0000:8'b1000_0000;
  wire [7:0] t3 = (idx3==3'd0)?8'b0000_0001:(idx3==3'd1)?8'b0000_0010:(idx3==3'd2)?8'b0000_0100:(idx3==3'd3)?8'b0000_1000:
                  (idx3==3'd4)?8'b0001_0000:(idx3==3'd5)?8'b0010_0000:(idx3==3'd6)?8'b0100_0000:8'b1000_0000;

  // Fixed-priority per output o: LLC0 > LLC1 > LLC2 > LLC3, gated by out_ro[o] and llc_si_r[k]
  // Compute winner lines wK_oX (K=input index, X=output index), unrolled
  // o0
  wire w0_o0 = llc_si_r[0] & t0[0] & out_ro[0];
  wire w1_o0 = llc_si_r[1] & t1[0] & out_ro[0] & ~w0_o0;
  wire w2_o0 = llc_si_r[2] & t2[0] & out_ro[0] & ~(w0_o0 | w1_o0);
  wire w3_o0 = llc_si_r[3] & t3[0] & out_ro[0] & ~(w0_o0 | w1_o0 | w2_o0);
  wire f_o0  = w0_o0 | w1_o0 | w2_o0 | w3_o0;

  // o1
  wire w0_o1 = llc_si_r[0] & t0[1] & out_ro[1];
  wire w1_o1 = llc_si_r[1] & t1[1] & out_ro[1] & ~w0_o1;
  wire w2_o1 = llc_si_r[2] & t2[1] & out_ro[1] & ~(w0_o1 | w1_o1);
  wire w3_o1 = llc_si_r[3] & t3[1] & out_ro[1] & ~(w0_o1 | w1_o1 | w2_o1);
  wire f_o1  = w0_o1 | w1_o1 | w2_o1 | w3_o1;

  // o2
  wire w0_o2 = llc_si_r[0] & t0[2] & out_ro[2];
  wire w1_o2 = llc_si_r[1] & t1[2] & out_ro[2] & ~w0_o2;
  wire w2_o2 = llc_si_r[2] & t2[2] & out_ro[2] & ~(w0_o2 | w1_o2);
  wire w3_o2 = llc_si_r[3] & t3[2] & out_ro[2] & ~(w0_o2 | w1_o2 | w2_o2);
  wire f_o2  = w0_o2 | w1_o2 | w2_o2 | w3_o2;

  // o3
  wire w0_o3 = llc_si_r[0] & t0[3] & out_ro[3];
  wire w1_o3 = llc_si_r[1] & t1[3] & out_ro[3] & ~w0_o3;
  wire w2_o3 = llc_si_r[2] & t2[3] & out_ro[3] & ~(w0_o3 | w1_o3);
  wire w3_o3 = llc_si_r[3] & t3[3] & out_ro[3] & ~(w0_o3 | w1_o3 | w2_o3);
  wire f_o3  = w0_o3 | w1_o3 | w2_o3 | w3_o3;

  // o4
  wire w0_o4 = llc_si_r[0] & t0[4] & out_ro[4];
  wire w1_o4 = llc_si_r[1] & t1[4] & out_ro[4] & ~w0_o4;
  wire w2_o4 = llc_si_r[2] & t2[4] & out_ro[4] & ~(w0_o4 | w1_o4);
  wire w3_o4 = llc_si_r[3] & t3[4] & out_ro[4] & ~(w0_o4 | w1_o4 | w2_o4);
  wire f_o4  = w0_o4 | w1_o4 | w2_o4 | w3_o4;

  // o5
  wire w0_o5 = llc_si_r[0] & t0[5] & out_ro[5];
  wire w1_o5 = llc_si_r[1] & t1[5] & out_ro[5] & ~w0_o5;
  wire w2_o5 = llc_si_r[2] & t2[5] & out_ro[5] & ~(w0_o5 | w1_o5);
  wire w3_o5 = llc_si_r[3] & t3[5] & out_ro[5] & ~(w0_o5 | w1_o5 | w2_o5);
  wire f_o5  = w0_o5 | w1_o5 | w2_o5 | w3_o5;

  // o6
  wire w0_o6 = llc_si_r[0] & t0[6] & out_ro[6];
  wire w1_o6 = llc_si_r[1] & t1[6] & out_ro[6] & ~w0_o6;
  wire w2_o6 = llc_si_r[2] & t2[6] & out_ro[6] & ~(w0_o6 | w1_o6);
  wire w3_o6 = llc_si_r[3] & t3[6] & out_ro[6] & ~(w0_o6 | w1_o6 | w2_o6);
  wire f_o6  = w0_o6 | w1_o6 | w2_o6 | w3_o6;

  // o7
  wire w0_o7 = llc_si_r[0] & t0[7] & out_ro[7];
  wire w1_o7 = llc_si_r[1] & t1[7] & out_ro[7] & ~w0_o7;
  wire w2_o7 = llc_si_r[2] & t2[7] & out_ro[7] & ~(w0_o7 | w1_o7);
  wire w3_o7 = llc_si_r[3] & t3[7] & out_ro[7] & ~(w0_o7 | w1_o7 | w2_o7);
  wire f_o7  = w0_o7 | w1_o7 | w2_o7 | w3_o7;

  assign out_so = {f_o7,f_o6,f_o5,f_o4,f_o3,f_o2,f_o1,f_o0};

  // data muxes
  assign out_do[DATA_W*1-1:DATA_W*0] =   w3_o0 ? r3 : (w2_o0 ? r2 : (w1_o0 ? r1 : (w0_o0 ? r0 : {DATA_W{1'b0}})));
  assign out_do[DATA_W*2-1:DATA_W*1] =   w3_o1 ? r3 : (w2_o1 ? r2 : (w1_o1 ? r1 : (w0_o1 ? r0 : {DATA_W{1'b0}})));
  assign out_do[DATA_W*3-1:DATA_W*2] =   w3_o2 ? r3 : (w2_o2 ? r2 : (w1_o2 ? r1 : (w0_o2 ? r0 : {DATA_W{1'b0}})));
  assign out_do[DATA_W*4-1:DATA_W*3] =   w3_o3 ? r3 : (w2_o3 ? r2 : (w1_o3 ? r1 : (w0_o3 ? r0 : {DATA_W{1'b0}})));
  assign out_do[DATA_W*5-1:DATA_W*4] =   w3_o4 ? r3 : (w2_o4 ? r2 : (w1_o4 ? r1 : (w0_o4 ? r0 : {DATA_W{1'b0}})));
  assign out_do[DATA_W*6-1:DATA_W*5] =   w3_o5 ? r3 : (w2_o5 ? r2 : (w1_o5 ? r1 : (w0_o5 ? r0 : {DATA_W{1'b0}})));
  assign out_do[DATA_W*7-1:DATA_W*6] =   w3_o6 ? r3 : (w2_o6 ? r2 : (w1_o6 ? r1 : (w0_o6 ? r0 : {DATA_W{1'b0}})));
  assign out_do[DATA_W*8-1:DATA_W*7] =   w3_o7 ? r3 : (w2_o7 ? r2 : (w1_o7 ? r1 : (w0_o7 ? r0 : {DATA_W{1'b0}})));

  // Backpressure to LLC replies: ready if that input won any output
  wire i0_win = w0_o0|w0_o1|w0_o2|w0_o3|w0_o4|w0_o5|w0_o6|w0_o7;
  wire i1_win = w1_o0|w1_o1|w1_o2|w1_o3|w1_o4|w1_o5|w1_o6|w1_o7;
  wire i2_win = w2_o0|w2_o1|w2_o2|w2_o3|w2_o4|w2_o5|w2_o6|w2_o7;
  wire i3_win = w3_o0|w3_o1|w3_o2|w3_o3|w3_o4|w3_o5|w3_o6|w3_o7;
  assign llc_ri_r = {i3_win,i2_win,i1_win,i0_win};


endmodule
`endif
