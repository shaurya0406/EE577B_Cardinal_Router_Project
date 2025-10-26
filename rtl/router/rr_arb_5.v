`timescale 1ns/1ps
// rr_arb_5.v — 5-way RR arbiter (combinational grant, registered pointer)
// req/gnt bit order: [4]=N, [3]=S, [2]=E, [1]=W, [0]=PE
module rr_arb_5 (
  input  wire       clk,
  input  wire       reset,        // active-high synchronous
  input  wire [4:0] req,
  input  wire       outbuf_full,  // 1 => block grants
  output wire [4:0] gnt           // combinational one-hot grant
);
  reg  [2:0] ptr;       // 0..4 rotation start (registered)
  reg  [4:0] gnt_c;     // comb grant

  // Combinational grant from current ptr and req (blocked if outbuf full)
  always @* begin
    gnt_c = 5'b00000;
    if (!outbuf_full) begin
      case (ptr)
        3'd0: begin // N,S,E,W,PE
          if (req[4])      gnt_c = 5'b10000;
          else if (req[3]) gnt_c = 5'b01000;
          else if (req[2]) gnt_c = 5'b00100;
          else if (req[1]) gnt_c = 5'b00010;
          else if (req[0]) gnt_c = 5'b00001;
        end
        3'd1: begin // S,E,W,PE,N
          if (req[3])      gnt_c = 5'b01000;
          else if (req[2]) gnt_c = 5'b00100;
          else if (req[1]) gnt_c = 5'b00010;
          else if (req[0]) gnt_c = 5'b00001;
          else if (req[4]) gnt_c = 5'b10000;
        end
        3'd2: begin // E,W,PE,N,S
          if (req[2])      gnt_c = 5'b00100;
          else if (req[1]) gnt_c = 5'b00010;
          else if (req[0]) gnt_c = 5'b00001;
          else if (req[4]) gnt_c = 5'b10000;
          else if (req[3]) gnt_c = 5'b01000;
        end
        3'd3: begin // W,PE,N,S,E
          if (req[1])      gnt_c = 5'b00010;
          else if (req[0]) gnt_c = 5'b00001;
          else if (req[4]) gnt_c = 5'b10000;
          else if (req[3]) gnt_c = 5'b01000;
          else if (req[2]) gnt_c = 5'b00100;
        end
        3'd4: begin // PE,N,S,E,W
          if (req[0])      gnt_c = 5'b00001;
          else if (req[4]) gnt_c = 5'b10000;
          else if (req[3]) gnt_c = 5'b01000;
          else if (req[2]) gnt_c = 5'b00100;
          else if (req[1]) gnt_c = 5'b00010;
        end
        default: gnt_c = 5'b00000;
      endcase
    end
  end

  // Registered rotation pointer: advance only on real grant
  always @(posedge clk) begin
    if (reset) begin
      ptr <= 3'd0; // seed at N
    end else begin
      if (gnt_c != 5'b00000) begin
        case (gnt_c)
          5'b10000: ptr <= 3'd1;
          5'b01000: ptr <= 3'd2;
          5'b00100: ptr <= 3'd3;
          5'b00010: ptr <= 3'd4;
          5'b00001: ptr <= 3'd0;
          default:  ptr <= ptr;
        endcase
      end
    end
  end

  assign gnt = gnt_c;
endmodule
