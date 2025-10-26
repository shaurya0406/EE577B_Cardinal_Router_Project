// xbar_internal_tb.v
`timescale 1ns/1ps
module xbar_internal_tb;
  reg clk, reset;

  // Inputs (buffers)
  reg         n_full,s_full,e_full,w_full,pe_full;
  reg  [63:0] n_q,s_q,e_q,w_q,pe_q;

  // Next packets from req_matrix
  wire [63:0] n_pkt_next, s_pkt_next, e_pkt_next, w_pkt_next, pe_pkt_next;
  wire [4:0]  req_to_n, req_to_s, req_to_e, req_to_w, req_to_pe;

  // Grants (drive from TB)
  reg  [4:0]  gnt_to_n, gnt_to_s, gnt_to_e, gnt_to_w, gnt_to_pe;

  // Outbuf full flags
  reg outbuf_full_n, outbuf_full_s, outbuf_full_e, outbuf_full_w, outbuf_full_pe;

  // Crossbar outputs
  reg phase_internal;
  wire enq_n,enq_s,enq_e,enq_w,enq_pe;
  wire [63:0] d_in_n,d_in_s,d_in_e,d_in_w,d_in_pe;
  wire deq_n,deq_s,deq_e,deq_w,deq_pe;

  // Instantiate req_matrix
  req_matrix RM (
    .n_full(n_full), .n_q(n_q),
    .s_full(s_full), .s_q(s_q),
    .e_full(e_full), .e_q(e_q),
    .w_full(w_full), .w_q(w_q),
    .pe_full(pe_full), .pe_q(pe_q),
    .req_to_n(req_to_n), .req_to_s(req_to_s), .req_to_e(req_to_e), .req_to_w(req_to_w), .req_to_pe(req_to_pe),
    .n_pkt_next(n_pkt_next), .s_pkt_next(s_pkt_next), .e_pkt_next(e_pkt_next), .w_pkt_next(w_pkt_next), .pe_pkt_next(pe_pkt_next)
  );

  // Instantiate crossbar
  xbar_internal XBAR (
    .clk(clk), .reset(reset), .phase_internal(phase_internal),
    .n_full(n_full), .n_q(n_q), .n_pkt_next(n_pkt_next),
    .s_full(s_full), .s_q(s_q), .s_pkt_next(s_pkt_next),
    .e_full(e_full), .e_q(e_q), .e_pkt_next(e_pkt_next),
    .w_full(w_full), .w_q(w_q), .w_pkt_next(w_pkt_next),
    .pe_full(pe_full), .pe_q(pe_q), .pe_pkt_next(pe_pkt_next),
    .gnt_to_n(gnt_to_n), .gnt_to_s(gnt_to_s), .gnt_to_e(gnt_to_e), .gnt_to_w(gnt_to_w), .gnt_to_pe(gnt_to_pe),
    .outbuf_full_n(outbuf_full_n), .outbuf_full_s(outbuf_full_s), .outbuf_full_e(outbuf_full_e),
    .outbuf_full_w(outbuf_full_w), .outbuf_full_pe(outbuf_full_pe),
    .enq_n(enq_n), .d_in_n(d_in_n), .enq_s(enq_s), .d_in_s(d_in_s),
    .enq_e(enq_e), .d_in_e(d_in_e), .enq_w(enq_w), .d_in_w(d_in_w),
    .enq_pe(enq_pe), .d_in_pe(d_in_pe),
    .deq_n(deq_n), .deq_s(deq_s), .deq_e(deq_e), .deq_w(deq_w), .deq_pe(deq_pe)
  );

  // Clock
  initial begin clk=0; forever #5 clk=~clk; end
  initial begin
    $dumpfile("xbar_internal_tb.vcd");
    $dumpvars(0, xbar_internal_tb);
  end

  function [63:0] mkpkt;
    input vc, dx, dy; input [4:0] rsv; input [3:0] hx, hy; input [7:0] sx, sy; input [31:0] pl;
    begin mkpkt = {vc,dx,dy,rsv,hx,hy,sx,sy,pl}; end
  endfunction

  integer errors; initial errors=0;

  initial begin
    // Reset / defaults
    reset=1; phase_internal=0;
    n_full=0; s_full=0; e_full=0; w_full=0; pe_full=0;
    n_q=0; s_q=0; e_q=0; w_q=0; pe_q=0;
    gnt_to_n=0; gnt_to_s=0; gnt_to_e=0; gnt_to_w=0; gnt_to_pe=0;
    outbuf_full_n=0; outbuf_full_s=0; outbuf_full_e=0; outbuf_full_w=0; outbuf_full_pe=0;

    repeat(2) @(posedge clk);
    reset=0;

    // Prepare: E input holds +X two hops => it should route to East
    e_full=1; e_q = mkpkt(1'b0,1'b0,1'b0,5'b0,4'b0011,4'b0000,8'h01,8'h01,32'hAAAA0001);
    // Phase internal ON
    @(negedge clk); phase_internal=1;

    // Case 1: Grant E input to E output
    @(negedge clk);
    gnt_to_e = 5'b00100;  // bit2 selects E input among {N,S,E,W,PE}={4,3,2,1,0}
    @(posedge clk); #1
    if (!(enq_e==1 && d_in_e==e_pkt_next && deq_e==1)) begin
      $display("ERR: E->E transfer failed"); errors=errors+1;
    end
    // Others idle
    if (enq_n|enq_s|enq_w|enq_pe) begin
      $display("ERR: unexpected enqueue on other outputs"); errors=errors+1;
    end

    // Case 2: Blocked E outbuf => no movement
    @(negedge clk);
    outbuf_full_e=1; gnt_to_e=5'b00100;
    @(posedge clk); #1
    if (enq_e|deq_e) begin
      $display("ERR: movement while outbuf_full_e=1"); errors=errors+1;
    end
    outbuf_full_e=0;

    // Case 3: Route to N using N input (Hy hops)
    n_full=1; n_q = mkpkt(1'b0,1'b1,1'b0,5'b0,4'b0000,4'b0011,8'h00,8'h00,32'hBBBB0002);
    @(negedge clk);
    gnt_to_n = 5'b10000; // bit4 selects N input
    gnt_to_e = 5'b00000;
    @(posedge clk); #1
    if (!(enq_n==1 && d_in_n==n_pkt_next && deq_n==1)) begin
      $display("ERR: N->N transfer failed"); errors=errors+1;
    end

    // Case 4: phase_internal=0 => no internal movement even if grants exist
    @(negedge clk);
    phase_internal=0; gnt_to_n=5'b10000;
    @(posedge clk); #1
    if (enq_n|deq_n) begin
      $display("ERR: movement when phase_internal=0"); errors=errors+1;
    end

    if (errors==0) $display("TB RESULT: PASS");
    else           $display("TB RESULT: FAIL (%0d)", errors);
    $finish;
  end
endmodule
