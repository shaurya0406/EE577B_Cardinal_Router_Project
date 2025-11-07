// hdr_fields.v
module hdr_fields (
  input  wire [63:0] pkt,
  output wire        vc,
  output wire        dx,
  output wire        dy,
  output wire [4:0]  rsv,
  output wire [3:0]  hx,
  output wire [3:0]  hy,
  output wire [7:0]  srcx,
  output wire [7:0]  srcy
);
  // Bit map (63..32): VC[63], Dx[62], Dy[61], Rsv[60:56], Hx[55:52], Hy[51:48], SrcX[47:40], SrcY[39:32]
  assign vc   = pkt[63];
  assign dx   = pkt[62];
  assign dy   = pkt[61];
  assign rsv  = pkt[60:56];
  assign hx   = pkt[55:52];
  assign hy   = pkt[51:48];
  assign srcx = pkt[47:40];
  assign srcy = pkt[39:32];
endmodule


// inbuf_cell.v
module inbuf_cell (
  input  wire        clk,
  input  wire        reset,           // active-high synchronous
  // Link from neighbor (to us)
  input  wire        si,
  output wire        ri,
  input  wire [63:0] di,
  // Phase controls for THIS VC
  input  wire        phase_external,  // 1 when this VC is in external (link) phase
  input  wire        phase_internal,  // 1 when this VC is in internal (forward) phase
  // Router control to pop on internal forward
  input  wire        deq,
  // Buffer state
  output reg         full,
  output reg  [63:0] q
);
  assign ri = phase_external & ~full;

  always @(posedge clk) begin
    if (reset) begin
      full <= 1'b0;
      q    <= 64'b0;
    end else begin
      // Receive from link
      if (si & ri) begin
        q    <= di;
        full <= 1'b1;
      end
      // Dequeue on internal phase
      if (phase_internal & deq) begin
        full <= 1'b0;
      end
    end
  end
endmodule

`timescale 1ns/1ps
module outbuf_cell (
  input  wire        clk,
  input  wire        reset,
  // Enqueue from internal crossbar (internal phase only)
  input  wire        enq,
  input  wire [63:0] d_in,
  input  wire        phase_internal,
  // Link to neighbor (external phase only)
  output wire        so,
  input  wire        ro,
  output wire [63:0] dout,
  input  wire        phase_external,
  // State
  output reg         full,
  output reg  [63:0] q
);
  // Link valid only when a real transfer will occur
  assign so   = phase_external & full & ro;
  assign dout = so ? q : 64'b0;

  always @(posedge clk) begin
    if (reset) begin
      full <= 1'b0;
      q    <= 64'b0;
    end else begin
      // Accept from crossbar only in internal phase and only if empty
      if (phase_internal & enq & ~full) begin
        q    <= d_in;
        full <= 1'b1;
      end
      // Consume on the external phase handshake
      if (phase_external & full & ro) begin
        full <= 1'b0;
      end
    end
  end
endmodule


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


// route_xy.v
module route_xy (
  input  wire       dx,      // 0=+X(E), 1=-X(W)
  input  wire       dy,      // 0=+Y(N), 1=-Y(S)
  input  wire [3:0] hx,
  input  wire [3:0] hy,
  output wire       req_n,
  output wire       req_s,
  output wire       req_e,
  output wire       req_w,
  output wire       req_pe,
  output wire       shift_x,
  output wire       shift_y,
  output wire [3:0] hx_next,
  output wire [3:0] hy_next
);
  wire hx_zero = (hx==4'b0000);
  wire hy_zero = (hy==4'b0000);

  assign req_e   = (~hx_zero) & (dx==1'b0);
  assign req_w   = (~hx_zero) & (dx==1'b1);
  assign req_n   = ( hx_zero) & (~hy_zero) & (dy==1'b0);
  assign req_s   = ( hx_zero) & (~hy_zero) & (dy==1'b1);
  assign req_pe  = ( hx_zero) & ( hy_zero);

  assign shift_x = (~hx_zero);
  assign shift_y = ( hx_zero) & (~hy_zero);

  assign hx_next = shift_x ? {1'b0, hx[3:1]} : hx;
  assign hy_next = shift_y ? {1'b0, hy[3:1]} : hy;
endmodule




`timescale 1ns/1ps
// rr_arb_5.v — 5-way RR arbiter (combinational grant, registered pointer)
// req/gnt bit order: [4]=N, [3]=S, [2]=E, [1]=W, [0]=PE
module rr_arb_5 (
  input  wire       clk,
  input  wire       reset,        // active-high synchronous
  input  wire [4:0] req,
  input  wire       outbuf_full,  // 1 => block grants
  output wire [4:0] gnt           // combinational one-hot grant
);
  reg  [2:0] ptr;       // 0..4 rotation start (registered)
  reg  [4:0] gnt_c;     // comb grant

  // Combinational grant from current ptr and req (blocked if outbuf full)
  always @* begin
    gnt_c = 5'b00000;
    if (!outbuf_full) begin
      case (ptr)
        3'd0: begin // N,S,E,W,PE
          if (req[4])      gnt_c = 5'b10000;
          else if (req[3]) gnt_c = 5'b01000;
          else if (req[2]) gnt_c = 5'b00100;
          else if (req[1]) gnt_c = 5'b00010;
          else if (req[0]) gnt_c = 5'b00001;
        end
        3'd1: begin // S,E,W,PE,N
          if (req[3])      gnt_c = 5'b01000;
          else if (req[2]) gnt_c = 5'b00100;
          else if (req[1]) gnt_c = 5'b00010;
          else if (req[0]) gnt_c = 5'b00001;
          else if (req[4]) gnt_c = 5'b10000;
        end
        3'd2: begin // E,W,PE,N,S
          if (req[2])      gnt_c = 5'b00100;
          else if (req[1]) gnt_c = 5'b00010;
          else if (req[0]) gnt_c = 5'b00001;
          else if (req[4]) gnt_c = 5'b10000;
          else if (req[3]) gnt_c = 5'b01000;
        end
        3'd3: begin // W,PE,N,S,E
          if (req[1])      gnt_c = 5'b00010;
          else if (req[0]) gnt_c = 5'b00001;
          else if (req[4]) gnt_c = 5'b10000;
          else if (req[3]) gnt_c = 5'b01000;
          else if (req[2]) gnt_c = 5'b00100;
        end
        3'd4: begin // PE,N,S,E,W
          if (req[0])      gnt_c = 5'b00001;
          else if (req[4]) gnt_c = 5'b10000;
          else if (req[3]) gnt_c = 5'b01000;
          else if (req[2]) gnt_c = 5'b00100;
          else if (req[1]) gnt_c = 5'b00010;
        end
        default: gnt_c = 5'b00000;
      endcase
    end
  end

  // Registered rotation pointer: advance only on real grant
  always @(posedge clk) begin
    if (reset) begin
      ptr <= 3'd0; // seed at N
    end else begin
      if (gnt_c != 5'b00000) begin
        case (gnt_c)
          5'b10000: ptr <= 3'd1;
          5'b01000: ptr <= 3'd2;
          5'b00100: ptr <= 3'd3;
          5'b00010: ptr <= 3'd4;
          5'b00001: ptr <= 3'd0;
          default:  ptr <= ptr;
        endcase
      end
    end
  end

  assign gnt = gnt_c;
endmodule

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



// vc_phase.v
module vc_phase (
  input  wire clk,
  input  wire reset,   // active-high synchronous
  output reg  polarity // 0=even, 1=odd
);
  always @(posedge clk) begin
    if (reset) polarity <= 1'b0;
    else       polarity <= ~polarity;
  end
endmodule


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








//! ROUTER GOLDEN TOP

// gold_router.v
`timescale 1ns/1ps
module gold_router (
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

  //* External multiplexing by current external VC (opposite of 'phase_internal' of that VC):
  //* On even cycles (polarity=0): external = VC1, so expose VC1.so/do/ri
  //* On odd  cycles (polarity=1): external = VC0, so expose VC0.so/do/ri
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


