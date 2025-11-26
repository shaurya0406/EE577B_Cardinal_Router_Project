// //======================================================================
// // rr_arb8.v — 8-way round-robin arbiter (no integer/int, no loops)
// // - Rotate-by-ptr (3 bits), LSB-first priority pick, rotate back
// // - Pointer advances to slot after winner when en=1 and a request is present
// //======================================================================
// `timescale 1ns/1ps
// `ifndef RR_ARB8_V
// `define RR_ARB8_V

// module rr_arb8
// (
//   input  wire        clk,
//   input  wire        reset,
//   input  wire [7:0]  req,   // request vector
//   input  wire        en,    // enable arbitration this cycle
//   output wire [7:0]  gnt    // one-hot grant
// );

//   // next-start pointer (3-bit wraps mod 8)
//   reg [2:0] ptr;

//   // -------- Rotate requests by ptr (unrolled)
//   wire [7:0] req_rot_0 = req;
//   wire [7:0] req_rot_1 = {req[6:0], req[7]};
//   wire [7:0] req_rot_2 = {req[5:0], req[7:6]};
//   wire [7:0] req_rot_3 = {req[4:0], req[7:5]};
//   wire [7:0] req_rot_4 = {req[3:0], req[7:4]};
//   wire [7:0] req_rot_5 = {req[2:0], req[7:3]};
//   wire [7:0] req_rot_6 = {req[1:0], req[7:2]};
//   wire [7:0] req_rot_7 = {req[0],   req[7:1]};

//   wire [7:0] req_rot = (ptr==3'd0) ? req_rot_0 :
//                        (ptr==3'd1) ? req_rot_1 :
//                        (ptr==3'd2) ? req_rot_2 :
//                        (ptr==3'd3) ? req_rot_3 :
//                        (ptr==3'd4) ? req_rot_4 :
//                        (ptr==3'd5) ? req_rot_5 :
//                        (ptr==3'd6) ? req_rot_6 : req_rot_7;

//   // -------- Priority encode (LSB-first) on rotated requests
//   wire [7:0] gnt_rot =
//       (req_rot[0]) ? 8'b0000_0001 :
//       (req_rot[1]) ? 8'b0000_0010 :
//       (req_rot[2]) ? 8'b0000_0100 :
//       (req_rot[3]) ? 8'b0000_1000 :
//       (req_rot[4]) ? 8'b0001_0000 :
//       (req_rot[5]) ? 8'b0010_0000 :
//       (req_rot[6]) ? 8'b0100_0000 :
//       (req_rot[7]) ? 8'b1000_0000 :
//                      8'b0000_0000;

//   // -------- Rotate grant back by ptr (unrolled)
//   wire [7:0] gnt_bk_0 = gnt_rot;
//   wire [7:0] gnt_bk_1 = {gnt_rot[6:0], gnt_rot[7]};
//   wire [7:0] gnt_bk_2 = {gnt_rot[5:0], gnt_rot[7:6]};
//   wire [7:0] gnt_bk_3 = {gnt_rot[4:0], gnt_rot[7:5]};
//   wire [7:0] gnt_bk_4 = {gnt_rot[3:0], gnt_rot[7:4]};
//   wire [7:0] gnt_bk_5 = {gnt_rot[2:0], gnt_rot[7:3]};
//   wire [7:0] gnt_bk_6 = {gnt_rot[1:0], gnt_rot[7:2]};
//   wire [7:0] gnt_bk_7 = {gnt_rot[0],   gnt_rot[7:1]};

//   wire [7:0] gnt_pre = (ptr==3'd0) ? gnt_bk_0 :
//                        (ptr==3'd1) ? gnt_bk_1 :
//                        (ptr==3'd2) ? gnt_bk_2 :
//                        (ptr==3'd3) ? gnt_bk_3 :
//                        (ptr==3'd4) ? gnt_bk_4 :
//                        (ptr==3'd5) ? gnt_bk_5 :
//                        (ptr==3'd6) ? gnt_bk_6 : gnt_bk_7;

//   assign gnt = en ? gnt_pre : 8'b0000_0000;

//   // -------- Winner index in rotated domain (for ptr advance)
//   wire [2:0] win_idx_rot =
//       gnt_rot[0] ? 3'd0 :
//       gnt_rot[1] ? 3'd1 :
//       gnt_rot[2] ? 3'd2 :
//       gnt_rot[3] ? 3'd3 :
//       gnt_rot[4] ? 3'd4 :
//       gnt_rot[5] ? 3'd5 :
//       gnt_rot[6] ? 3'd6 :
//       gnt_rot[7] ? 3'd7 : 3'd0;

//   wire       has_win = |gnt_pre;
//   wire [2:0] ptr_inc = ptr + win_idx_rot + 3'd1; // wraps mod 8 naturally on 3 bits

//   always @(posedge clk) begin
//     if (reset) begin
//       ptr <= 3'd0;
//     end else if (en && has_win) begin
//       ptr <= ptr_inc;
//     end
//   end

// endmodule
// `endif




//======================================================================
// rr_arb8.v — 8-way round-robin (no loops, no integers, no rotates)
// - 8 fixed priority chains, one per ptr
// - ptr updates to (granted_index + 1) mod 8
//======================================================================
`timescale 1ns/1ps
`ifndef RR_ARB8_V
`define RR_ARB8_V
module rr_arb8(
  input  wire        clk,
  input  wire        reset,
  input  wire [7:0]  req,
  input  wire        en,
  output wire [7:0]  gnt
);
  reg [2:0] ptr;

  // priority chains for each ptr value (scan order indicated in comments)
  wire [7:0] g0 = req[0] ? 8'b0000_0001 :
                  req[1] ? 8'b0000_0010 :
                  req[2] ? 8'b0000_0100 :
                  req[3] ? 8'b0000_1000 :
                  req[4] ? 8'b0001_0000 :
                  req[5] ? 8'b0010_0000 :
                  req[6] ? 8'b0100_0000 :
                  req[7] ? 8'b1000_0000 : 8'b0; // 0,1,2,3,4,5,6,7

  wire [7:0] g1 = req[1] ? 8'b0000_0010 :
                  req[2] ? 8'b0000_0100 :
                  req[3] ? 8'b0000_1000 :
                  req[4] ? 8'b0001_0000 :
                  req[5] ? 8'b0010_0000 :
                  req[6] ? 8'b0100_0000 :
                  req[7] ? 8'b1000_0000 :
                  req[0] ? 8'b0000_0001 : 8'b0; // 1,2,3,4,5,6,7,0

  wire [7:0] g2 = req[2] ? 8'b0000_0100 :
                  req[3] ? 8'b0000_1000 :
                  req[4] ? 8'b0001_0000 :
                  req[5] ? 8'b0010_0000 :
                  req[6] ? 8'b0100_0000 :
                  req[7] ? 8'b1000_0000 :
                  req[0] ? 8'b0000_0001 :
                  req[1] ? 8'b0000_0010 : 8'b0; // 2,3,4,5,6,7,0,1

  wire [7:0] g3 = req[3] ? 8'b0000_1000 :
                  req[4] ? 8'b0001_0000 :
                  req[5] ? 8'b0010_0000 :
                  req[6] ? 8'b0100_0000 :
                  req[7] ? 8'b1000_0000 :
                  req[0] ? 8'b0000_0001 :
                  req[1] ? 8'b0000_0010 :
                  req[2] ? 8'b0000_0100 : 8'b0; // 3,4,5,6,7,0,1,2

  wire [7:0] g4 = req[4] ? 8'b0001_0000 :
                  req[5] ? 8'b0010_0000 :
                  req[6] ? 8'b0100_0000 :
                  req[7] ? 8'b1000_0000 :
                  req[0] ? 8'b0000_0001 :
                  req[1] ? 8'b0000_0010 :
                  req[2] ? 8'b0000_0100 :
                  req[3] ? 8'b0000_1000 : 8'b0; // 4,5,6,7,0,1,2,3

  wire [7:0] g5 = req[5] ? 8'b0010_0000 :
                  req[6] ? 8'b0100_0000 :
                  req[7] ? 8'b1000_0000 :
                  req[0] ? 8'b0000_0001 :
                  req[1] ? 8'b0000_0010 :
                  req[2] ? 8'b0000_0100 :
                  req[3] ? 8'b0000_1000 :
                  req[4] ? 8'b0001_0000 : 8'b0; // 5,6,7,0,1,2,3,4

  wire [7:0] g6 = req[6] ? 8'b0100_0000 :
                  req[7] ? 8'b1000_0000 :
                  req[0] ? 8'b0000_0001 :
                  req[1] ? 8'b0000_0010 :
                  req[2] ? 8'b0000_0100 :
                  req[3] ? 8'b0000_1000 :
                  req[4] ? 8'b0001_0000 :
                  req[5] ? 8'b0010_0000 : 8'b0; // 6,7,0,1,2,3,4,5

  wire [7:0] g7 = req[7] ? 8'b1000_0000 :
                  req[0] ? 8'b0000_0001 :
                  req[1] ? 8'b0000_0010 :
                  req[2] ? 8'b0000_0100 :
                  req[3] ? 8'b0000_1000 :
                  req[4] ? 8'b0001_0000 :
                  req[5] ? 8'b0010_0000 :
                  req[6] ? 8'b0100_0000 : 8'b0; // 7,0,1,2,3,4,5,6

  wire [7:0] gsel = (ptr==3'd0) ? g0 :
                    (ptr==3'd1) ? g1 :
                    (ptr==3'd2) ? g2 :
                    (ptr==3'd3) ? g3 :
                    (ptr==3'd4) ? g4 :
                    (ptr==3'd5) ? g5 :
                    (ptr==3'd6) ? g6 : g7;

  assign gnt = en ? gsel : 8'b0;

  // next ptr = (granted_index + 1) mod 8
  wire [2:0] nxt =
      gsel[0] ? 3'd1 :
      gsel[1] ? 3'd2 :
      gsel[2] ? 3'd3 :
      gsel[3] ? 3'd4 :
      gsel[4] ? 3'd5 :
      gsel[5] ? 3'd6 :
      gsel[6] ? 3'd7 :
      gsel[7] ? 3'd0 : ptr;

  wire has_win = |gsel;

  always @(posedge clk) begin
    if (reset) begin
      ptr <= 3'd0;
    end else if (en && has_win) begin
      ptr <= nxt;
    end
  end
endmodule
`endif
