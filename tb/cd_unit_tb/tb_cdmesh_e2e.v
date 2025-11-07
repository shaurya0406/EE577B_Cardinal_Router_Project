`timescale 1ns/1ps
module tb_cdmesh_e2e;
  localparam DATA_W=64; localparam CLK=10;
  reg clk, reset;

  // Local0 router side
  reg  [3:0]          in_si;
  wire [3:0]          in_ri;
  reg  [4*DATA_W-1:0] in_di;
  wire [3:0]          out_so;
  reg  [3:0]          out_ro;
  wire [4*DATA_W-1:0] out_do;

  cdmesh_e2e_demo #(.DATA_W(DATA_W)) dut (
    .clk(clk), .reset(reset),
    .l0_in_si(in_si), .l0_in_ri(in_ri), .l0_in_di(in_di),
    .l0_out_so(out_so), .l0_out_ro(out_ro), .l0_out_do(out_do)
  );

  initial begin clk=1'b0; forever #(CLK/2) clk=~clk; end

  // Helper: make header with fields
  // Layout (matches your hdr_fields):
  // [63] VC, [62] Dx, [61] Dy, [60:56] Rsv, [55:52] Hx, [51:48] Hy, [47:40] SrcX, [39:32] SrcY, [31:0] payload/opaque
  function [DATA_W-1:0] mk_hdr;
    input [3:0] hx, hy;
    input [7:0] sx, sy;
    input [31:0] pay;
    begin
      mk_hdr = {1'b0,1'b0,1'b0,5'b0, hx, hy, sx, sy, pay};
    end
  endfunction

  // Per-router counters (8-bit)
  reg [7:0] c0,c1,c2,c3;

  // Split outs
  wire [DATA_W-1:0] o0 = out_do[DATA_W*1-1:DATA_W*0];
  wire [DATA_W-1:0] o1 = out_do[DATA_W*2-1:DATA_W*1];
  wire [DATA_W-1:0] o2 = out_do[DATA_W*3-1:DATA_W*2];
  wire [DATA_W-1:0] o3 = out_do[DATA_W*4-1:DATA_W*3];

  // VCD
  initial begin
    $dumpfile("tb_cdmesh_e2e.vcd");
    $dumpvars(0,tb_cdmesh_e2e);
  end

  // Reset & defaults
  initial begin
    reset=1'b1; in_si=4'b0000; in_di={4*DATA_W{1'b0}}; out_ro=4'b1111;
    c0=0;c1=0;c2=0;c3=0;
    repeat(4) @(posedge clk); reset=1'b0;
  end

  // Test
  initial begin : TEST
    wait(!reset);

    // Send two requests simultaneously:
    // - router0 (0,0) → LLC0 at (0,0) ; Src=(0,0)
    // - router1 (1,0) → LLC1 at (3,0) ; Src=(1,0)
    in_si = 4'b0011;
    in_di[DATA_W*1-1:DATA_W*0] = mk_hdr(4'd0,4'd0, 8'd0,8'd0, 32'hDEAD0000); // r0 → LLC0, SrcX/Y=(0,0)
    in_di[DATA_W*2-1:DATA_W*1] = mk_hdr(4'd3,4'd0, 8'd1,8'd0, 32'hBEEF0001); // r1 → LLC1, SrcX/Y=(1,0)
    in_di[DATA_W*3-1:DATA_W*2] = {DATA_W{1'b0}};
    in_di[DATA_W*4-1:DATA_W*3] = {DATA_W{1'b0}};

    // Hold valid for a few cycles until accepted
    repeat(8) @(posedge clk);

    // Deassert valids
    in_si = 4'b0000;

    // Wait for replies and check which router got them
    // LLC proxies emit BURST=2 replies per request; we expect:
    // - replies for r0 on out_so[0] with o0 carrying original header echo
    // - replies for r1 on out_so[1] with o1 carrying original header echo
    repeat(32) @(posedge clk) begin
      // consume if valid
      if (out_so[0]) c0 <= c0 + 1;
      if (out_so[1]) c1 <= c1 + 1;
    end

    // Simple pass criteria: each of r0 and r1 should see >0 reply flits
    if (c0==0) $display("[ERR] No replies seen on router0 (expected >0)");
    if (c1==0) $display("[ERR] No replies seen on router1 (expected >0)");
    if ((c0!=0) && (c1!=0)) $display("[PASS] e2e CD-mesh demo replies returned to correct routers.");
    $finish;
  end
endmodule
