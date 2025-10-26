`timescale 1ns/1ps
// Plain-Verilog TB for rr_arb_5 (combinational grant, registered pointer)
// req/gnt bit order: [4]=N, [3]=S, [2]=E, [1]=W, [0]=PE

module rr_arb_5_tb;
  reg        clk, reset;
  reg  [4:0] req;
  reg        outbuf_full;
  wire [4:0] gnt;

  // DUT
  rr_arb_5 dut (
    .clk(clk),
    .reset(reset),
    .req(req),
    .outbuf_full(outbuf_full),
    .gnt(gnt)
  );

  // 100 MHz clock
  initial begin clk = 1'b0; forever #5 clk = ~clk; end

  // Waves
  initial begin
    $dumpfile("rr_arb_5_tb.vcd");
    $dumpvars(0, rr_arb_5_tb);
  end

  // Next-in-rotation helper (pure function, no tasks)
  function [4:0] next_rot;
    input [4:0] g;
    begin
      case (g)
        5'b10000: next_rot = 5'b01000; // N -> S
        5'b01000: next_rot = 5'b00100; // S -> E
        5'b00100: next_rot = 5'b00010; // E -> W
        5'b00010: next_rot = 5'b00001; // W -> PE
        5'b00001: next_rot = 5'b10000; // PE -> N
        default : next_rot = 5'b00000;
      endcase
    end
  endfunction

  integer errors; initial errors = 0;
  reg [4:0] g0, gexp, gcur;
  reg [4:0] g_last;

  initial begin
    // ---------------- Reset ----------------
    reset = 1;
    req = 5'b00000;
    outbuf_full = 1'b0;
    repeat (2) @(posedge clk);
    reset = 0;
    @(posedge clk); #2;

    // ---------------------------------------------------------
    // 1) No requests → no grant
    // ---------------------------------------------------------
    @(negedge clk);
    req = 5'b00000;
    #1;
    if (gnt !== 5'b00000) begin
      $display("ERR: grant with no requests (gnt=%b)", gnt);
      errors = errors + 1;
    end

    // ---------------------------------------------------------
    // 2) Single requester (E = bit2) should be immediate
    // ---------------------------------------------------------
    @(negedge clk);
    req = 5'b00100;
    #1;
    if (gnt !== 5'b00100) begin
      $display("ERR: single requester E not granted (gnt=%b)", gnt);
      errors = errors + 1;
    end
    @(posedge clk); #2;

    // ---------------------------------------------------------
    // 3) Full contention — verify rotation RELATIVE to first grant
    // ---------------------------------------------------------
    // Re-seed deterministically
    reset = 1; @(posedge clk); reset = 0; @(posedge clk); #1;

    @(negedge clk);
    req = 5'b11111; // all request
    #1;

    // Capture first grant (start), then check the next four in order
    
    g0 = gnt;
    if (g0 === 5'b00000) begin
      $display("ERR: no grant under full contention");
      errors = errors + 1;
    end

    // step 2..5
    @(posedge clk); #1; gexp = next_rot(g0); gcur = gnt;
    if (gcur !== gexp) begin
      $display("ERR: rotation step2 expected %b, got %b (start %b)", gexp, gcur, g0);
      errors = errors + 1;
    end

    @(posedge clk); #1; gexp = next_rot(gexp); gcur = gnt;
    if (gcur !== gexp) begin
      $display("ERR: rotation step3 expected %b, got %b (start %b)", gexp, gcur, g0);
      errors = errors + 1;
    end

    @(posedge clk); #1; gexp = next_rot(gexp); gcur = gnt;
    if (gcur !== gexp) begin
      $display("ERR: rotation step4 expected %b, got %b (start %b)", gexp, gcur, g0);
      errors = errors + 1;
    end

    @(posedge clk); #1; gexp = next_rot(gexp); gcur = gnt;
    if (gcur !== gexp) begin
      $display("ERR: rotation step5 expected %b, got %b (start %b)", gexp, gcur, g0);
      errors = errors + 1;
    end

    // ---------------------------------------------------------
    // 4) Blocked by outbuf_full — gnt must be 0 and POINTER HOLDS.
    //     After unblocking, the SAME grant should appear again,
    //     then advance on the next posedge.
    // ---------------------------------------------------------
    // Take the current grant as the "last real grant" before blocking:
    
    g_last = gnt;  // whatever the current rotation point is now

    @(negedge clk);
    outbuf_full = 1'b1;
    #1;
    if (gnt !== 5'b00000) begin
      $display("ERR: gnt not zero when outbuf_full=1 (gnt=%b)", gnt);
      errors = errors + 1;
    end

    @(posedge clk); #1; // pointer must NOT advance here
    outbuf_full = 1'b0; #1;

    // Right after unblock (same cycle), we should see the SAME grant again
    if (gnt !== g_last) begin
      $display("ERR: pointer did not hold across block/unblock (expected %b, got %b)", g_last, gnt);
      errors = errors + 1;
    end

    // On the next posedge, pointer should advance to the next in rotation
    @(posedge clk); #1;
    if (gnt !== next_rot(g_last)) begin
      $display("ERR: did not advance to next after unblock (expected %b, got %b)", next_rot(g_last), gnt);
      errors = errors + 1;
    end

    // ---------------------------------------------------------
    // Done
    // ---------------------------------------------------------
    if (errors == 0)
      $display("TB RESULT: PASS");
    else
      $display("TB RESULT: FAIL (%0d errors)", errors);

    $finish;
  end
endmodule
