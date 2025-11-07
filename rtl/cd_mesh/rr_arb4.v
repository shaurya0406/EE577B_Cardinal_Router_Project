//======================================================================
// rr_arb4.v — 4-way round-robin arbiter (no loops, no integer/int)
// - Rotate by ptr (2 bits), priority-encode, rotate back
// - Gate by 'en'; pointer advances to slot after winner
//======================================================================
`timescale 1ns/1ps
`ifndef RR_ARB4_V
`define RR_ARB4_V

module rr_arb4
(
  input  wire        clk,
  input  wire        reset,
  input  wire [3:0]  req,   // requests
  input  wire        en,    // enable arbitration this cycle
  output wire [3:0]  gnt    // one-hot grant
);

  // pointer to next starting index (2 bits, wraps naturally)
  reg [1:0] ptr;

  // -------- rotate requests by ptr
  wire [3:0] req_rot_0 = req;
  wire [3:0] req_rot_1 = {req[2:0], req[3]};
  wire [3:0] req_rot_2 = {req[1:0], req[3:2]};
  wire [3:0] req_rot_3 = {req[0],   req[3:1]};
  wire [3:0] req_rot = (ptr==2'd0) ? req_rot_0 :
                       (ptr==2'd1) ? req_rot_1 :
                       (ptr==2'd2) ? req_rot_2 : req_rot_3;

  // -------- priority encode (LSB first) on rotated requests
  wire [3:0] gnt_rot =
      (req_rot[0]) ? 4'b0001 :
      (req_rot[1]) ? 4'b0010 :
      (req_rot[2]) ? 4'b0100 :
      (req_rot[3]) ? 4'b1000 :
                     4'b0000;

  // -------- rotate grant back by ptr
  wire [3:0] gnt_bk_0 = gnt_rot;
  wire [3:0] gnt_bk_1 = {gnt_rot[2:0], gnt_rot[3]};
  wire [3:0] gnt_bk_2 = {gnt_rot[1:0], gnt_rot[3:2]};
  wire [3:0] gnt_bk_3 = {gnt_rot[0],   gnt_rot[3:1]};
  wire [3:0] gnt_pre = (ptr==2'd0) ? gnt_bk_0 :
                       (ptr==2'd1) ? gnt_bk_1 :
                       (ptr==2'd2) ? gnt_bk_2 : gnt_bk_3;

  assign gnt = en ? gnt_pre : 4'b0000;

  // -------- winner index in rotated domain
  wire [1:0] win_idx_rot = (gnt_rot[0]) ? 2'd0 :
                           (gnt_rot[1]) ? 2'd1 :
                           (gnt_rot[2]) ? 2'd2 :
                           (gnt_rot[3]) ? 2'd3 : 2'd0;

  // -------- pointer update: ptr <- ptr + win_idx_rot + 1 (mod 4)
  wire has_win = |gnt_pre;
  wire [1:0] ptr_inc = ptr + win_idx_rot + 2'd1;

  always @(posedge clk) begin
    if (reset) begin
      ptr <= 2'd0;
    end else if (en && has_win) begin
      ptr <= ptr_inc;
    end
  end

endmodule
`endif
