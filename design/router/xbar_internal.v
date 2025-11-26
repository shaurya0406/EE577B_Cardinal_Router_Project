// xbar_internal.v
`timescale 1ns/1ps
module xbar_internal (
  input  wire        clk,
  input  wire        reset,
  input  wire        phase_internal, // 1 when this VC is in internal phase

  // Input buffers (state) and next packets from req_matrix
  input  wire        n_full,
  input  wire [63:0] n_q,
  input  wire [63:0] n_pkt_next,

  input  wire        s_full,
  input  wire [63:0] s_q,
  input  wire [63:0] s_pkt_next,

  input  wire        e_full,
  input  wire [63:0] e_q,
  input  wire [63:0] e_pkt_next,

  input  wire        w_full,
  input  wire [63:0] w_q,
  input  wire [63:0] w_pkt_next,

  input  wire        pe_full,
  input  wire [63:0] pe_q,
  input  wire [63:0] pe_pkt_next,

  // Per-output grants from 5-way arbiters (one-hot among inputs [N,S,E,W,PE] = [4,3,2,1,0])
  input  wire [4:0]  gnt_to_n,
  input  wire [4:0]  gnt_to_s,
  input  wire [4:0]  gnt_to_e,
  input  wire [4:0]  gnt_to_w,
  input  wire [4:0]  gnt_to_pe,

  // Each output's outbuf full indicator (block enqueue)
  input  wire        outbuf_full_n,
  input  wire        outbuf_full_s,
  input  wire        outbuf_full_e,
  input  wire        outbuf_full_w,
  input  wire        outbuf_full_pe,

  // Enqueue controls to outbuf_cell (one per output)
  output wire        enq_n,
  output wire [63:0] d_in_n,
  output wire        enq_s,
  output wire [63:0] d_in_s,
  output wire        enq_e,
  output wire [63:0] d_in_e,
  output wire        enq_w,
  output wire [63:0] d_in_w,
  output wire        enq_pe,
  output wire [63:0] d_in_pe,

  // Dequeue controls to inbuf_cell (one per input)
  output wire        deq_n,
  output wire        deq_s,
  output wire        deq_e,
  output wire        deq_w,
  output wire        deq_pe
);

  // ---------------- Mux helpers per output ----------------
  // Given a grant vector, pick the winning input's next packet.
  // Order: [4]=N, [3]=S, [2]=E, [1]=W, [0]=PE.

  // N output
  wire [63:0] mux_n_din =
      (gnt_to_n[4] ? n_pkt_next :
      (gnt_to_n[3] ? s_pkt_next :
      (gnt_to_n[2] ? e_pkt_next :
      (gnt_to_n[1] ? w_pkt_next :
      (gnt_to_n[0] ? pe_pkt_next : 64'b0)))));

  // S output
  wire [63:0] mux_s_din =
      (gnt_to_s[4] ? n_pkt_next :
      (gnt_to_s[3] ? s_pkt_next :
      (gnt_to_s[2] ? e_pkt_next :
      (gnt_to_s[1] ? w_pkt_next :
      (gnt_to_s[0] ? pe_pkt_next : 64'b0)))));

  // E output
  wire [63:0] mux_e_din =
      (gnt_to_e[4] ? n_pkt_next :
      (gnt_to_e[3] ? s_pkt_next :
      (gnt_to_e[2] ? e_pkt_next :
      (gnt_to_e[1] ? w_pkt_next :
      (gnt_to_e[0] ? pe_pkt_next : 64'b0)))));

  // W output
  wire [63:0] mux_w_din =
      (gnt_to_w[4] ? n_pkt_next :
      (gnt_to_w[3] ? s_pkt_next :
      (gnt_to_w[2] ? e_pkt_next :
      (gnt_to_w[1] ? w_pkt_next :
      (gnt_to_w[0] ? pe_pkt_next : 64'b0)))));

  // PE output
  wire [63:0] mux_pe_din =
      (gnt_to_pe[4] ? n_pkt_next :
      (gnt_to_pe[3] ? s_pkt_next :
      (gnt_to_pe[2] ? e_pkt_next :
      (gnt_to_pe[1] ? w_pkt_next :
      (gnt_to_pe[0] ? pe_pkt_next : 64'b0)))));

  // ---------------- Enqueue enables (phase + outbuf not full + some grant) ----------------
  assign enq_n  = phase_internal & (~outbuf_full_n)  & (|gnt_to_n);
  assign enq_s  = phase_internal & (~outbuf_full_s)  & (|gnt_to_s);
  assign enq_e  = phase_internal & (~outbuf_full_e)  & (|gnt_to_e);
  assign enq_w  = phase_internal & (~outbuf_full_w)  & (|gnt_to_w);
  assign enq_pe = phase_internal & (~outbuf_full_pe) & (|gnt_to_pe);

  assign d_in_n  = mux_n_din;
  assign d_in_s  = mux_s_din;
  assign d_in_e  = mux_e_din;
  assign d_in_w  = mux_w_din;
  assign d_in_pe = mux_pe_din;

  // ---------------- Dequeue per input: OR of grants to any output ----------------
  // Only during internal phase and only when that output is actually enqueuing (not full).
  assign deq_n  = phase_internal & (
                    (gnt_to_n[4]  & ~outbuf_full_n)  |
                    (gnt_to_s[4]  & ~outbuf_full_s)  |
                    (gnt_to_e[4]  & ~outbuf_full_e)  |
                    (gnt_to_w[4]  & ~outbuf_full_w)  |
                    (gnt_to_pe[4] & ~outbuf_full_pe) );

  assign deq_s  = phase_internal & (
                    (gnt_to_n[3]  & ~outbuf_full_n)  |
                    (gnt_to_s[3]  & ~outbuf_full_s)  |
                    (gnt_to_e[3]  & ~outbuf_full_e)  |
                    (gnt_to_w[3]  & ~outbuf_full_w)  |
                    (gnt_to_pe[3] & ~outbuf_full_pe) );

  assign deq_e  = phase_internal & (
                    (gnt_to_n[2]  & ~outbuf_full_n)  |
                    (gnt_to_s[2]  & ~outbuf_full_s)  |
                    (gnt_to_e[2]  & ~outbuf_full_e)  |
                    (gnt_to_w[2]  & ~outbuf_full_w)  |
                    (gnt_to_pe[2] & ~outbuf_full_pe) );

  assign deq_w  = phase_internal & (
                    (gnt_to_n[1]  & ~outbuf_full_n)  |
                    (gnt_to_s[1]  & ~outbuf_full_s)  |
                    (gnt_to_e[1]  & ~outbuf_full_e)  |
                    (gnt_to_w[1]  & ~outbuf_full_w)  |
                    (gnt_to_pe[1] & ~outbuf_full_pe) );

  assign deq_pe = phase_internal & (
                    (gnt_to_n[0]  & ~outbuf_full_n)  |
                    (gnt_to_s[0]  & ~outbuf_full_s)  |
                    (gnt_to_e[0]  & ~outbuf_full_e)  |
                    (gnt_to_w[0]  & ~outbuf_full_w)  |
                    (gnt_to_pe[0] & ~outbuf_full_pe) );

endmodule
