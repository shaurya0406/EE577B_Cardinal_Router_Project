`timescale 1ns/1ps
module mesh_tb;
  reg clk=0, reset=1;
  always #5 clk = ~clk;
  initial begin
    repeat (2) @(posedge clk);
    reset = 0;
    repeat (50) @(posedge clk);
    $finish;
  end
  cardinal_router_mesh_xy #(.NX(2), .NY(2)) dut(.clk(clk), .reset(reset));
endmodule
