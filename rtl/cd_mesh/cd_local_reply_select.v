//======================================================================
// cd_local_reply_select.v
// - For a LOCAL (2→4) reply path, compute one-hot selects per converged input.
// - No integers, no loops. Pure combinational.
// - Defaults match hdr_fields: Hx[55:52], Hy[51:48].
//======================================================================
`timescale 1ns/1ps
`ifndef CD_LOCAL_REPLY_SELECT_V
`define CD_LOCAL_REPLY_SELECT_V

module cd_local_reply_select
#(
  parameter DATA_W = 64,
  // Header field locations (defaults: Hx[55:52], Hy[51:48])
  parameter HXO = 55, parameter HXW = 4,
  parameter HYO = 51, parameter HYW = 4,
  // Router coords inside this quadrant (tile addresses)
  parameter RX0 = 0, parameter RY0 = 0,
  parameter RX1 = 1, parameter RY1 = 0,
  parameter RX2 = 0, parameter RY2 = 1,
  parameter RX3 = 1, parameter RY3 = 1
)
(
  // Two converged reply inputs (from global_xbar)
  input  wire [DATA_W-1:0] cv0_di,
  input  wire [DATA_W-1:0] cv1_di,
  // One-hot selects to LOCAL xbar (which router gets cv0/cv1)
  output wire [3:0]        sel_cv0,
  output wire [3:0]        sel_cv1
);

  // ---- Extract Hx/Hy for cv0
  wire [HXW-1:0] cv0_hx = cv0_di[HXO -: HXW];
  wire [HYW-1:0] cv0_hy = cv0_di[HYO -: HYW];

  // ---- Equality comparators to quadrant routers
  wire cv0_eq0 = (cv0_hx == RX0[HXW-1:0]) & (cv0_hy == RY0[HYW-1:0]);
  wire cv0_eq1 = (cv0_hx == RX1[HXW-1:0]) & (cv0_hy == RY1[HYW-1:0]);
  wire cv0_eq2 = (cv0_hx == RX2[HXW-1:0]) & (cv0_hy == RY2[HYW-1:0]);
  wire cv0_eq3 = (cv0_hx == RX3[HXW-1:0]) & (cv0_hy == RY3[HYW-1:0]);

  assign sel_cv0 = { cv0_eq3, cv0_eq2, cv0_eq1, cv0_eq0 };

  // ---- Repeat for cv1
  wire [HXW-1:0] cv1_hx = cv1_di[HXO -: HXW];
  wire [HYW-1:0] cv1_hy = cv1_di[HYO -: HYW];

  wire cv1_eq0 = (cv1_hx == RX0[HXW-1:0]) & (cv1_hy == RY0[HYW-1:0]);
  wire cv1_eq1 = (cv1_hx == RX1[HXW-1:0]) & (cv1_hy == RY1[HYW-1:0]);
  wire cv1_eq2 = (cv1_hx == RX2[HXW-1:0]) & (cv1_hy == RY2[HYW-1:0]);
  wire cv1_eq3 = (cv1_hx == RX3[HXW-1:0]) & (cv1_hy == RY3[HYW-1:0]);

  assign sel_cv1 = { cv1_eq3, cv1_eq2, cv1_eq1, cv1_eq0 };

endmodule
`endif
