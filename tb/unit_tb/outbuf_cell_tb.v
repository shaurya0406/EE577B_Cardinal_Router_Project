// outbuf_cell_tb.v
`timescale 1ns/1ps
module outbuf_cell_tb;
  reg clk, reset;
  reg enq;
  reg [63:0] d_in;
  reg phase_int, phase_ext;
  wire so;
  reg ro;
  wire [63:0] do;
  wire full;
  wire [63:0] q;

  outbuf_cell dut (
    .clk(clk), .reset(reset),
    .enq(enq), .d_in(d_in), .phase_internal(phase_int),
    .so(so), .ro(ro), .do(do), .phase_external(phase_ext),
    .full(full), .q(q)
  );

  initial begin clk=0; forever #5 clk=~clk; end

  integer errors;
  initial begin
    errors=0; enq=0; d_in=64'h0; phase_int=0; phase_ext=0; ro=0;
    reset=1; repeat(2) @(posedge clk); reset=0;

    // Enqueue on internal phase
    phase_int=1; d_in=64'hABCD_EF01_2345_6789; enq=1;
    @(posedge clk);
    enq=0; phase_int=0;
    if (full!==1 || q!==64'hABCD_EF01_2345_6789) begin
      $display("ERR: enqueue failed"); errors=errors+1;
    end

    // External phase but ro=0 => no send
    phase_ext=1; ro=0;
    @(negedge clk);
    if (so!==1'b0) begin $display("ERR: so should be 0 when ro=0"); errors=errors+1; end

    // Now allow send
    ro=1;
    @(negedge clk);
    if (so!==1'b1 || do!==64'hABCD_EF01_2345_6789) begin
      $display("ERR: send gating wrong"); errors=errors+1;
    end
    @(posedge clk); // consume here
    if (full!==1'b0) begin $display("ERR: did not clear after send"); errors=errors+1; end

    #1;
    if (errors==0) $display("TB RESULT: PASS");
    else           $display("TB RESULT: FAIL (%0d)", errors);
    $finish;
  end
endmodule
