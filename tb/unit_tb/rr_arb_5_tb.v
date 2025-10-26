`timescale 1ns/1ps
module tb_rr_arb_5;
  reg clk, reset;
  reg [4:0] req;
  reg outbuf_full;
  wire [4:0] gnt;

  rr_arb_5 dut (
    .clk(clk),
    .reset(reset),
    .req(req),
    .outbuf_full(outbuf_full),
    .gnt(gnt)
  );

  // 100 MHz clock
  initial begin clk = 1'b0; forever #5 clk = ~clk; end
  initial begin
    $dumpfile("rr_arb_5_tb.vcd");
    $dumpvars(0, tb_rr_arb_5);
  end

  integer errors;
  integer i;

  initial begin
    errors = 0;
    req = 5'b00000;
    outbuf_full = 1'b0;

    // Reset
    reset = 1'b1;
    repeat(2) @(posedge clk);
    reset = 1'b0;

    // ------------------------------------------------------------------
    // (A) No requests -> no grants (sample on posedge)
    // ------------------------------------------------------------------
    @(posedge clk);
    #2
    if (gnt !== 5'b00000) begin
      $display("ERR: grant with no requests");
      errors = errors + 1;
    end

    // ------------------------------------------------------------------
    // (B) Single requester (E). Drive on negedge, sample two posedges later.
    // Registered gnt requires a clean posedge with req stable beforehand.
    // ------------------------------------------------------------------
    @(negedge clk);
    req = 5'b00100; // E only
    @(posedge clk); // evaluate gnt for this edge
    @(posedge clk); // allow one full registered update window
    #2
    if (gnt !== 5'b00100) begin
      $display("ERR: single requester E not granted");
      errors = errors + 1;
    end

    // ------------------------------------------------------------------
    // (C) All requesters high, watch rotation (just print 5 cycles)
    // ------------------------------------------------------------------
    @(negedge clk);
    req = 5'b11111;
    for (i=0; i<5; i=i+1) begin
      @(posedge clk);
      #2
      $display("t=%0t gnt=%b", $time, gnt);
      if (gnt == 5'b00000) begin
        $display("ERR: no grant under full requests");
        errors = errors + 1;
      end
    end

    // ------------------------------------------------------------------
    // (D) Block by outbuf_full. Assert on negedge, then sample next posedge.
    // ------------------------------------------------------------------
    @(negedge clk);
    outbuf_full = 1'b1;
    @(posedge clk);
    #2
    if (gnt !== 5'b00000) begin
      $display("ERR: grant while outbuf_full=1");
      errors = errors + 1;
    end

    // ------------------------------------------------------------------
    // (E) Unblock; give one extra posedge for registered grant to reappear.
    // Keep reqs asserted == 11111.
    // ------------------------------------------------------------------
    @(negedge clk);
    outbuf_full = 1'b0;
    @(posedge clk); // first edge after unblock
    @(posedge clk); // allow registered gnt to update
    #2
    if (gnt == 5'b00000) begin
      $display("ERR: no grant after unblocking");
      errors = errors + 1;
    end

    if (errors==0) $display("TB RESULT: PASS");
    else           $display("TB RESULT: FAIL (%0d errors)", errors);
    $finish;
  end
endmodule
