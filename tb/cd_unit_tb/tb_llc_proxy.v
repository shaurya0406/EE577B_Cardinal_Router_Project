`timescale 1ns/1ps

module tb_llc_proxy;

  // -------------------------------------------------------------------
  // Params & clock
  // -------------------------------------------------------------------
  localparam DATA_W = 64;
  localparam CLK_PER = 10;

  reg  clk, reset;

  // xbar -> LLC (request)
  reg        [3:0]     llc_so;
  wire       [3:0]     llc_ro;
  reg  [4*DATA_W-1:0]  llc_do;

  // LLC -> xbar (reply)
  wire       [3:0]     llc_si_r;
  reg        [3:0]     llc_ri_r;
  wire [4*DATA_W-1:0]  llc_di_r;

  // DUT with distinct reply latencies (0 is immediate)
  llc_proxy #(
    .DATA_W(DATA_W),
    .LAT0(4'd2),
    .LAT1(4'd3),
    .LAT2(4'd0),
    .LAT3(4'd5)
  ) dut (
    .clk(clk), .reset(reset),
    .llc_so(llc_so), .llc_ro(llc_ro), .llc_do(llc_do),
    .llc_si_r(llc_si_r), .llc_ri_r(llc_ri_r), .llc_di_r(llc_di_r)
  );

  // Clock
  initial begin
    clk = 1'b0;
    forever #(CLK_PER/2) clk = ~clk;
  end

  // -------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------
  function [DATA_W-1:0] mk_word;
    input [7:0] tag;
    begin
      // recognizable filler + tag in LSB
      mk_word = {16'hABCD, 8'h55, 8'hAA, 16'h1337, 8'h00, tag};
    end
  endfunction

  // Unpack replies for comparisons
  wire [DATA_W-1:0] r0 = llc_di_r[DATA_W*1-1:DATA_W*0];
  wire [DATA_W-1:0] r1 = llc_di_r[DATA_W*2-1:DATA_W*1];
  wire [DATA_W-1:0] r2 = llc_di_r[DATA_W*3-1:DATA_W*2];
  wire [DATA_W-1:0] r3 = llc_di_r[DATA_W*4-1:DATA_W*3];

  // Drive a one-cycle request on negedge for clean setup
  task send_req_p0;
    input [DATA_W-1:0] w;
    begin
      while (llc_ro[0] !== 1'b1) @(posedge clk);
      @(negedge clk);
      llc_do[DATA_W*1-1:DATA_W*0] <= w;
      llc_so <= 4'b0001;
      @(posedge clk);  // handshake happens here
      #1 if (llc_ro[0] !== 1'b0) $display("[ERR] P0: llc_ro should drop after accept");
      @(negedge clk);
      llc_so <= 4'b0000;
    end
  endtask

  task send_req_p1;
    input [DATA_W-1:0] w;
    begin
      while (llc_ro[1] !== 1'b1) @(posedge clk);
      @(negedge clk);
      llc_do[DATA_W*2-1:DATA_W*1] <= w;
      llc_so <= 4'b0010;
      @(posedge clk);
      #1 if (llc_ro[1] !== 1'b0) $display("[ERR] P1: llc_ro should drop after accept");
      @(negedge clk);
      llc_so <= 4'b0000;
    end
  endtask

  task send_req_p2;
    input [DATA_W-1:0] w;
    begin
      while (llc_ro[2] !== 1'b1) @(posedge clk);
      @(negedge clk);
      llc_do[DATA_W*3-1:DATA_W*2] <= w;
      llc_so <= 4'b0100;
      @(posedge clk);
      #1 if (llc_ro[2] !== 1'b0) $display("[ERR] P2: llc_ro should drop after accept");
      @(negedge clk);
      llc_so <= 4'b0000;
    end
  endtask

  task send_req_p3;
    input [DATA_W-1:0] w;
    begin
      while (llc_ro[3] !== 1'b1) @(posedge clk);
      @(negedge clk);
      llc_do[DATA_W*4-1:DATA_W*3] <= w;
      llc_so <= 4'b1000;
      @(posedge clk);
      #1 if (llc_ro[3] !== 1'b0) $display("[ERR] P3: llc_ro should drop after accept");
      @(negedge clk);
      llc_so <= 4'b0000;
    end
  endtask

  // Consume replies with one-cycle ready pulse; ensure persistence
  task recv_reply_p0;
    input [DATA_W-1:0] exp;
    begin
      while (llc_si_r[0] !== 1'b1) @(posedge clk);
      #1 if (r0 !== exp) $display("[ERR] P0: reply data mismatch");
      @(posedge clk); // hold for a cycle to check persistence
      #1 if (llc_si_r[0] !== 1'b1) $display("[ERR] P0: reply should persist");
      @(negedge clk) llc_ri_r <= 4'b0001;
      @(posedge clk);
      @(negedge clk) llc_ri_r <= 4'b0000;
      #1 if (llc_si_r[0] !== 1'b0) $display("[ERR] P0: reply valid should drop");
      if (llc_ro[0] !== 1'b1) $display("[ERR] P0: llc_ro should rise after free");
    end
  endtask

  task recv_reply_p1;
    input [DATA_W-1:0] exp;
    begin
      while (llc_si_r[1] !== 1'b1) @(posedge clk);
      #1 if (r1 !== exp) $display("[ERR] P1: reply data mismatch");
      @(posedge clk);
      #1 if (llc_si_r[1] !== 1'b1) $display("[ERR] P1: reply should persist");
      @(negedge clk) llc_ri_r <= 4'b0010;
      @(posedge clk);
      @(negedge clk) llc_ri_r <= 4'b0000;
      #1 if (llc_si_r[1] !== 1'b0) $display("[ERR] P1: reply valid should drop");
      if (llc_ro[1] !== 1'b1) $display("[ERR] P1: llc_ro should rise after free");
    end
  endtask

  task recv_reply_p2;
    input [DATA_W-1:0] exp;
    begin
      // LAT2=0: should be valid right after the accept edge we already did
      while (llc_si_r[2] !== 1'b1) @(posedge clk);
      #1 if (r2 !== exp) $display("[ERR] P2: reply data mismatch");
      @(negedge clk) llc_ri_r <= 4'b0100;
      @(posedge clk);
      @(negedge clk) llc_ri_r <= 4'b0000;
      #1 if (llc_si_r[2] !== 1'b0) $display("[ERR] P2: reply valid should drop");
      if (llc_ro[2] !== 1'b1) $display("[ERR] P2: llc_ro should rise after free");
    end
  endtask

  task recv_reply_p3;
    input [DATA_W-1:0] exp;
    begin
      while (llc_si_r[3] !== 1'b1) @(posedge clk);
      #1 if (r3 !== exp) $display("[ERR] P3: reply data mismatch");
      @(posedge clk);
      #1 if (llc_si_r[3] !== 1'b1) $display("[ERR] P3: reply should persist");
      @(negedge clk) llc_ri_r <= 4'b1000;
      @(posedge clk);
      @(negedge clk) llc_ri_r <= 4'b0000;
      #1 if (llc_si_r[3] !== 1'b0) $display("[ERR] P3: reply valid should drop");
      if (llc_ro[3] !== 1'b1) $display("[ERR] P3: llc_ro should rise after free");
    end
  endtask

  // -------------------------------------------------------------------
  // Stimulus
  // -------------------------------------------------------------------
  initial begin
    $dumpfile("tb_llc_proxy.vcd");
    $dumpvars(0, tb_llc_proxy);

    llc_so   = 4'b0000;
    llc_do   = {4*DATA_W{1'b0}};
    llc_ri_r = 4'b0000;

    reset = 1'b1; repeat (3) @(posedge clk); reset = 1'b0;

    // Port 0 (LAT0=2)
    send_req_p0(mk_word(8'hA0));
    @(posedge clk); @(posedge clk);  // wait 2 cycles
    recv_reply_p0(mk_word(8'hA0));

    // Port 1 (LAT1=3)
    send_req_p1(mk_word(8'hB1));
    @(posedge clk); @(posedge clk); @(posedge clk);
    recv_reply_p1(mk_word(8'hB1));

    // Port 2 (LAT2=0) — immediate
    send_req_p2(mk_word(8'hC2));
    // On the accept edge, immediate reply should already be visible by now
    @(posedge clk); #1;
    if (llc_si_r[2] !== 1'b1) $display("[ERR] P2: expected immediate reply valid");
    recv_reply_p2(mk_word(8'hC2));

    // Port 3 (LAT3=5)
    send_req_p3(mk_word(8'hD3));
    @(posedge clk); @(posedge clk); @(posedge clk); @(posedge clk); @(posedge clk);
    recv_reply_p3(mk_word(8'hD3));

    // Negative: keep asserting so while busy (should not overwrite)
    send_req_p0(mk_word(8'hE0));
    @(negedge clk);
    llc_do[DATA_W*1-1:DATA_W*0] <= mk_word(8'hE1); // different word (must be ignored)
    llc_so <= 4'b0001;
    @(posedge clk);
    @(posedge clk);  // in latency window
    @(negedge clk) llc_so <= 4'b0000;
    @(posedge clk); @(posedge clk);
    recv_reply_p0(mk_word(8'hE0)); // must match original, not overwritten

    $display("[PASS] llc_proxy basic tests passed.");
    $finish;
  end

endmodule
