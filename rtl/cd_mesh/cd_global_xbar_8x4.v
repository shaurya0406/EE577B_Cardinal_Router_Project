//======================================================================
// cd_global_xbar_8x4.v — Global crossbar
// - Request: 8 inputs -> 4 LLC outputs (per-output rr_arb8 + dst mask)
// - Reply:   4 inputs -> 8 outputs (per-output rr_arb4 + dst mask)
// - No integers, no loops
//======================================================================
`timescale 1ns/1ps
`ifndef CD_GLOBAL_XBAR_8X4_V
`define CD_GLOBAL_XBAR_8X4_V

module cd_global_xbar_8x4
#( parameter DATA_W = 64 )
(
  input  wire                  clk,
  input  wire                  reset,

  // -------- Request: in(8) -> llc(4)
  input  wire  [7:0]           in_si,
  output wire  [7:0]           in_ri,
  input  wire  [8*DATA_W-1:0]  in_di,

  output wire  [3:0]           llc_so,
  input  wire  [3:0]           llc_ro,
  output wire  [4*DATA_W-1:0]  llc_do,

  // Destination masks (one-hot per input for each output)
  input  wire  [7:0]           dst_o0,    // which inputs target LLC0
  input  wire  [7:0]           dst_o1,    // which inputs target LLC1
  input  wire  [7:0]           dst_o2,    // ...
  input  wire  [7:0]           dst_o3,

  // -------- Reply: llc(4) -> out(8)
  input  wire  [3:0]           llc_si_r,
  output wire  [3:0]           llc_ri_r,
  input  wire  [4*DATA_W-1:0]  llc_di_r,

  output wire  [7:0]           out_so,
  input  wire  [7:0]           out_ro,
  output wire  [8*DATA_W-1:0]  out_do,

  // Destination masks for reply (one-hot per LLC input to each out[0..7])
  input  wire  [7:0]           dst_r0,    // which out gets llc0 flit
  input  wire  [7:0]           dst_r1,    // which out gets llc1 flit
  input  wire  [7:0]           dst_r2,
  input  wire  [7:0]           dst_r3
);

  // ====== Unpack request inputs
  wire [DATA_W-1:0] i0 = in_di[DATA_W*1-1:DATA_W*0];
  wire [DATA_W-1:0] i1 = in_di[DATA_W*2-1:DATA_W*1];
  wire [DATA_W-1:0] i2 = in_di[DATA_W*3-1:DATA_W*2];
  wire [DATA_W-1:0] i3 = in_di[DATA_W*4-1:DATA_W*3];
  wire [DATA_W-1:0] i4 = in_di[DATA_W*5-1:DATA_W*4];
  wire [DATA_W-1:0] i5 = in_di[DATA_W*6-1:DATA_W*5];
  wire [DATA_W-1:0] i6 = in_di[DATA_W*7-1:DATA_W*6];
  wire [DATA_W-1:0] i7 = in_di[DATA_W*8-1:DATA_W*7];

  // Per-output masked request vectors
  wire [7:0] m0 = dst_o0 & in_si;
  wire [7:0] m1 = dst_o1 & in_si;
  wire [7:0] m2 = dst_o2 & in_si;
  wire [7:0] m3 = dst_o3 & in_si;

  // rr_arb8 per LLC output
  wire [7:0] g0, g1, g2, g3;
  rr_arb8 a0 (.clk(clk), .reset(reset), .req(m0), .en(llc_ro[0]), .gnt(g0));
  rr_arb8 a1 (.clk(clk), .reset(reset), .req(m1), .en(llc_ro[1]), .gnt(g1));
  rr_arb8 a2 (.clk(clk), .reset(reset), .req(m2), .en(llc_ro[2]), .gnt(g2));
  rr_arb8 a3 (.clk(clk), .reset(reset), .req(m3), .en(llc_ro[3]), .gnt(g3));

  // Data mux for LLC outputs
  wire [DATA_W-1:0] d0 = ({DATA_W{g0[0]}}&i0)|({DATA_W{g0[1]}}&i1)|({DATA_W{g0[2]}}&i2)|({DATA_W{g0[3]}}&i3)|
                         ({DATA_W{g0[4]}}&i4)|({DATA_W{g0[5]}}&i5)|({DATA_W{g0[6]}}&i6)|({DATA_W{g0[7]}}&i7);
  wire [DATA_W-1:0] d1 = ({DATA_W{g1[0]}}&i0)|({DATA_W{g1[1]}}&i1)|({DATA_W{g1[2]}}&i2)|({DATA_W{g1[3]}}&i3)|
                         ({DATA_W{g1[4]}}&i4)|({DATA_W{g1[5]}}&i5)|({DATA_W{g1[6]}}&i6)|({DATA_W{g1[7]}}&i7);
  wire [DATA_W-1:0] d2 = ({DATA_W{g2[0]}}&i0)|({DATA_W{g2[1]}}&i1)|({DATA_W{g2[2]}}&i2)|({DATA_W{g2[3]}}&i3)|
                         ({DATA_W{g2[4]}}&i4)|({DATA_W{g2[5]}}&i5)|({DATA_W{g2[6]}}&i6)|({DATA_W{g2[7]}}&i7);
  wire [DATA_W-1:0] d3 = ({DATA_W{g3[0]}}&i0)|({DATA_W{g3[1]}}&i1)|({DATA_W{g3[2]}}&i2)|({DATA_W{g3[3]}}&i3)|
                         ({DATA_W{g3[4]}}&i4)|({DATA_W{g3[5]}}&i5)|({DATA_W{g3[6]}}&i6)|({DATA_W{g3[7]}}&i7);

  assign llc_so = { (|g3)&llc_ro[3], (|g2)&llc_ro[2], (|g1)&llc_ro[1], (|g0)&llc_ro[0] };
  assign llc_do[DATA_W*1-1:DATA_W*0]   = d0;
  assign llc_do[DATA_W*2-1:DATA_W*1]   = d1;
  assign llc_do[DATA_W*3-1:DATA_W*2]   = d2;
  assign llc_do[DATA_W*4-1:DATA_W*3]   = d3;

  // Backpressure to inputs: ready if granted on any output targeting it
  wire [7:0] in_ri_vec = (g0 & {8{llc_ro[0]}}) | (g1 & {8{llc_ro[1]}}) |
                         (g2 & {8{llc_ro[2]}}) | (g3 & {8{llc_ro[3]}});

  assign in_ri = in_ri_vec;

  // ====== Reply: llc(4) -> out(8) via per-output rr_arb4

  wire [DATA_W-1:0] l0 = llc_di_r[DATA_W*1-1:DATA_W*0];
  wire [DATA_W-1:0] l1 = llc_di_r[DATA_W*2-1:DATA_W*1];
  wire [DATA_W-1:0] l2 = llc_di_r[DATA_W*3-1:DATA_W*2];
  wire [DATA_W-1:0] l3 = llc_di_r[DATA_W*4-1:DATA_W*3];

  // For each out[k], build req vec from llc_si_r masked by dst_r*
  wire [3:0] req_out0 = { llc_si_r[3] & dst_r3[0], llc_si_r[2] & dst_r2[0], llc_si_r[1] & dst_r1[0], llc_si_r[0] & dst_r0[0] };
  wire [3:0] req_out1 = { llc_si_r[3] & dst_r3[1], llc_si_r[2] & dst_r2[1], llc_si_r[1] & dst_r1[1], llc_si_r[0] & dst_r0[1] };
  wire [3:0] req_out2 = { llc_si_r[3] & dst_r3[2], llc_si_r[2] & dst_r2[2], llc_si_r[1] & dst_r1[2], llc_si_r[0] & dst_r0[2] };
  wire [3:0] req_out3 = { llc_si_r[3] & dst_r3[3], llc_si_r[2] & dst_r2[3], llc_si_r[1] & dst_r1[3], llc_si_r[0] & dst_r0[3] };
  wire [3:0] req_out4 = { llc_si_r[3] & dst_r3[4], llc_si_r[2] & dst_r2[4], llc_si_r[1] & dst_r1[4], llc_si_r[0] & dst_r0[4] };
  wire [3:0] req_out5 = { llc_si_r[3] & dst_r3[5], llc_si_r[2] & dst_r2[5], llc_si_r[1] & dst_r1[5], llc_si_r[0] & dst_r0[5] };
  wire [3:0] req_out6 = { llc_si_r[3] & dst_r3[6], llc_si_r[2] & dst_r2[6], llc_si_r[1] & dst_r1[6], llc_si_r[0] & dst_r0[6] };
  wire [3:0] req_out7 = { llc_si_r[3] & dst_r3[7], llc_si_r[2] & dst_r2[7], llc_si_r[1] & dst_r1[7], llc_si_r[0] & dst_r0[7] };

  wire [3:0] g_out0, g_out1, g_out2, g_out3, g_out4, g_out5, g_out6, g_out7;
  rr_arb4 r0 (.clk(clk), .reset(reset), .req(req_out0), .en(out_ro[0]), .gnt(g_out0));
  rr_arb4 r1 (.clk(clk), .reset(reset), .req(req_out1), .en(out_ro[1]), .gnt(g_out1));
  rr_arb4 r2 (.clk(clk), .reset(reset), .req(req_out2), .en(out_ro[2]), .gnt(g_out2));
  rr_arb4 r3 (.clk(clk), .reset(reset), .req(req_out3), .en(out_ro[3]), .gnt(g_out3));
  rr_arb4 r4 (.clk(clk), .reset(reset), .req(req_out4), .en(out_ro[4]), .gnt(g_out4));
  rr_arb4 r5 (.clk(clk), .reset(reset), .req(req_out5), .en(out_ro[5]), .gnt(g_out5));
  rr_arb4 r6 (.clk(clk), .reset(reset), .req(req_out6), .en(out_ro[6]), .gnt(g_out6));
  rr_arb4 r7 (.clk(clk), .reset(reset), .req(req_out7), .en(out_ro[7]), .gnt(g_out7));

  // out valids
  assign out_so[0] = (|g_out0) & out_ro[0];
  assign out_so[1] = (|g_out1) & out_ro[1];
  assign out_so[2] = (|g_out2) & out_ro[2];
  assign out_so[3] = (|g_out3) & out_ro[3];
  assign out_so[4] = (|g_out4) & out_ro[4];
  assign out_so[5] = (|g_out5) & out_ro[5];
  assign out_so[6] = (|g_out6) & out_ro[6];
  assign out_so[7] = (|g_out7) & out_ro[7];

  // out data muxing
  wire [DATA_W-1:0] mux0 = (g_out0[0]?l0:(g_out0[1]?l1:(g_out0[2]?l2:(g_out0[3]?l3:{DATA_W{1'b0}}))));
  wire [DATA_W-1:0] mux1 = (g_out1[0]?l0:(g_out1[1]?l1:(g_out1[2]?l2:(g_out1[3]?l3:{DATA_W{1'b0}}))));
  wire [DATA_W-1:0] mux2 = (g_out2[0]?l0:(g_out2[1]?l1:(g_out2[2]?l2:(g_out2[3]?l3:{DATA_W{1'b0}}))));
  wire [DATA_W-1:0] mux3 = (g_out3[0]?l0:(g_out3[1]?l1:(g_out3[2]?l2:(g_out3[3]?l3:{DATA_W{1'b0}}))));
  wire [DATA_W-1:0] mux4 = (g_out4[0]?l0:(g_out4[1]?l1:(g_out4[2]?l2:(g_out4[3]?l3:{DATA_W{1'b0}}))));
  wire [DATA_W-1:0] mux5 = (g_out5[0]?l0:(g_out5[1]?l1:(g_out5[2]?l2:(g_out5[3]?l3:{DATA_W{1'b0}}))));
  wire [DATA_W-1:0] mux6 = (g_out6[0]?l0:(g_out6[1]?l1:(g_out6[2]?l2:(g_out6[3]?l3:{DATA_W{1'b0}}))));
  wire [DATA_W-1:0] mux7 = (g_out7[0]?l0:(g_out7[1]?l1:(g_out7[2]?l2:(g_out7[3]?l3:{DATA_W{1'b0}}))));

  assign out_do[DATA_W*1-1:DATA_W*0]   = mux0;
  assign out_do[DATA_W*2-1:DATA_W*1]   = mux1;
  assign out_do[DATA_W*3-1:DATA_W*2]   = mux2;
  assign out_do[DATA_W*4-1:DATA_W*3]   = mux3;
  assign out_do[DATA_W*5-1:DATA_W*4]   = mux4;
  assign out_do[DATA_W*6-1:DATA_W*5]   = mux5;
  assign out_do[DATA_W*7-1:DATA_W*6]   = mux6;
  assign out_do[DATA_W*8-1:DATA_W*7]   = mux7;

  // backpressure to llc inputs: ready if their selected out is ready and got grant
  // Reduce: if any out[k] granted this llc input, llc_ri_r[*] high.
  wire llc0_g = g_out0[0]|g_out1[0]|g_out2[0]|g_out3[0]|g_out4[0]|g_out5[0]|g_out6[0]|g_out7[0];
  wire llc1_g = g_out0[1]|g_out1[1]|g_out2[1]|g_out3[1]|g_out4[1]|g_out5[1]|g_out6[1]|g_out7[1];
  wire llc2_g = g_out0[2]|g_out1[2]|g_out2[2]|g_out3[2]|g_out4[2]|g_out5[2]|g_out6[2]|g_out7[2];
  wire llc3_g = g_out0[3]|g_out1[3]|g_out2[3]|g_out3[3]|g_out4[3]|g_out5[3]|g_out6[3]|g_out7[3];

  assign llc_ri_r = { llc3_g & (|out_ro), llc2_g & (|out_ro), llc1_g & (|out_ro), llc0_g & (|out_ro) };

endmodule
`endif
