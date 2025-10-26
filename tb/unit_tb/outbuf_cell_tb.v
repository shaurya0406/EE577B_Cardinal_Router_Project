`timescale 1ns/1ps
module outbuf_cell_tb;
  reg clk, reset;

  // DUT I/O
  reg        enq;
  reg [63:0] d_in;
  reg        phase_int;
  wire       so;
  reg        ro;
  wire [63:0] dout;      
  reg        phase_ext;
  wire       full;
  wire [63:0] q;

  // DUT
  outbuf_cell dut (
    .clk(clk), .reset(reset),
    .enq(enq), .d_in(d_in), .phase_internal(phase_int),
    .so(so), .ro(ro), .dout(dout), .phase_external(phase_ext),
    .full(full), .q(q)
  );

  // 100 MHz clock
  initial begin clk = 1'b0; forever #5 clk = ~clk; end

  // Waves
  initial begin
    $dumpfile("outbuf_cell_tb.vcd");
    $dumpvars(0, outbuf_cell_tb);
  end

  integer errors; initial errors=0;

  initial begin
    // Defaults
    reset=1;
    enq=0; d_in=64'h0;
    phase_int=0; phase_ext=0;
    ro=0;

    // Hold reset, settle
    repeat(2) @(posedge clk);
    reset=0;
    @(posedge clk); #2;

    // =========================
    // 1) Enqueue in INTERNAL phase
    // =========================
    phase_int = 1'b1;
    d_in      = 64'hABCD_EF01_2345_6789;
    enq       = 1'b1;                 // assert before posedge
    @(posedge clk);                   // capture into q/full here
    #2;
    enq       = 1'b0;
    phase_int = 1'b0;

    if (full !== 1'b1 || q !== 64'hABCD_EF01_2345_6789) begin
      $display("ERR: enqueue failed (full=%b q=%h)", full, q);
      errors = errors + 1;
    end

    // =========================
    // 2) EXTERNAL phase, ro=0  (no send)
    // =========================
    phase_ext = 1'b1;
    ro        = 1'b0;
    @(posedge clk); #2;
    // With spec gating: so = ext & full & ro -> 0; dout = 0
    if (so !== 1'b0 || dout !== 64'h0) begin
      $display("ERR: should be idle when ro=0 (so=%b dout=%h)", so, dout);
      errors = errors + 1;
    end

    // =========================
    // 3) Still EXTERNAL phase, now ro=1 (send happens)
    // =========================
    @(negedge clk);
    ro = 1'b1;       // combinationally raises 'so' and 'dout' now
    #1;              // tiny delta to observe Mealy outputs
    if (so !== 1'b1 || dout !== 64'hABCD_EF01_2345_6789) begin
      $display("ERR: send gating wrong (so=%b dout=%h)", so, dout);
      errors = errors + 1;
    end

    // Consume on next posedge, buffer clears
    @(posedge clk); #2;
    if (full !== 1'b0) begin
      $display("ERR: did not clear after send (full=%b)", full);
      errors = errors + 1;
    end
    if (so !== 1'b0) begin
      $display("ERR: so should drop after clearing");
      errors = errors + 1;
    end

    if (errors==0) $display("TB RESULT: PASS");
    else           $display("TB RESULT: FAIL (%0d)", errors);
    $finish;
  end
endmodule
