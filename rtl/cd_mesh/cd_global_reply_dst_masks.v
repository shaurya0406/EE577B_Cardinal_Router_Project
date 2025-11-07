//======================================================================
// cd_global_reply_dst_masks.v
// - For GLOBAL (4→8) reply path, compute which of 8 outs to target.
// - No integers, no loops. Pure combinational.
// - Chooses port-0 of the target local (even index): out = 2*local_id.
//======================================================================
`timescale 1ns/1ps
`ifndef CD_GLOBAL_REPLY_DST_MASKS_V
`define CD_GLOBAL_REPLY_DST_MASKS_V

module cd_global_reply_dst_masks
#(
  parameter DATA_W = 64,
  parameter HXO = 55, parameter HXW = 4,
  parameter HYO = 51, parameter HYW = 4,
  // Each LOCAL quadrant membership: four router coords (2x2 region)
  // Local0 (quadrant 0)
  parameter L0_RX0 = 0, parameter L0_RY0 = 0,
  parameter L0_RX1 = 1, parameter L0_RY1 = 0,
  parameter L0_RX2 = 0, parameter L0_RY2 = 1,
  parameter L0_RX3 = 1, parameter L0_RY3 = 1,
  // Local1 (quadrant 1)
  parameter L1_RX0 = 2, parameter L1_RY0 = 0,
  parameter L1_RX1 = 3, parameter L1_RY1 = 0,
  parameter L1_RX2 = 2, parameter L1_RY2 = 1,
  parameter L1_RX3 = 3, parameter L1_RY3 = 1,
  // Local2 (quadrant 2)
  parameter L2_RX0 = 0, parameter L2_RY0 = 2,
  parameter L2_RX1 = 1, parameter L2_RY1 = 2,
  parameter L2_RX2 = 0, parameter L2_RY2 = 3,
  parameter L2_RX3 = 1, parameter L2_RY3 = 3,
  // Local3 (quadrant 3)
  parameter L3_RX0 = 2, parameter L3_RY0 = 2,
  parameter L3_RX1 = 3, parameter L3_RY1 = 2,
  parameter L3_RX2 = 2, parameter L3_RY2 = 3,
  parameter L3_RX3 = 3, parameter L3_RY3 = 3
)
(
  // Four LLC reply inputs
  input  wire [DATA_W-1:0] l0_di,
  input  wire [DATA_W-1:0] l1_di,
  input  wire [DATA_W-1:0] l2_di,
  input  wire [DATA_W-1:0] l3_di,

  // One-hot 8-bit masks (which out[0..7] to use) for each LLC
  output wire [7:0]        dst_r0,
  output wire [7:0]        dst_r1,
  output wire [7:0]        dst_r2,
  output wire [7:0]        dst_r3
);

  // Helper: does (hx,hy) belong to local k's 2x2 set?
  // ---- LLC0
  wire [HXW-1:0] hx0 = l0_di[HXO -: HXW];  wire [HYW-1:0] hy0 = l0_di[HYO -: HYW];
  wire l0_in0 = ((hx0==L0_RX0[HXW-1:0]) & (hy0==L0_RY0[HYW-1:0])) |
                ((hx0==L0_RX1[HXW-1:0]) & (hy0==L0_RY1[HYW-1:0])) |
                ((hx0==L0_RX2[HXW-1:0]) & (hy0==L0_RY2[HYW-1:0])) |
                ((hx0==L0_RX3[HXW-1:0]) & (hy0==L0_RY3[HYW-1:0]));
  wire l0_in1 = ((hx0==L1_RX0[HXW-1:0]) & (hy0==L1_RY0[HYW-1:0])) |
                ((hx0==L1_RX1[HXW-1:0]) & (hy0==L1_RY1[HYW-1:0])) |
                ((hx0==L1_RX2[HXW-1:0]) & (hy0==L1_RY2[HYW-1:0])) |
                ((hx0==L1_RX3[HXW-1:0]) & (hy0==L1_RY3[HYW-1:0]));
  wire l0_in2 = ((hx0==L2_RX0[HXW-1:0]) & (hy0==L2_RY0[HYW-1:0])) |
                ((hx0==L2_RX1[HXW-1:0]) & (hy0==L2_RY1[HYW-1:0])) |
                ((hx0==L2_RX2[HXW-1:0]) & (hy0==L2_RY2[HYW-1:0])) |
                ((hx0==L2_RX3[HXW-1:0]) & (hy0==L2_RY3[HYW-1:0]));
  wire l0_in3 = ((hx0==L3_RX0[HXW-1:0]) & (hy0==L3_RY0[HYW-1:0])) |
                ((hx0==L3_RX1[HXW-1:0]) & (hy0==L3_RY1[HYW-1:0])) |
                ((hx0==L3_RX2[HXW-1:0]) & (hy0==L3_RY2[HYW-1:0])) |
                ((hx0==L3_RX3[HXW-1:0]) & (hy0==L3_RY3[HYW-1:0]));

  // Map local_id → out index = 2*local_id (port 0)
  assign dst_r0 = l0_in0 ? 8'b0000_0001 :
                  l0_in1 ? 8'b0000_0100 :
                  l0_in2 ? 8'b0001_0000 :
                  l0_in3 ? 8'b0100_0000 : 8'b0000_0000;

  // ---- LLC1
  wire [HXW-1:0] hx1 = l1_di[HXO -: HXW];  wire [HYW-1:0] hy1 = l1_di[HYO -: HYW];
  wire l1_in0 = ((hx1==L0_RX0[HXW-1:0]) & (hy1==L0_RY0[HYW-1:0])) |
                ((hx1==L0_RX1[HXW-1:0]) & (hy1==L0_RY1[HYW-1:0])) |
                ((hx1==L0_RX2[HXW-1:0]) & (hy1==L0_RY2[HYW-1:0])) |
                ((hx1==L0_RX3[HXW-1:0]) & (hy1==L0_RY3[HYW-1:0]));
  wire l1_in1 = ((hx1==L1_RX0[HXW-1:0]) & (hy1==L1_RY0[HYW-1:0])) |
                ((hx1==L1_RX1[HXW-1:0]) & (hy1==L1_RY1[HYW-1:0])) |
                ((hx1==L1_RX2[HXW-1:0]) & (hy1==L1_RY2[HYW-1:0])) |
                ((hx1==L1_RX3[HXW-1:0]) & (hy1==L1_RY3[HYW-1:0]));
  wire l1_in2 = ((hx1==L2_RX0[HXW-1:0]) & (hy1==L2_RY0[HYW-1:0])) |
                ((hx1==L2_RX1[HXW-1:0]) & (hy1==L2_RY1[HYW-1:0])) |
                ((hx1==L2_RX2[HXW-1:0]) & (hy1==L2_RY2[HYW-1:0])) |
                ((hx1==L2_RX3[HXW-1:0]) & (hy1==L2_RY3[HYW-1:0]));
  wire l1_in3 = ((hx1==L3_RX0[HXW-1:0]) & (hy1==L3_RY0[HYW-1:0])) |
                ((hx1==L3_RX1[HXW-1:0]) & (hy1==L3_RY1[HYW-1:0])) |
                ((hx1==L3_RX2[HXW-1:0]) & (hy1==L3_RY2[HYW-1:0])) |
                ((hx1==L3_RX3[HXW-1:0]) & (hy1==L3_RY3[HYW-1:0]));

  assign dst_r1 = l1_in0 ? 8'b0000_0001 :
                  l1_in1 ? 8'b0000_0100 :
                  l1_in2 ? 8'b0001_0000 :
                  l1_in3 ? 8'b0100_0000 : 8'b0000_0000;

  // ---- LLC2
  wire [HXW-1:0] hx2 = l2_di[HXO -: HXW];  wire [HYW-1:0] hy2 = l2_di[HYO -: HYW];
  wire l2_in0 = ((hx2==L0_RX0[HXW-1:0]) & (hy2==L0_RY0[HYW-1:0])) |
                ((hx2==L0_RX1[HXW-1:0]) & (hy2==L0_RY1[HYW-1:0])) |
                ((hx2==L0_RX2[HXW-1:0]) & (hy2==L0_RY2[HYW-1:0])) |
                ((hx2==L0_RX3[HXW-1:0]) & (hy2==L0_RY3[HYW-1:0]));
  wire l2_in1 = ((hx2==L1_RX0[HXW-1:0]) & (hy2==L1_RY0[HYW-1:0])) |
                ((hx2==L1_RX1[HXW-1:0]) & (hy2==L1_RY1[HYW-1:0])) |
                ((hx2==L1_RX2[HXW-1:0]) & (hy2==L1_RY2[HYW-1:0])) |
                ((hx2==L1_RX3[HXW-1:0]) & (hy2==L1_RY3[HYW-1:0]));
  wire l2_in2 = ((hx2==L2_RX0[HXW-1:0]) & (hy2==L2_RY0[HYW-1:0])) |
                ((hx2==L2_RX1[HXW-1:0]) & (hy2==L2_RY1[HYW-1:0])) |
                ((hx2==L2_RX2[HXW-1:0]) & (hy2==L2_RY2[HYW-1:0])) |
                ((hx2==L2_RX3[HXW-1:0]) & (hy2==L2_RY3[HYW-1:0]));
  wire l2_in3 = ((hx2==L3_RX0[HXW-1:0]) & (hy2==L3_RY0[HYW-1:0])) |
                ((hx2==L3_RX1[HXW-1:0]) & (hy2==L3_RY1[HYW-1:0])) |
                ((hx2==L3_RX2[HXW-1:0]) & (hy2==L3_RY2[HYW-1:0])) |
                ((hx2==L3_RX3[HXW-1:0]) & (hy2==L3_RY3[HYW-1:0]));

  assign dst_r2 = l2_in0 ? 8'b0000_0001 :
                  l2_in1 ? 8'b0000_0100 :
                  l2_in2 ? 8'b0001_0000 :
                  l2_in3 ? 8'b0100_0000 : 8'b0000_0000;

  // ---- LLC3
  wire [HXW-1:0] hx3 = l3_di[HXO -: HXW];  wire [HYW-1:0] hy3 = l3_di[HYO -: HYW];
  wire l3_in0 = ((hx3==L0_RX0[HXW-1:0]) & (hy3==L0_RY0[HYW-1:0])) |
                ((hx3==L0_RX1[HXW-1:0]) & (hy3==L0_RY1[HYW-1:0])) |
                ((hx3==L0_RX2[HXW-1:0]) & (hy3==L0_RY2[HYW-1:0])) |
                ((hx3==L0_RX3[HXW-1:0]) & (hy3==L0_RY3[HYW-1:0]));
  wire l3_in1 = ((hx3==L1_RX0[HXW-1:0]) & (hy3==L1_RY0[HYW-1:0])) |
                ((hx3==L1_RX1[HXW-1:0]) & (hy3==L1_RY1[HYW-1:0])) |
                ((hx3==L1_RX2[HXW-1:0]) & (hy3==L1_RY2[HYW-1:0])) |
                ((hx3==L1_RX3[HXW-1:0]) & (hy3==L1_RY3[HYW-1:0]));
  wire l3_in2 = ((hx3==L2_RX0[HXW-1:0]) & (hy3==L2_RY0[HYW-1:0])) |
                ((hx3==L2_RX1[HXW-1:0]) & (hy3==L2_RY1[HYW-1:0])) |
                ((hx3==L2_RX2[HXW-1:0]) & (hy3==L2_RY2[HYW-1:0])) |
                ((hx3==L2_RX3[HXW-1:0]) & (hy3==L2_RY3[HYW-1:0]));
  wire l3_in3 = ((hx3==L3_RX0[HXW-1:0]) & (hy3==L3_RY0[HYW-1:0])) |
                ((hx3==L3_RX1[HXW-1:0]) & (hy3==L3_RY1[HYW-1:0])) |
                ((hx3==L3_RX2[HXW-1:0]) & (hy3==L3_RY2[HYW-1:0])) |
                ((hx3==L3_RX3[HXW-1:0]) & (hy3==L3_RY3[HYW-1:0]));

  assign dst_r3 = l3_in0 ? 8'b0000_0001 :
                  l3_in1 ? 8'b0000_0100 :
                  l3_in2 ? 8'b0001_0000 :
                  l3_in3 ? 8'b0100_0000 : 8'b0000_0000;

endmodule
`endif
