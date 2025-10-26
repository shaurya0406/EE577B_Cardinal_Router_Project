// req_matrix_tb.v
`timescale 1ns/1ps
module req_matrix_tb;
  reg         n_full,s_full,e_full,w_full,pe_full;
  reg  [63:0] n_q,s_q,e_q,w_q,pe_q;
  wire [4:0]  req_to_n, req_to_s, req_to_e, req_to_w, req_to_pe;
  wire [63:0] n_pkt_next, s_pkt_next, e_pkt_next, w_pkt_next, pe_pkt_next;

  req_matrix dut (
    .n_full(n_full), .n_q(n_q),
    .s_full(s_full), .s_q(s_q),
    .e_full(e_full), .e_q(e_q),
    .w_full(w_full), .w_q(w_q),
    .pe_full(pe_full), .pe_q(pe_q),
    .req_to_n(req_to_n), .req_to_s(req_to_s), .req_to_e(req_to_e), .req_to_w(req_to_w), .req_to_pe(req_to_pe),
    .n_pkt_next(n_pkt_next), .s_pkt_next(s_pkt_next), .e_pkt_next(e_pkt_next), .w_pkt_next(w_pkt_next), .pe_pkt_next(pe_pkt_next)
  );

  initial begin
    $dumpfile("req_matrix_tb.vcd");
    $dumpvars(0, req_matrix_tb);
  end

  integer errors; initial errors=0;

  // Helper: build header MSB fields (VC,Dx,Dy,Rsv,Hx,Hy,SrcX,SrcY)
  function [63:0] mkpkt;
    input vc, dx, dy; input [4:0] rsv; input [3:0] hx, hy; input [7:0] sx, sy; input [31:0] pl;
    begin
      mkpkt = {vc,dx,dy,rsv,hx,hy,sx,sy,pl};
    end
  endfunction

  initial begin
    // Simple: only E input has a packet needing +X (Dx=0) with Hx=0011 (2 hops)
    n_full=0; s_full=0; w_full=0; pe_full=0; e_full=1;
    e_q = mkpkt(1'b0,1'b0,1'b0,5'b00000,4'b0011,4'b0000,8'h01,8'h01,32'hDEAD_BEEF);
    #1;
    if (req_to_e !== 5'b00100) begin $display("ERR: E should request East"); errors=errors+1; end
    // Check Hx shifted by one, Hy unchanged
    if (e_pkt_next[55:52] !== 4'b0001 || e_pkt_next[51:48] !== 4'b0000) begin
      $display("ERR: E pkt_next shift wrong"); errors=errors+1;
    end

    // Now PE input: already local (Hx=Hy=0) -> request PE, no shift
    pe_full=1; pe_q = mkpkt(1'b1,1'b0,1'b0,5'b00000,4'b0000,4'b0000,8'h02,8'h03,32'hCAFEBABE);
    #1;
    if (req_to_pe[0] !== 1'b1) begin $display("ERR: PE should request PE"); errors=errors+1; end
    if (pe_pkt_next !== pe_q) begin $display("ERR: PE pkt_next should equal original"); errors=errors+1; end

    // N input: Hx=0, Hy=0011, Dy=0 -> request North; shift Y only
    n_full=1; n_q = mkpkt(1'b0,1'b1,1'b0,5'b00000,4'b0000,4'b0011,8'h00,8'h00,32'h11112222);
    #1;
    if (req_to_n[4] !== 1'b1) begin $display("ERR: N should request North"); errors=errors+1; end
    if (n_pkt_next[51:48] !== 4'b0001 || n_pkt_next[55:52] !== 4'b0000) begin
      $display("ERR: N pkt_next shift Y wrong"); errors=errors+1;
    end

    if (errors==0) $display("TB RESULT: PASS");
    else           $display("TB RESULT: FAIL (%0d)", errors);
    $finish;
  end
endmodule
