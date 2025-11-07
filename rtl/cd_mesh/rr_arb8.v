//======================================================================
// rr_arb8.v — 8-way round-robin arbiter (no ints/loops)
// - rotate by ptr (3 bits), PE, rotate back
//======================================================================
`timescale 1ns/1ps
`ifndef RR_ARB8_V
`define RR_ARB8_V

module rr_arb8
(
  input  wire        clk,
  input  wire        reset,
  input  wire [7:0]  req,
  input  wire        en,
  output wire [7:0]  gnt
);
  reg [2:0] ptr;

  // rotate request by ptr (pre-compute 8 rotations)
  wire [7:0] r0 = req;
  wire [7:0] r1 = {req[6:0], req[7]};
  wire [7:0] r2 = {req[5:0], req[7:6]};
  wire [7:0] r3 = {req[4:0], req[7:5]};
  wire [7:0] r4 = {req[3:0], req[7:4]};
  wire [7:0] r5 = {req[2:0], req[7:3]};
  wire [7:0] r6 = {req[1:0], req[7:2]};
  wire [7:0] r7 = {req[0],   req[7:1]};
  wire [7:0] req_rot = (ptr==3'd0)?r0:(ptr==3'd1)?r1:(ptr==3'd2)?r2:(ptr==3'd3)?r3:
                       (ptr==3'd4)?r4:(ptr==3'd5)?r5:(ptr==3'd6)?r6:r7;

  // priority encode (bit0 highest)
  wire [7:0] g_rot = req_rot[0] ? 8'b0000_0001 :
                     req_rot[1] ? 8'b0000_0010 :
                     req_rot[2] ? 8'b0000_0100 :
                     req_rot[3] ? 8'b0000_1000 :
                     req_rot[4] ? 8'b0001_0000 :
                     req_rot[5] ? 8'b0010_0000 :
                     req_rot[6] ? 8'b0100_0000 :
                     req_rot[7] ? 8'b1000_0000 : 8'b0000_0000;

  // rotate grant back by ptr
  wire [7:0] b0 = g_rot;
  wire [7:0] b1 = {g_rot[6:0], g_rot[7]};
  wire [7:0] b2 = {g_rot[5:0], g_rot[7:6]};
  wire [7:0] b3 = {g_rot[4:0], g_rot[7:5]};
  wire [7:0] b4 = {g_rot[3:0], g_rot[7:4]};
  wire [7:0] b5 = {g_rot[2:0], g_rot[7:3]};
  wire [7:0] b6 = {g_rot[1:0], g_rot[7:2]};
  wire [7:0] b7 = {g_rot[0],   g_rot[7:1]};
  wire [7:0] g_pre = (ptr==3'd0)?b0:(ptr==3'd1)?b1:(ptr==3'd2)?b2:(ptr==3'd3)?b3:
                     (ptr==3'd4)?b4:(ptr==3'd5)?b5:(ptr==3'd6)?b6:b7;

  assign gnt = en ? g_pre : 8'b0;

  // pointer advance to slot after winner (in rotated idx)
  wire [2:0] win_idx_rot = g_rot[0]?3'd0:g_rot[1]?3'd1:g_rot[2]?3'd2:g_rot[3]?3'd3:
                           g_rot[4]?3'd4:g_rot[5]?3'd5:g_rot[6]?3'd6:g_rot[7]?3'd7:3'd0;
  wire has_win = |g_pre;
  wire [3:0] ptr_inc = {1'b0,ptr} + {1'b0,win_idx_rot} + 4'd1; // 4-bit add
  wire [2:0] ptr_next = (ptr_inc[3]) ? ptr_inc[2:0] : ptr_inc[2:0]; // natural wrap mod 8

  always @(posedge clk) begin
    if (reset) ptr <= 3'd0;
    else if (en && has_win) ptr <= ptr_next;
  end

endmodule
`endif
