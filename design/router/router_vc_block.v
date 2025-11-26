// router_vc_block.v
// Per-VC plane: 5 inputs (N,S,E,W,PE) -> 5 outputs (N,S,E,W,PE)
`timescale 1ns/1ps

module router_vc_block (
  input  wire        clk,
  input  wire        reset,

  // Phase control for THIS VC only
  input  wire        phase_internal,  // 1 when this VC is in internal (forward) phase
  input  wire        phase_external,  // 1 when this VC is in external (link) phase

  // ==== INPUT LINKS (from neighbors/PE into this router) ====
  // North input
  input  wire        n_si,
  output wire        n_ri,
  input  wire [63:0] n_di,
  // South input
  input  wire        s_si,
  output wire        s_ri,
  input  wire [63:0] s_di,
  // East input
  input  wire        e_si,
  output wire        e_ri,
  input  wire [63:0] e_di,
  // West input
  input  wire        w_si,
  output wire        w_ri,
  input  wire [63:0] w_di,
  // PE input
  input  wire        pe_si,
  output wire        pe_ri,
  input  wire [63:0] pe_di,

  // ==== OUTPUT LINKS (from this router to neighbors/PE) ====
  // North output
  output wire        n_so,
  input  wire        n_ro,
  output wire [63:0] n_do,
  // South output
  output wire        s_so,
  input  wire        s_ro,
  output wire [63:0] s_do,
  // East output
  output wire        e_so,
  input  wire        e_ro,
  output wire [63:0] e_do,
  // West output
  output wire        w_so,
  input  wire        w_ro,
  output wire [63:0] w_do,
  // PE output
  output wire        pe_so,
  input  wire        pe_ro,
  output wire [63:0] pe_do
);

  // -------------------------
  // Input VC buffers (5x)
  // -------------------------
  wire        n_full, s_full, e_full, w_full, pe_full;
  wire [63:0] n_q,    s_q,    e_q,    w_q,    pe_q;

  wire        deq_n, deq_s, deq_e, deq_w, deq_pe;

  inbuf_cell IN_N (
    .clk(clk), .reset(reset),
    .si(n_si), .ri(n_ri), .di(n_di),
    .phase_external(phase_external),
    .phase_internal(phase_internal),
    .deq(deq_n),
    .full(n_full), .q(n_q)
  );

  inbuf_cell IN_S (
    .clk(clk), .reset(reset),
    .si(s_si), .ri(s_ri), .di(s_di),
    .phase_external(phase_external),
    .phase_internal(phase_internal),
    .deq(deq_s),
    .full(s_full), .q(s_q)
  );

  inbuf_cell IN_E (
    .clk(clk), .reset(reset),
    .si(e_si), .ri(e_ri), .di(e_di),
    .phase_external(phase_external),
    .phase_internal(phase_internal),
    .deq(deq_e),
    .full(e_full), .q(e_q)
  );

  inbuf_cell IN_W (
    .clk(clk), .reset(reset),
    .si(w_si), .ri(w_ri), .di(w_di),
    .phase_external(phase_external),
    .phase_internal(phase_internal),
    .deq(deq_w),
    .full(w_full), .q(w_q)
  );

  inbuf_cell IN_PE (
    .clk(clk), .reset(reset),
    .si(pe_si), .ri(pe_ri), .di(pe_di),
    .phase_external(phase_external),
    .phase_internal(phase_internal),
    .deq(deq_pe),
    .full(pe_full), .q(pe_q)
  );

  // -------------------------
  // Request matrix (combinational)
  // -------------------------
  wire [4:0] req_to_n, req_to_s, req_to_e, req_to_w, req_to_pe;
  wire [63:0] n_pkt_next, s_pkt_next, e_pkt_next, w_pkt_next, pe_pkt_next;

  req_matrix RM (
    .n_full(n_full), .n_q(n_q),
    .s_full(s_full), .s_q(s_q),
    .e_full(e_full), .e_q(e_q),
    .w_full(w_full), .w_q(w_q),
    .pe_full(pe_full), .pe_q(pe_q),
    .req_to_n(req_to_n), .req_to_s(req_to_s), .req_to_e(req_to_e), .req_to_w(req_to_w), .req_to_pe(req_to_pe),
    .n_pkt_next(n_pkt_next), .s_pkt_next(s_pkt_next), .e_pkt_next(e_pkt_next), .w_pkt_next(w_pkt_next), .pe_pkt_next(pe_pkt_next)
  );

  // -------------------------
  // Output VC buffers (5x)
  // -------------------------
  wire outbuf_full_n, outbuf_full_s, outbuf_full_e, outbuf_full_w, outbuf_full_pe;

  // These get enq_* and d_in_* from xbar
  wire        enq_n, enq_s, enq_e, enq_w, enq_pe;
  wire [63:0] d_in_n, d_in_s, d_in_e, d_in_w, d_in_pe;

  // Add local taps for debug/clean connectivity
  wire [63:0] n_q_ob, s_q_ob, e_q_ob, w_q_ob, pe_q_ob;

  outbuf_cell OUT_N (
    .clk(clk), .reset(reset),
    .enq(enq_n), .d_in(d_in_n), .phase_internal(phase_internal),
    .so(n_so), .ro(n_ro), .dout(n_do), .phase_external(phase_external),
    .full(outbuf_full_n), .q(n_q_ob)
  );

  outbuf_cell OUT_S (
    .clk(clk), .reset(reset),
    .enq(enq_s), .d_in(d_in_s), .phase_internal(phase_internal),
    .so(s_so), .ro(s_ro), .dout(s_do), .phase_external(phase_external),
    .full(outbuf_full_s), .q(s_q_ob)
  );

  outbuf_cell OUT_E (
    .clk(clk), .reset(reset),
    .enq(enq_e), .d_in(d_in_e), .phase_internal(phase_internal),
    .so(e_so), .ro(e_ro), .dout(e_do), .phase_external(phase_external),
    .full(outbuf_full_e), .q(e_q_ob)
  );

  outbuf_cell OUT_W (
    .clk(clk), .reset(reset),
    .enq(enq_w), .d_in(d_in_w), .phase_internal(phase_internal),
    .so(w_so), .ro(w_ro), .dout(w_do), .phase_external(phase_external),
    .full(outbuf_full_w), .q(w_q_ob)
  );

  outbuf_cell OUT_PE (
    .clk(clk), .reset(reset),
    .enq(enq_pe), .d_in(d_in_pe), .phase_internal(phase_internal),
    .so(pe_so), .ro(pe_ro), .dout(pe_do), .phase_external(phase_external),
    .full(outbuf_full_pe), .q(pe_q_ob)
  );

  // -------------------------
  // Per-output RR arbiters (5x)
  // -------------------------
  wire [4:0] gnt_to_n, gnt_to_s, gnt_to_e, gnt_to_w, gnt_to_pe;

  rr_arb_5 ARB_N (
    .clk(clk), .reset(reset),
    .req(req_to_n),
    .outbuf_full(outbuf_full_n),
    .gnt(gnt_to_n)
  );

  rr_arb_5 ARB_S (
    .clk(clk), .reset(reset),
    .req(req_to_s),
    .outbuf_full(outbuf_full_s),
    .gnt(gnt_to_s)
  );

  rr_arb_5 ARB_E (
    .clk(clk), .reset(reset),
    .req(req_to_e),
    .outbuf_full(outbuf_full_e),
    .gnt(gnt_to_e)
  );

  rr_arb_5 ARB_W (
    .clk(clk), .reset(reset),
    .req(req_to_w),
    .outbuf_full(outbuf_full_w),
    .gnt(gnt_to_w)
  );

  rr_arb_5 ARB_PE (
    .clk(clk), .reset(reset),
    .req(req_to_pe),
    .outbuf_full(outbuf_full_pe),
    .gnt(gnt_to_pe)
  );

  // -------------------------
  // Crossbar / internal forward
  // -------------------------
  xbar_internal XBAR (
    .clk(clk), .reset(reset), .phase_internal(phase_internal),

    .n_full(n_full), .n_q(n_q), .n_pkt_next(n_pkt_next),
    .s_full(s_full), .s_q(s_q), .s_pkt_next(s_pkt_next),
    .e_full(e_full), .e_q(e_q), .e_pkt_next(e_pkt_next),
    .w_full(w_full), .w_q(w_q), .w_pkt_next(w_pkt_next),
    .pe_full(pe_full), .pe_q(pe_q), .pe_pkt_next(pe_pkt_next),

    .gnt_to_n(gnt_to_n),
    .gnt_to_s(gnt_to_s),
    .gnt_to_e(gnt_to_e),
    .gnt_to_w(gnt_to_w),
    .gnt_to_pe(gnt_to_pe),

    .outbuf_full_n(outbuf_full_n),
    .outbuf_full_s(outbuf_full_s),
    .outbuf_full_e(outbuf_full_e),
    .outbuf_full_w(outbuf_full_w),
    .outbuf_full_pe(outbuf_full_pe),

    .enq_n(enq_n),   .d_in_n(d_in_n),
    .enq_s(enq_s),   .d_in_s(d_in_s),
    .enq_e(enq_e),   .d_in_e(d_in_e),
    .enq_w(enq_w),   .d_in_w(d_in_w),
    .enq_pe(enq_pe), .d_in_pe(d_in_pe),

    .deq_n(deq_n), .deq_s(deq_s), .deq_e(deq_e), .deq_w(deq_w), .deq_pe(deq_pe)
  );

endmodule
