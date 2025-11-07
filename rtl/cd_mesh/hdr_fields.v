// hdr_fields.v
module hdr_fields (
  input  wire [63:0] pkt,
  output wire        vc,
  output wire        dx,
  output wire        dy,
  output wire [4:0]  rsv,
  output wire [3:0]  hx,
  output wire [3:0]  hy,
  output wire [7:0]  srcx,
  output wire [7:0]  srcy
);
  // Bit map (63..32): VC[63], Dx[62], Dy[61], Rsv[60:56], Hx[55:52], Hy[51:48], SrcX[47:40], SrcY[39:32]
  assign vc   = pkt[63];
  assign dx   = pkt[62];
  assign dy   = pkt[61];
  assign rsv  = pkt[60:56];
  assign hx   = pkt[55:52];
  assign hy   = pkt[51:48];
  assign srcx = pkt[47:40];
  assign srcy = pkt[39:32];
endmodule
