`timescale 1ns/1ps
module mesh_link #(
  parameter integer WIDTH = 64
)(
  input  wire             clk,
  input  wire             reset,
  input  wire [WIDTH-1:0] di,
  input  wire             si,
  output wire             ri,
  output wire [WIDTH-1:0] do,
  output wire             so,
  input  wire             ro
);
// TODO: simple 1-deep buffer placeholder
assign ri = 1'b1;
assign so = si & ro;
assign do = di;
endmodule
