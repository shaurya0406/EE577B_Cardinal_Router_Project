//======================================================================
// cd_global_req_dst_masks.v
// - For GLOBAL (8→4) request path, compute per-LLC input masks.
// - No integers, no loops. Pure combinational.
//======================================================================
`timescale 1ns/1ps
`ifndef CD_GLOBAL_REQ_DST_MASKS_V
`define CD_GLOBAL_REQ_DST_MASKS_V

module cd_global_req_dst_masks
#(
  parameter DATA_W = 64,
  parameter HXO = 55, parameter HXW = 4,
  parameter HYO = 51, parameter HYW = 4,
  // Four LLC proxy coords:
  parameter LX0 = 0, parameter LY0 = 0,
  parameter LX1 = 3, parameter LY1 = 0,
  parameter LX2 = 0, parameter LY2 = 3,
  parameter LX3 = 3, parameter LY3 = 3
)
(
  // Eight converged request inputs (d0..d7)
  input  wire [DATA_W-1:0] d0,
  input  wire [DATA_W-1:0] d1,
  input  wire [DATA_W-1:0] d2,
  input  wire [DATA_W-1:0] d3,
  input  wire [DATA_W-1:0] d4,
  input  wire [DATA_W-1:0] d5,
  input  wire [DATA_W-1:0] d6,
  input  wire [DATA_W-1:0] d7,
  // One-hot masks: which inputs target LLCk (bit i corresponds to di)
  output wire [7:0]        dst_o0,
  output wire [7:0]        dst_o1,
  output wire [7:0]        dst_o2,
  output wire [7:0]        dst_o3
);

  // Extract Hx/Hy for all eight
  wire [HXW-1:0] hx0 = d0[HXO -: HXW];  wire [HYW-1:0] hy0 = d0[HYO -: HYW];
  wire [HXW-1:0] hx1 = d1[HXO -: HXW];  wire [HYW-1:0] hy1 = d1[HYO -: HYW];
  wire [HXW-1:0] hx2 = d2[HXO -: HXW];  wire [HYW-1:0] hy2 = d2[HYO -: HYW];
  wire [HXW-1:0] hx3 = d3[HXO -: HXW];  wire [HYW-1:0] hy3 = d3[HYO -: HYW];
  wire [HXW-1:0] hx4 = d4[HXO -: HXW];  wire [HYW-1:0] hy4 = d4[HYO -: HYW];
  wire [HXW-1:0] hx5 = d5[HXO -: HXW];  wire [HYW-1:0] hy5 = d5[HYO -: HYW];
  wire [HXW-1:0] hx6 = d6[HXO -: HXW];  wire [HYW-1:0] hy6 = d6[HYO -: HYW];
  wire [HXW-1:0] hx7 = d7[HXO -: HXW];  wire [HYW-1:0] hy7 = d7[HYO -: HYW];

  // Equals LLCk?
  wire e0_0 = (hx0==LX0[HXW-1:0]) & (hy0==LY0[HYW-1:0]);
  wire e0_1 = (hx1==LX0[HXW-1:0]) & (hy1==LY0[HYW-1:0]);
  wire e0_2 = (hx2==LX0[HXW-1:0]) & (hy2==LY0[HYW-1:0]);
  wire e0_3 = (hx3==LX0[HXW-1:0]) & (hy3==LY0[HYW-1:0]);
  wire e0_4 = (hx4==LX0[HXW-1:0]) & (hy4==LY0[HYW-1:0]);
  wire e0_5 = (hx5==LX0[HXW-1:0]) & (hy5==LY0[HYW-1:0]);
  wire e0_6 = (hx6==LX0[HXW-1:0]) & (hy6==LY0[HYW-1:0]);
  wire e0_7 = (hx7==LX0[HXW-1:0]) & (hy7==LY0[HYW-1:0]);

  wire e1_0 = (hx0==LX1[HXW-1:0]) & (hy0==LY1[HYW-1:0]);
  wire e1_1 = (hx1==LX1[HXW-1:0]) & (hy1==LY1[HYW-1:0]);
  wire e1_2 = (hx2==LX1[HXW-1:0]) & (hy2==LY1[HYW-1:0]);
  wire e1_3 = (hx3==LX1[HXW-1:0]) & (hy3==LY1[HYW-1:0]);
  wire e1_4 = (hx4==LX1[HXW-1:0]) & (hy4==LY1[HYW-1:0]);
  wire e1_5 = (hx5==LX1[HXW-1:0]) & (hy5==LY1[HYW-1:0]);
  wire e1_6 = (hx6==LX1[HXW-1:0]) & (hy6==LY1[HYW-1:0]);
  wire e1_7 = (hx7==LX1[HXW-1:0]) & (hy7==LY1[HYW-1:0]);

  wire e2_0 = (hx0==LX2[HXW-1:0]) & (hy0==LY2[HYW-1:0]);
  wire e2_1 = (hx1==LX2[HXW-1:0]) & (hy1==LY2[HYW-1:0]);
  wire e2_2 = (hx2==LX2[HXW-1:0]) & (hy2==LY2[HYW-1:0]);
  wire e2_3 = (hx3==LX2[HXW-1:0]) & (hy3==LY2[HYW-1:0]);
  wire e2_4 = (hx4==LX2[HXW-1:0]) & (hy4==LY2[HYW-1:0]);
  wire e2_5 = (hx5==LX2[HXW-1:0]) & (hy5==LY2[HYW-1:0]);
  wire e2_6 = (hx6==LX2[HXW-1:0]) & (hy6==LY2[HYW-1:0]);
  wire e2_7 = (hx7==LX2[HXW-1:0]) & (hy7==LY2[HYW-1:0]);

  wire e3_0 = (hx0==LX3[HXW-1:0]) & (hy0==LY3[HYW-1:0]);
  wire e3_1 = (hx1==LX3[HXW-1:0]) & (hy1==LY3[HYW-1:0]);
  wire e3_2 = (hx2==LX3[HXW-1:0]) & (hy2==LY3[HYW-1:0]);
  wire e3_3 = (hx3==LX3[HXW-1:0]) & (hy3==LY3[HYW-1:0]);
  wire e3_4 = (hx4==LX3[HXW-1:0]) & (hy4==LY3[HYW-1:0]);
  wire e3_5 = (hx5==LX3[HXW-1:0]) & (hy5==LY3[HYW-1:0]);
  wire e3_6 = (hx6==LX3[HXW-1:0]) & (hy6==LY3[HYW-1:0]);
  wire e3_7 = (hx7==LX3[HXW-1:0]) & (hy7==LY3[HYW-1:0]);

  assign dst_o0 = { e0_7, e0_6, e0_5, e0_4, e0_3, e0_2, e0_1, e0_0 };
  assign dst_o1 = { e1_7, e1_6, e1_5, e1_4, e1_3, e1_2, e1_1, e1_0 };
  assign dst_o2 = { e2_7, e2_6, e2_5, e2_4, e2_3, e2_2, e2_1, e2_0 };
  assign dst_o3 = { e3_7, e3_6, e3_5, e3_4, e3_3, e3_2, e3_1, e3_0 };

endmodule
`endif
