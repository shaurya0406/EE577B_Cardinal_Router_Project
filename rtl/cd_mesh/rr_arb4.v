`timescale 1ns/1ps
`ifndef RR_ARB4_V
`define RR_ARB4_V
module rr_arb4(
  input  wire       clk, input wire reset,
  input  wire [3:0] req, input wire en,
  output wire [3:0] gnt
);
  reg [1:0] ptr;
  wire [3:0] req_rot = (ptr==2'd0)? req :
                       (ptr==2'd1)? {req[2:0],req[3]} :
                       (ptr==2'd2)? {req[1:0],req[3:2]} :
                                    {req[0],req[3:1]};
  wire [3:0] gnt_rot = req_rot[0]?4'b0001:
                       req_rot[1]?4'b0010:
                       req_rot[2]?4'b0100:
                       req_rot[3]?4'b1000:4'b0000;
  wire [3:0] g0 = gnt_rot;
  wire [3:0] g1 = {gnt_rot[2:0], gnt_rot[3]};
  wire [3:0] g2 = {gnt_rot[1:0], gnt_rot[3:2]};
  wire [3:0] g3 = {gnt_rot[0],   gnt_rot[3:1]};
  wire [3:0] g_pre = (ptr==2'd0)?g0:(ptr==2'd1)?g1:(ptr==2'd2)?g2:g3;
  assign gnt = en ? g_pre : 4'b0000;
  wire [1:0] win_idx_rot = gnt_rot[0]?2'd0:gnt_rot[1]?2'd1:gnt_rot[2]?2'd2:gnt_rot[3]?2'd3:2'd0;
  wire       has_win = |g_pre;
  wire [1:0] ptr_inc = ptr + win_idx_rot + 2'd1;
  always @(posedge clk) begin
    if (reset) ptr <= 2'd0;
    else if (en && has_win) ptr <= ptr_inc;
  end
endmodule
`endif
