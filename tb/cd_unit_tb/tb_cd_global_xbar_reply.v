`timescale 1ns/1ps
module tb_cd_global_xbar_reply;

  localparam DATA_W=64; localparam CLK_PER=10;

  reg                   clk, reset;

  // req side (tie-off)
  reg  [7:0]            in_si;   wire [7:0] in_ri;
  reg  [8*DATA_W-1:0]   in_di;
  wire [3:0]            llc_so;  reg  [3:0] llc_ro;  wire [4*DATA_W-1:0] llc_do;

  // reply under test
  reg  [3:0]            llc_si_r; wire [3:0] llc_ri_r;
  reg  [4*DATA_W-1:0]   llc_di_r;
  wire [7:0]            out_so;   reg  [7:0] out_ro;
  wire [8*DATA_W-1:0]   out_do;

  cd_global_xbar_8x4 #(.DATA_W(DATA_W)) dut (
    .clk(clk), .reset(reset),
    .in_si(in_si), .in_ri(in_ri), .in_di(in_di),
    .llc_so(llc_so), .llc_ro(llc_ro), .llc_do(llc_do),
    .llc_si_r(llc_si_r), .llc_ri_r(llc_ri_r), .llc_di_r(llc_di_r),
    .out_so(out_so), .out_ro(out_ro), .out_do(out_do)
  );

  initial begin clk=0; forever #(CLK_PER/2) clk=~clk; end

  // Build a reply flit with srcx/srcy; pay attention to bits per mapping:
  // Quadrant base = {sy[1],sx[1]}*2 ; link select = sy[0]
  function [DATA_W-1:0] mk_reply;
    input [7:0] srcx; input [7:0] srcy; input [7:0] tag;
    begin
      mk_reply = { 1'b0,1'b0,1'b0, 5'b0, 4'b0, 4'b0, srcx, srcy, 24'h0, tag };
    end
  endfunction

  // Unpack outs
  wire [DATA_W-1:0] o0 = out_do[DATA_W*1-1:DATA_W*0];
  wire [DATA_W-1:0] o1 = out_do[DATA_W*2-1:DATA_W*1];
  wire [DATA_W-1:0] o2 = out_do[DATA_W*3-1:DATA_W*2];
  wire [DATA_W-1:0] o3 = out_do[DATA_W*4-1:DATA_W*3];
  wire [DATA_W-1:0] o4 = out_do[DATA_W*5-1:DATA_W*4];
  wire [DATA_W-1:0] o5 = out_do[DATA_W*6-1:DATA_W*5];
  wire [DATA_W-1:0] o6 = out_do[DATA_W*7-1:DATA_W*6];
  wire [DATA_W-1:0] o7 = out_do[DATA_W*8-1:DATA_W*7];

  initial begin
    $dumpfile("tb_cd_global_xbar_reply.vcd");
    $dumpvars(0, tb_cd_global_xbar_reply);

    // reset
    reset=1; in_si=0; in_di=0; llc_ro=4'b0000; out_ro=8'hFF; llc_si_r=4'b0000; llc_di_r=0;
    repeat(3) @(posedge clk); reset=0;

    // ---------------- Case 1: two distinct targets ----------------
    // r0 -> Q0 link0: sx=0000_0000, sy=0000_0000 -> out0
    // r1 -> Q1 link1: sx=0000_0010 (sx[1]=1), sy=0000_0001 (sy[1]=0, sy[0]=1) -> base=2, sel=1 -> out3
    llc_si_r = 4'b0011; // r0,r1 valid
    llc_di_r[DATA_W*1-1:DATA_W*0] = mk_reply(8'h00,8'h00,8'hA0);
    llc_di_r[DATA_W*2-1:DATA_W*1] = mk_reply(8'h02,8'h01,8'hB1);
    out_ro = 8'hFF;
    #1;
    if (!(out_so==8'b0000_1001)) $display("[ERR] C1 out_so exp 00001001 got %b", out_so);
    if (!(o0==mk_reply(8'h00,8'h00,8'hA0))) $display("[ERR] C1 o0 mismatch");
    if (!(o3==mk_reply(8'h02,8'h01,8'hB1))) $display("[ERR] C1 o3 mismatch");
    if (!(llc_ri_r==4'b0011)) $display("[ERR] C1 llc_ri_r exp 0011 got %b", llc_ri_r);
    @(posedge clk);

    // ---------------- Case 2: conflict same target (fixed priority) ----
    // Both to out5 (Q2 base=4, sel=1)
    llc_si_r = 4'b0011; // r0,r1 valid
    llc_di_r[DATA_W*1-1:DATA_W*0] = mk_reply(8'h00,8'h11,8'hC0); // Q2 sel1 -> out5
    llc_di_r[DATA_W*2-1:DATA_W*1] = mk_reply(8'h00,8'h11,8'hC1); // same
    out_ro = 8'hFF;
    #1;
    if (!(out_so==8'b0010_0000)) $display("[ERR] C2 out_so exp 00100000 got %b", out_so);
    if (!(o5==mk_reply(8'h00,8'h11,8'hC0))) $display("[ERR] C2 priority: expect r0 win");
    if (!(llc_ri_r==4'b0001)) $display("[ERR] C2 llc_ri_r exp 0001 got %b", llc_ri_r);
    @(posedge clk);

    // ---------------- Case 3: not ready target -------------------------
    // r2 targets out7 (Q3 sel1), but out_ro[7]=0
    llc_si_r = 4'b0100; // only r2 valid
    llc_di_r[DATA_W*3-1:DATA_W*2] = mk_reply(8'h03,8'h11,8'hD2); // sx[1]=1, sy[1]=1 → base=6, sel=1 → out7
    out_ro = 8'b0111_1111; // out7 not ready
    #1;
    if (!(out_so==8'b0000_0000)) $display("[ERR] C3 out_so exp 0 got %b", out_so);
    if (!(llc_ri_r==4'b0000)) $display("[ERR] C3 llc_ri_r exp 0 got %b", llc_ri_r);

    $display("[PASS] cd_global_xbar_8x4 reply path OK.");
    $finish;
  end

endmodule
