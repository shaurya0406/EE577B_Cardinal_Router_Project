`timescale 1ns/1ps
module router_vc_block_tb;
  reg clk, reset;
  reg phase_internal, phase_external;

  reg n_si, s_si, e_si, w_si, pe_si;
  wire n_ri, s_ri, e_ri, w_ri, pe_ri;
  reg [63:0] n_di, s_di, e_di, w_di, pe_di;

  wire n_so, s_so, e_so, w_so, pe_so;
  reg  n_ro, s_ro, e_ro, w_ro, pe_ro;
  wire [63:0] n_do, s_do, e_do, w_do, pe_do;

  router_vc_block DUT (
    .clk(clk), .reset(reset),
    .phase_internal(phase_internal), .phase_external(phase_external),
    .n_si(n_si), .n_ri(n_ri), .n_di(n_di),
    .s_si(s_si), .s_ri(s_ri), .s_di(s_di),
    .e_si(e_si), .e_ri(e_ri), .e_di(e_di),
    .w_si(w_si), .w_ri(w_ri), .w_di(w_di),
    .pe_si(pe_si), .pe_ri(pe_ri), .pe_di(pe_di),
    .n_so(n_so), .n_ro(n_ro), .n_do(n_do),
    .s_so(s_so), .s_ro(s_ro), .s_do(s_do),
    .e_so(e_so), .e_ro(e_ro), .e_do(e_do),
    .w_so(w_so), .w_ro(w_ro), .w_do(w_do),
    .pe_so(pe_so), .pe_ro(pe_ro), .pe_do(pe_do)
  );

  // Clock
  initial begin clk=0; forever #5 clk=~clk; end

  // Waves
  initial begin
    $dumpfile("router_vc_block_tb.vcd");
    $dumpvars(0, router_vc_block_tb);
  end

  function [63:0] mkpkt;
    input vc, dx, dy; input [4:0] rsv; input [3:0] hx, hy; input [7:0] sx, sy; input [31:0] pl;
    begin mkpkt = {vc,dx,dy,rsv,hx,hy,sx,sy,pl}; end
  endfunction

  integer errors; initial errors=0;

  initial begin
    // Defaults
    reset=1;
    phase_internal=0; phase_external=0;
    n_si=0; s_si=0; e_si=0; w_si=0; pe_si=0;
    n_di=0; s_di=0; e_di=0; w_di=0; pe_di=0;
    n_ro=0; s_ro=0; e_ro=0; w_ro=0; pe_ro=0;

    repeat(2) @(posedge clk);
    reset=0;

    // ======================
    // Cycle N: EXTERNAL receive on E
    // ======================
    phase_external=1; phase_internal=0;
    @(negedge clk);
    // Buffer empty -> e_ri must be 1
    if (e_ri !== 1'b1) begin $display("ERR: e_ri not 1 when empty/external"); errors=errors+1; end
    e_di = mkpkt(1'b0,1'b0,1'b0,5'b00000,4'b0011,4'b0000,8'h01,8'h01,32'hABCD0001);
    e_si = 1'b1;
    @(posedge clk); #2;
    e_si = 1'b0;

    // ======================
    // Cycle N+1: INTERNAL forward (grant+enqueue+dequeue in same cycle)
    // ======================
    phase_external=0; phase_internal=1;
    @(posedge clk); #2;
    // At this point, outbuf_E must have latched a packet (full=1 internally).
    // We can at least check that e_ri will be 1 again next external phase
    // (input dequeued), indirectly validated by successful send next.

    // ======================
    // Cycle N+2: EXTERNAL send (neighbor ready)
    // ======================
    phase_external=1; phase_internal=0;
    @(negedge clk);
    e_ro = 1'b1; // ready
    #1;
    if (e_so !== 1'b1) begin $display("ERR: e_so not asserted on send"); errors=errors+1; end
    if (e_do !== mkpkt(1'b0,1'b0,1'b0,5'b00000,4'b0001,4'b0000,8'h01,8'h01,32'hABCD0001)) begin
      $display("ERR: e_do mismatch / Hx not shifted once"); errors=errors+1;
    end
    @(posedge clk); #2; // consume & clear
    if (e_so !== 1'b0) begin $display("ERR: e_so did not drop after send"); errors=errors+1; end

    if (errors==0) $display("TB RESULT: PASS");
    else           $display("TB RESULT: FAIL (%0d)", errors);
    $finish;
  end
endmodule
