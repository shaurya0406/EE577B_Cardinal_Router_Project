`timescale 1ns/1ps
module cardinal_router_mesh_xy #(
  parameter integer NX = 2,
  parameter integer NY = 2
)(
  input  wire clk,
  input  wire reset
  // TODO: expose NIC/router ports for edges
);
// TODO: instantiate a grid of router nodes and wire links
endmodule
