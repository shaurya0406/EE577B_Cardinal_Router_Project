// `timescale 1ns/1ps
// module tb_cd_local_xbar_4x2_reply_A;

//   localparam DATA_W=64; localparam CLK_PER=10;
//   reg clk, reset;

//   // request side (tie-off)
//   reg  [3:0]          in_si;     wire [3:0] in_ri;
//   reg  [4*DATA_W-1:0] in_di;
//   wire [1:0]          cv_so;     reg  [1:0] cv_ro; wire [2*DATA_W-1:0] cv_do;

//   // reply under test
//   reg  [1:0]          cv_si_r;   wire [1:0] cv_ri_r;
//   reg  [2*DATA_W-1:0] cv_di_r;
//   wire [3:0]          out_so;    reg  [3:0] out_ro;
//   wire [4*DATA_W-1:0] out_do;

//   cd_local_xbar_4x2 #(.DATA_W(DATA_W)) dut (
//     .clk(clk), .reset(reset),
//     .in_si(in_si), .in_ri(in_ri), .in_di(in_di),
//     .cv_so(cv_so), .cv_ro(cv_ro), .cv_do(cv_do),
//     .cv_si_r(cv_si_r), .cv_ri_r(cv_ri_r), .cv_di_r(cv_di_r),
//     .out_so(out_so), .out_ro(out_ro), .out_do(out_do)
//   );

//   initial begin clk=0; forever #(CLK_PER/2) clk=~clk; end

//   function [DATA_W-1:0] mk_reply;
//     input [7:0] srcx; input [7:0] srcy;
//     begin
//       mk_reply = { 1'b0,1'b0,1'b0, 5'b0, 4'b0,4'b0, srcx, srcy, 32'hDEAD_BEEF };
//     end
//   endfunction

//   wire [DATA_W-1:0] o0 = out_do[DATA_W*1-1:DATA_W*0];
//   wire [DATA_W-1:0] o1 = out_do[DATA_W*2-1:DATA_W*1];
//   wire [DATA_W-1:0] o2 = out_do[DATA_W*3-1:DATA_W*2];
//   wire [DATA_W-1:0] o3 = out_do[DATA_W*4-1:DATA_W*3];

//   initial begin
//     $dumpfile("tb_cd_local_xbar_4x2_reply_A.vcd");
//     $dumpvars(0, tb_cd_local_xbar_4x2_reply_A);

//     reset=1; in_si=0; in_di=0; cv_ro=2'b00; cv_si_r=2'b00; cv_di_r=0; out_ro=4'b1111;
//     repeat(4) @(posedge clk); reset=0;

//     // r0 -> out1 (x=1,y=0), r1 -> out2 (x=0,y=1)
//     cv_si_r = 2'b11;
//     cv_di_r[DATA_W*1-1:DATA_W*0] = mk_reply(8'h01,8'h00);
//     cv_di_r[DATA_W*2-1:DATA_W*1] = mk_reply(8'h00,8'h01);
//     @(posedge clk); #1;
//     if (!(out_so==4'b0110)) $display("[ERR] one-hot exp 0110 got %b", out_so);
//     if (!(o1==mk_reply(8'h01,8'h00))) $display("[ERR] o1 mismatch");
//     if (!(o2==mk_reply(8'h00,8'h01))) $display("[ERR] o2 mismatch");

//     // r0 -> out0, r1 -> out3
//     cv_di_r[DATA_W*1-1:DATA_W*0] = mk_reply(8'h00,8'h00);
//     cv_di_r[DATA_W*2-1:DATA_W*1] = mk_reply(8'h01,8'h01);
//     @(posedge clk); #1;
//     if (!(out_so==4'b1001)) $display("[ERR] one-hot exp 1001 got %b", out_so);
//     if (!(o0==mk_reply(8'h00,8'h00))) $display("[ERR] o0 mismatch");
//     if (!(o3==mk_reply(8'h01,8'h01))) $display("[ERR] o3 mismatch");

//     $display("[PASS] Reply Step A decode OK.");
//     $finish;
//   end
// endmodule


`timescale 1ns/1ps
module tb_cd_local_xbar_4x2_reply_B;

  localparam DATA_W=64; localparam CLK_PER=10;
  reg clk, reset;

  // request side (tie-off)
  reg  [3:0]          in_si;     wire [3:0] in_ri;
  reg  [4*DATA_W-1:0] in_di;
  wire [1:0]          cv_so;     reg  [1:0] cv_ro; wire [2*DATA_W-1:0] cv_do;

  // reply under test
  reg  [1:0]          cv_si_r;   wire [1:0] cv_ri_r;
  reg  [2*DATA_W-1:0] cv_di_r;
  wire [3:0]          out_so;    reg  [3:0] out_ro;
  wire [4*DATA_W-1:0] out_do;

  cd_local_xbar_4x2 #(.DATA_W(DATA_W)) dut (
    .clk(clk), .reset(reset),
    .in_si(in_si), .in_ri(in_ri), .in_di(in_di),
    .cv_so(cv_so), .cv_ro(cv_ro), .cv_do(cv_do),
    .cv_si_r(cv_si_r), .cv_ri_r(cv_ri_r), .cv_di_r(cv_di_r),
    .out_so(out_so), .out_ro(out_ro), .out_do(out_do)
  );

  initial begin clk=0; forever #(CLK_PER/2) clk=~clk; end

  function [DATA_W-1:0] mk_reply;
    input [7:0] srcx; input [7:0] srcy;
    begin
      mk_reply = { 1'b0,1'b0,1'b0, 5'b0, 4'b0,4'b0, srcx, srcy, 32'hCAFE_F00D };
    end
  endfunction

  wire [DATA_W-1:0] o0 = out_do[DATA_W*1-1:DATA_W*0];
  wire [DATA_W-1:0] o1 = out_do[DATA_W*2-1:DATA_W*1];
  wire [DATA_W-1:0] o2 = out_do[DATA_W*3-1:DATA_W*2];
  wire [DATA_W-1:0] o3 = out_do[DATA_W*4-1:DATA_W*3];

  initial begin
    $dumpfile("tb_cd_local_xbar_4x2_reply_B.vcd");
    $dumpvars(0, tb_cd_local_xbar_4x2_reply_B);

    reset=1; in_si=0; in_di=0; cv_ro=2'b00; cv_si_r=2'b00; cv_di_r=0; out_ro=4'b1111;
    repeat(4) @(posedge clk); reset=0;

    // Conflict: both to out1 (x=1,y=0) → input0 wins, input1 backpressured
    cv_si_r = 2'b11;
    cv_di_r[DATA_W*1-1:DATA_W*0] = mk_reply(8'h01,8'h00);
    cv_di_r[DATA_W*2-1:DATA_W*1] = mk_reply(8'h01,8'h00);
    @(posedge clk); #1;
    if (!(out_so==4'b0010)) $display("[ERR] conflict: out_so exp 0010 got %b", out_so);
    if (!(o1==mk_reply(8'h01,8'h00))) $display("[ERR] conflict: o1 mismatch");
    if (!(cv_ri_r==2'b01)) $display("[ERR] conflict: cv_ri_r exp 01 got %b", cv_ri_r);

    // Different targets → both fire, both ready
    cv_di_r[DATA_W*1-1:DATA_W*0] = mk_reply(8'h00,8'h00); // out0
    cv_di_r[DATA_W*2-1:DATA_W*1] = mk_reply(8'h01,8'h01); // out3
    @(posedge clk); #1;
    if (!(out_so==4'b1001)) $display("[ERR] split: out_so exp 1001 got %b", out_so);
    if (!(o0==mk_reply(8'h00,8'h00))) $display("[ERR] split: o0 mismatch");
    if (!(o3==mk_reply(8'h01,8'h01))) $display("[ERR] split: o3 mismatch");
    if (!(cv_ri_r==2'b11)) $display("[ERR] split: cv_ri_r exp 11 got %b", cv_ri_r);

    // Not ready on out2 → nobody fires, both not-ready
    out_ro = 4'b1011; // out2=0
    cv_di_r[DATA_W*1-1:DATA_W*0] = mk_reply(8'h00,8'h01); // out2
    cv_di_r[DATA_W*2-1:DATA_W*1] = mk_reply(8'h00,8'h01); // out2
    @(posedge clk); #1;
    if (!(out_so==4'b0000)) $display("[ERR] not-ready: out_so exp 0000 got %b", out_so);
    if (!(cv_ri_r==2'b00)) $display("[ERR] not-ready: cv_ri_r exp 00 got %b", cv_ri_r);

    $display("[PASS] Reply Step B backpressure OK.");
    $finish;
  end
endmodule
