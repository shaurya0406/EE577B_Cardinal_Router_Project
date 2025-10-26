// inbuf_cell_tb.v
`timescale 1ns/1ps
module inbuf_cell_tb;
  reg clk, reset;
  reg si;
  wire ri;
  reg [63:0] di;
  reg phase_ext, phase_int;
  reg deq;
  wire full;
  wire [63:0] q;

  inbuf_cell dut (
    .clk(clk), .reset(reset),
    .si(si), .ri(ri), .di(di),
    .phase_external(phase_ext),
    .phase_internal(phase_int),
    .deq(deq),
    .full(full), .q(q)
  );

  initial begin clk=0; forever #5 clk=~clk; end

  integer errors;
  initial begin
    errors=0; si=0; di=64'h0; deq=0; phase_ext=0; phase_int=0;
    reset=1; repeat(2) @(posedge clk); reset=0;

    // External phase active: should expose ri=1 when empty
    phase_ext=1; phase_int=0;
    @(negedge clk);
    if (ri!==1) begin $display("ERR: ri should be 1 when empty in external phase"); errors=errors+1; end

    // Handshake receive
    di=64'hDEADBEEF_F0F0A5A5; si=1;
    @(posedge clk); // capture
    si=0;
    if (full!==1 || q!==64'hDEADBEEF_F0F0A5A5) begin
      $display("ERR: did not capture flit"); errors=errors+1;
    end
    if (ri!==0) begin $display("ERR: ri should go 0 when full"); errors=errors+1; end

    // Internal phase: pop
    phase_ext=0; phase_int=1; deq=1;
    @(posedge clk);
    deq=0;
    if (full!==1'b0) begin $display("ERR: did not dequeue"); errors=errors+1; end

    #1;
    if (errors==0) $display("TB RESULT: PASS");
    else           $display("TB RESULT: FAIL (%0d errors)", errors);
    $finish;
  end
endmodule
