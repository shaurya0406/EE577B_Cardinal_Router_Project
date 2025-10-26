// tb_rr_arb_5.v
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

  integer errors;
  integer i;

  initial begin
    errors = 0;
    req = 5'b00000;
    outbuf_full = 1'b0;

    reset = 1'b1;
    repeat(2) @(posedge clk);
    reset = 1'b0;

    // 1) No requests -> no grants
    @(posedge clk);
    if (gnt !== 5'b00000) begin
      $display("ERR: grant with no requests");
      errors = errors + 1;
    end

    // 2) Single requester (E)
    req = 5'b00100; // E only
    @(posedge clk);
    if (gnt !== 5'b00100) begin
      $display("ERR: single requester E not granted");
      errors = errors + 1;
    end

    // 3) All requesters high, watch rotation
    req = 5'b11111;
    // We expect 5 consecutive grants, each different (rotating)
    for (i=0; i<5; i=i+1) begin
      @(posedge clk);
      $display("t=%0t gnt=%b", $time, gnt);
      if (gnt == 5'b00000) begin
        $display("ERR: no grant under full requests");
        errors = errors + 1;
      end
    end

    // 4) Block by outbuf_full
    outbuf_full = 1'b1;
    @(posedge clk);
    if (gnt !== 5'b00000) begin
      $display("ERR: grant while outbuf_full=1");
      errors = errors + 1;
    end
    outbuf_full = 1'b0;

    // 5) Resume: should continue rotating
    @(posedge clk);
    if (gnt == 5'b00000) begin
      $display("ERR: no grant after unblocking");
      errors = errors + 1;
    end

    if (errors==0) $display("TB RESULT: PASS");
    else           $display("TB RESULT: FAIL (%0d errors)", errors);
    $finish;
  end
endmodule
