// // rr_arb_5.v
// // Plain-Verilog 5-way rotating arbiter
// // - No loops, no modulo, no SystemVerilog
// // - One-hot grant; rotates start priority after a grant
// module rr_arb_5 (
//   input  wire       clk,
//   input  wire       reset,        // active-high synchronous
//   input  wire [4:0] req,          // [4]=N, [3]=S, [2]=E, [1]=W, [0]=PE
//   input  wire       outbuf_full,  // when 1: block grants
//   output reg  [4:0] gnt           // one-hot grant
// );
//   reg [2:0] ptr;       // 0..4 start position
//   reg [4:0] gnt_next;
//   reg [2:0] ptr_next;

//   // Combinational grant + next pointer
//   always @* begin
//     gnt_next = 5'b00000;
//     ptr_next = ptr;

//     if (!outbuf_full) begin
//       case (ptr)
//         3'd0: begin
//           // N,S,E,W,PE
//           if (req[4])      begin gnt_next = 5'b10000; ptr_next = 3'd1; end
//           else if (req[3]) begin gnt_next = 5'b01000; ptr_next = 3'd2; end
//           else if (req[2]) begin gnt_next = 5'b00100; ptr_next = 3'd3; end
//           else if (req[1]) begin gnt_next = 5'b00010; ptr_next = 3'd4; end
//           else if (req[0]) begin gnt_next = 5'b00001; ptr_next = 3'd0; end
//         end
//         3'd1: begin
//           // S,E,W,PE,N
//           if (req[3])      begin gnt_next = 5'b01000; ptr_next = 3'd2; end
//           else if (req[2]) begin gnt_next = 5'b00100; ptr_next = 3'd3; end
//           else if (req[1]) begin gnt_next = 5'b00010; ptr_next = 3'd4; end
//           else if (req[0]) begin gnt_next = 5'b00001; ptr_next = 3'd0; end
//           else if (req[4]) begin gnt_next = 5'b10000; ptr_next = 3'd1; end
//         end
//         3'd2: begin
//           // E,W,PE,N,S
//           if (req[2])      begin gnt_next = 5'b00100; ptr_next = 3'd3; end
//           else if (req[1]) begin gnt_next = 5'b00010; ptr_next = 3'd4; end
//           else if (req[0]) begin gnt_next = 5'b00001; ptr_next = 3'd0; end
//           else if (req[4]) begin gnt_next = 5'b10000; ptr_next = 3'd1; end
//           else if (req[3]) begin gnt_next = 5'b01000; ptr_next = 3'd2; end
//         end
//         3'd3: begin
//           // W,PE,N,S,E
//           if (req[1])      begin gnt_next = 5'b00010; ptr_next = 3'd4; end
//           else if (req[0]) begin gnt_next = 5'b00001; ptr_next = 3'd0; end
//           else if (req[4]) begin gnt_next = 5'b10000; ptr_next = 3'd1; end
//           else if (req[3]) begin gnt_next = 5'b01000; ptr_next = 3'd2; end
//           else if (req[2]) begin gnt_next = 5'b00100; ptr_next = 3'd3; end
//         end
//         3'd4: begin
//           // PE,N,S,E,W
//           if (req[0])      begin gnt_next = 5'b00001; ptr_next = 3'd0; end
//           else if (req[4]) begin gnt_next = 5'b10000; ptr_next = 3'd1; end
//           else if (req[3]) begin gnt_next = 5'b01000; ptr_next = 3'd2; end
//           else if (req[2]) begin gnt_next = 5'b00100; ptr_next = 3'd3; end
//           else if (req[1]) begin gnt_next = 5'b00010; ptr_next = 3'd4; end
//         end
//         default: begin
//           gnt_next = 5'b00000;
//           ptr_next = 3'd0;
//         end
//       endcase
//     end
//   end

//   // Registers
//   always @(posedge clk) begin
//     if (reset) begin
//       gnt <= 5'b00000;
//       ptr <= 3'd0; // reset seed: start at N
//     end else begin
//       gnt <= gnt_next;
//       ptr <= ptr_next;
//     end
//   end
// endmodule




`timescale 1ns/1ps
// rr_arb_5.v
// 5-way rotating arbiter (plain Verilog, synth-safe)
// Mapping: req[4]=N, req[3]=S, req[2]=E, req[1]=W, req[0]=PE
module rr_arb_5 (
  input  wire       clk,
  input  wire       reset,        // active-high synchronous
  input  wire [4:0] req,
  input  wire       outbuf_full,  // 1 => block new grants
  output reg  [4:0] gnt           // one-hot grant; 1-cycle pulse
);

  // Rotation pointer (0..4) defines the "first" to check
  reg [2:0] ptr;         // 0:N, 1:S, 2:E, 3:W, 4:PE

  // Combinational next-grant based on ptr and req
  reg [4:0] gnt_next;
  reg [2:0] ptr_next;

  always @* begin
    // defaults
    gnt_next = 5'b00000;
    ptr_next = ptr;

    if (!outbuf_full) begin
      case (ptr)
        3'd0: begin // N,S,E,W,PE
          if (req[4])      begin gnt_next = 5'b10000; ptr_next = 3'd1; end
          else if (req[3]) begin gnt_next = 5'b01000; ptr_next = 3'd2; end
          else if (req[2]) begin gnt_next = 5'b00100; ptr_next = 3'd3; end
          else if (req[1]) begin gnt_next = 5'b00010; ptr_next = 3'd4; end
          else if (req[0]) begin gnt_next = 5'b00001; ptr_next = 3'd0; end
        end
        3'd1: begin // S,E,W,PE, N
          if (req[3])      begin gnt_next = 5'b01000; ptr_next = 3'd2; end
          else if (req[2]) begin gnt_next = 5'b00100; ptr_next = 3'd3; end
          else if (req[1]) begin gnt_next = 5'b00010; ptr_next = 3'd4; end
          else if (req[0]) begin gnt_next = 5'b00001; ptr_next = 3'd0; end
          else if (req[4]) begin gnt_next = 5'b10000; ptr_next = 3'd1; end
        end
        3'd2: begin // E,W,PE,N, S
          if (req[2])      begin gnt_next = 5'b00100; ptr_next = 3'd3; end
          else if (req[1]) begin gnt_next = 5'b00010; ptr_next = 3'd4; end
          else if (req[0]) begin gnt_next = 5'b00001; ptr_next = 3'd0; end
          else if (req[4]) begin gnt_next = 5'b10000; ptr_next = 3'd1; end
          else if (req[3]) begin gnt_next = 5'b01000; ptr_next = 3'd2; end
        end
        3'd3: begin // W,PE,N,S, E
          if (req[1])      begin gnt_next = 5'b00010; ptr_next = 3'd4; end
          else if (req[0]) begin gnt_next = 5'b00001; ptr_next = 3'd0; end
          else if (req[4]) begin gnt_next = 5'b10000; ptr_next = 3'd1; end
          else if (req[3]) begin gnt_next = 5'b01000; ptr_next = 3'd2; end
          else if (req[2]) begin gnt_next = 5'b00100; ptr_next = 3'd3; end
        end
        3'd4: begin // PE,N,S,E, W
          if (req[0])      begin gnt_next = 5'b00001; ptr_next = 3'd0; end
          else if (req[4]) begin gnt_next = 5'b10000; ptr_next = 3'd1; end
          else if (req[3]) begin gnt_next = 5'b01000; ptr_next = 3'd2; end
          else if (req[2]) begin gnt_next = 5'b00100; ptr_next = 3'd3; end
          else if (req[1]) begin gnt_next = 5'b00010; ptr_next = 3'd4; end
        end
        default: begin
          gnt_next = 5'b00000;
          ptr_next = 3'd0;
        end
      endcase
    end
  end

  // Registers: one-cycle pulse gnt; forcibly zero when blocked
  always @(posedge clk) begin
    if (reset) begin
      gnt <= 5'b00000;
      ptr <= 3'd0;  // seed at N
    end else begin
      if (outbuf_full) begin
        gnt <= 5'b00000; // no grant while blocked
        ptr <= ptr;      // don't advance pointer
      end else begin
        gnt <= gnt_next; // one-cycle pulse (or 0)
        // advance only if we actually granted someone
        if (gnt_next != 5'b00000) ptr <= ptr_next;
        else                      ptr <= ptr;
      end
    end
  end
endmodule
