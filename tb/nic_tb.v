`timescale 1ns/1ps
module nic_tb;
  reg clk=0, reset=1;
  always #5 clk = ~clk;
  initial begin
    repeat (2) @(posedge clk);
    reset = 0;
    repeat (20) @(posedge clk);
    $finish;
  end
  cardinal_nic dut(.clk(clk), .reset(reset));
endmodule
