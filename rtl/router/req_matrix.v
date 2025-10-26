// req_matrix.v
`timescale 1ns/1ps
module req_matrix (
  // Five input buffers (from inbuf_cell), per VC
  input  wire        n_full,
  input  wire [63:0] n_q,
  input  wire        s_full,
  input  wire [63:0] s_q,
  input  wire        e_full,
  input  wire [63:0] e_q,
  input  wire        w_full,
  input  wire [63:0] w_q,
  input  wire        pe_full,
  input  wire [63:0] pe_q,

  // Requests per OUTPUT (each 5-bit vector from inputs {N,S,E,W,PE} -> bits {4,3,2,1,0})
  output wire [4:0]  req_to_n,
  output wire [4:0]  req_to_s,
  output wire [4:0]  req_to_e,
  output wire [4:0]  req_to_w,
  output wire [4:0]  req_to_pe,

  // Per-INPUT next packet after one-dimension hop update
  output wire [63:0] n_pkt_next,
  output wire [63:0] s_pkt_next,
  output wire [63:0] e_pkt_next,
  output wire [63:0] w_pkt_next,
  output wire [63:0] pe_pkt_next
);

  // ---------- Helper: decode + route for one input ----------
  // Make a small macro-like block as an inline section (copy 5x).

  // N input
  wire n_vc, n_dx, n_dy; wire [4:0] n_rsv; wire [3:0] n_hx, n_hy; wire [7:0] n_srcx, n_srcy;
  hdr_fields n_hdr (.pkt(n_q), .vc(n_vc), .dx(n_dx), .dy(n_dy), .rsv(n_rsv), .hx(n_hx), .hy(n_hy), .srcx(n_srcx), .srcy(n_srcy));
  wire n_req_n, n_req_s, n_req_e, n_req_w, n_req_pe, n_shift_x, n_shift_y; wire [3:0] n_hx_next, n_hy_next;
  route_xy n_xy (.dx(n_dx), .dy(n_dy), .hx(n_hx), .hy(n_hy),
                 .req_n(n_req_n), .req_s(n_req_s), .req_e(n_req_e), .req_w(n_req_w), .req_pe(n_req_pe),
                 .shift_x(n_shift_x), .shift_y(n_shift_y), .hx_next(n_hx_next), .hy_next(n_hy_next));
  // build next packet for N (only Hx/Hy bits change; preserve reserved and all others)
  assign n_pkt_next = { n_vc, n_dx, n_dy, n_rsv, n_hx_next, n_hy_next, n_srcx, n_srcy, n_q[31:0] };

  // S input
  wire s_vc, s_dx, s_dy; wire [4:0] s_rsv; wire [3:0] s_hx, s_hy; wire [7:0] s_srcx, s_srcy;
  hdr_fields s_hdr (.pkt(s_q), .vc(s_vc), .dx(s_dx), .dy(s_dy), .rsv(s_rsv), .hx(s_hx), .hy(s_hy), .srcx(s_srcx), .srcy(s_srcy));
  wire s_req_n, s_req_s, s_req_e, s_req_w, s_req_pe, s_shift_x, s_shift_y; wire [3:0] s_hx_next, s_hy_next;
  route_xy s_xy (.dx(s_dx), .dy(s_dy), .hx(s_hx), .hy(s_hy),
                 .req_n(s_req_n), .req_s(s_req_s), .req_e(s_req_e), .req_w(s_req_w), .req_pe(s_req_pe),
                 .shift_x(s_shift_x), .shift_y(s_shift_y), .hx_next(s_hx_next), .hy_next(s_hy_next));
  assign s_pkt_next = { s_vc, s_dx, s_dy, s_rsv, s_hx_next, s_hy_next, s_srcx, s_srcy, s_q[31:0] };

  // E input
  wire e_vc, e_dx, e_dy; wire [4:0] e_rsv; wire [3:0] e_hx, e_hy; wire [7:0] e_srcx, e_srcy;
  hdr_fields e_hdr (.pkt(e_q), .vc(e_vc), .dx(e_dx), .dy(e_dy), .rsv(e_rsv), .hx(e_hx), .hy(e_hy), .srcx(e_srcx), .srcy(e_srcy));
  wire e_req_n, e_req_s, e_req_e, e_req_w, e_req_pe, e_shift_x, e_shift_y; wire [3:0] e_hx_next, e_hy_next;
  route_xy e_xy (.dx(e_dx), .dy(e_dy), .hx(e_hx), .hy(e_hy),
                 .req_n(e_req_n), .req_s(e_req_s), .req_e(e_req_e), .req_w(e_req_w), .req_pe(e_req_pe),
                 .shift_x(e_shift_x), .shift_y(e_shift_y), .hx_next(e_hx_next), .hy_next(e_hy_next));
  assign e_pkt_next = { e_vc, e_dx, e_dy, e_rsv, e_hx_next, e_hy_next, e_srcx, e_srcy, e_q[31:0] };

  // W input
  wire w_vc, w_dx, w_dy; wire [4:0] w_rsv; wire [3:0] w_hx, w_hy; wire [7:0] w_srcx, w_srcy;
  hdr_fields w_hdr (.pkt(w_q), .vc(w_vc), .dx(w_dx), .dy(w_dy), .rsv(w_rsv), .hx(w_hx), .hy(w_hy), .srcx(w_srcx), .srcy(w_srcy));
  wire w_req_n, w_req_s, w_req_e, w_req_w, w_req_pe, w_shift_x, w_shift_y; wire [3:0] w_hx_next, w_hy_next;
  route_xy w_xy (.dx(w_dx), .dy(w_dy), .hx(w_hx), .hy(w_hy),
                 .req_n(w_req_n), .req_s(w_req_s), .req_e(w_req_e), .req_w(w_req_w), .req_pe(w_req_pe),
                 .shift_x(w_shift_x), .shift_y(w_shift_y), .hx_next(w_hx_next), .hy_next(w_hy_next));
  assign w_pkt_next = { w_vc, w_dx, w_dy, w_rsv, w_hx_next, w_hy_next, w_srcx, w_srcy, w_q[31:0] };

  // PE input
  wire pe_vc, pe_dx, pe_dy; wire [4:0] pe_rsv; wire [3:0] pe_hx, pe_hy; wire [7:0] pe_srcx, pe_srcy;
  hdr_fields pe_hdr (.pkt(pe_q), .vc(pe_vc), .dx(pe_dx), .dy(pe_dy), .rsv(pe_rsv), .hx(pe_hx), .hy(pe_hy), .srcx(pe_srcx), .srcy(pe_srcy));
  wire pe_req_n, pe_req_s, pe_req_e, pe_req_w, pe_req_pe, pe_shift_x, pe_shift_y; wire [3:0] pe_hx_next, pe_hy_next;
  route_xy pe_xy (.dx(pe_dx), .dy(pe_dy), .hx(pe_hx), .hy(pe_hy),
                 .req_n(pe_req_n), .req_s(pe_req_s), .req_e(pe_req_e), .req_w(pe_req_w), .req_pe(pe_req_pe),
                 .shift_x(pe_shift_x), .shift_y(pe_shift_y), .hx_next(pe_hx_next), .hy_next(pe_hy_next));
  assign pe_pkt_next = { pe_vc, pe_dx, pe_dy, pe_rsv, pe_hx_next, pe_hy_next, pe_srcx, pe_srcy, pe_q[31:0] };

  // ---------- Gate requests by input-full ----------
  assign req_to_n  = { (n_full & n_req_n), (s_full & s_req_n), (e_full & e_req_n), (w_full & w_req_n), (pe_full & pe_req_n) };
  assign req_to_s  = { (n_full & n_req_s), (s_full & s_req_s), (e_full & e_req_s), (w_full & w_req_s), (pe_full & pe_req_s) };
  assign req_to_e  = { (n_full & n_req_e), (s_full & s_req_e), (e_full & e_req_e), (w_full & w_req_e), (pe_full & pe_req_e) };
  assign req_to_w  = { (n_full & n_req_w), (s_full & s_req_w), (e_full & e_req_w), (w_full & w_req_w), (pe_full & pe_req_w) };
  assign req_to_pe = { (n_full & n_req_pe),(s_full & s_req_pe),(e_full & e_req_pe),(w_full & w_req_pe),(pe_full & pe_req_pe) };

endmodule
