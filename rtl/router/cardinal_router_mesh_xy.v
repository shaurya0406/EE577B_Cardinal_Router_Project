// cardinal_router_mesh_xy.v
`timescale 1ns/1ps
module cardinal_router_mesh_xy (
  input  wire        clk,
  input  wire        reset,

  // External I/O (shared across both VCs, time-multiplexed by phase)
  // Inputs from neighbors/PE
  input  wire        n_si,  input  wire [63:0] n_di,  output wire n_ri,
  input  wire        s_si,  input  wire [63:0] s_di,  output wire s_ri,
  input  wire        e_si,  input  wire [63:0] e_di,  output wire e_ri,
  input  wire        w_si,  input  wire [63:0] w_di,  output wire w_ri,
  input  wire        pe_si, input  wire [63:0] pe_di, output wire pe_ri,
  // Outputs to neighbors/PE
  output wire        n_so,  output wire [63:0] n_do,  input  wire n_ro,
  output wire        s_so,  output wire [63:0] s_do,  input  wire s_ro,
  output wire        e_so,  output wire [63:0] e_do,  input  wire e_ro,
  output wire        w_so,  output wire [63:0] w_do,  input  wire w_ro,
  output wire        pe_so, output wire [63:0] pe_do, input  wire pe_ro,

  // Polarity indicator
  output wire        polarity
);
  // Track even/odd
  vc_phase PH (.clk(clk), .reset(reset), .polarity(polarity));

  // VC0 (even): internal on even, external on odd
  wire n_ri_v0, s_ri_v0, e_ri_v0, w_ri_v0, pe_ri_v0;
  wire n_so_v0, s_so_v0, e_so_v0, w_so_v0, pe_so_v0;
  wire [63:0] n_do_v0, s_do_v0, e_do_v0, w_do_v0, pe_do_v0;

  router_vc_block VC0 (
    .clk(clk), .reset(reset),
    .phase_internal(~polarity), .phase_external(polarity),
    .n_si(n_si), .n_ri(n_ri_v0), .n_di(n_di),
    .s_si(s_si), .s_ri(s_ri_v0), .s_di(s_di),
    .e_si(e_si), .e_ri(e_ri_v0), .e_di(e_di),
    .w_si(w_si), .w_ri(w_ri_v0), .w_di(w_di),
    .pe_si(pe_si), .pe_ri(pe_ri_v0), .pe_di(pe_di),
    .n_so(n_so_v0), .n_ro(n_ro), .n_do(n_do_v0),
    .s_so(s_so_v0), .s_ro(s_ro), .s_do(s_do_v0),
    .e_so(e_so_v0), .e_ro(e_ro), .e_do(e_do_v0),
    .w_so(w_so_v0), .w_ro(w_ro), .w_do(w_do_v0),
    .pe_so(pe_so_v0), .pe_ro(pe_ro), .pe_do(pe_do_v0)
  );

  // VC1 (odd): internal on odd, external on even
  wire n_ri_v1, s_ri_v1, e_ri_v1, w_ri_v1, pe_ri_v1;
  wire n_so_v1, s_so_v1, e_so_v1, w_so_v1, pe_so_v1;
  wire [63:0] n_do_v1, s_do_v1, e_do_v1, w_do_v1, pe_do_v1;

  router_vc_block VC1 (
    .clk(clk), .reset(reset),
    .phase_internal(polarity), .phase_external(~polarity),
    .n_si(n_si), .n_ri(n_ri_v1), .n_di(n_di),
    .s_si(s_si), .s_ri(s_ri_v1), .s_di(s_di),
    .e_si(e_si), .e_ri(e_ri_v1), .e_di(e_di),
    .w_si(w_si), .w_ri(w_ri_v1), .w_di(w_di),
    .pe_si(pe_si), .pe_ri(pe_ri_v1), .pe_di(pe_di),
    .n_so(n_so_v1), .n_ro(n_ro), .n_do(n_do_v1),
    .s_so(s_so_v1), .s_ro(s_ro), .s_do(s_do_v1),
    .e_so(e_so_v1), .e_ro(e_ro), .e_do(e_do_v1),
    .w_so(w_so_v1), .w_ro(w_ro), .w_do(w_do_v1),
    .pe_so(pe_so_v1), .pe_ro(pe_ro), .pe_do(pe_do_v1)
  );

  // External multiplexing by current external VC (opposite of 'phase_internal' of that VC):
  // On even cycles (polarity=0): external = VC1, so expose VC1.so/do/ri
  // On odd  cycles (polarity=1): external = VC0, so expose VC0.so/do/ri
  assign n_so = (polarity==1'b0) ? n_so_v1 : n_so_v0;
  assign s_so = (polarity==1'b0) ? s_so_v1 : s_so_v0;
  assign e_so = (polarity==1'b0) ? e_so_v1 : e_so_v0;
  assign w_so = (polarity==1'b0) ? w_so_v1 : w_so_v0;
  assign pe_so= (polarity==1'b0) ? pe_so_v1: pe_so_v0;

  assign n_do = (polarity==1'b0) ? n_do_v1 : n_do_v0;
  assign s_do = (polarity==1'b0) ? s_do_v1 : s_do_v0;
  assign e_do = (polarity==1'b0) ? e_do_v1 : e_do_v0;
  assign w_do = (polarity==1'b0) ? w_do_v1 : w_do_v0;
  assign pe_do= (polarity==1'b0) ? pe_do_v1: pe_do_v0;

  assign n_ri = (polarity==1'b0) ? n_ri_v1 : n_ri_v0;
  assign s_ri = (polarity==1'b0) ? s_ri_v1 : s_ri_v0;
  assign e_ri = (polarity==1'b0) ? e_ri_v1 : e_ri_v0;
  assign w_ri = (polarity==1'b0) ? w_ri_v1 : w_ri_v0;
  assign pe_ri= (polarity==1'b0) ? pe_ri_v1: pe_ri_v0;
endmodule
