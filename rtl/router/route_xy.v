// route_xy.v
module route_xy (
  input  wire       dx,      // 0=+X(E), 1=-X(W)
  input  wire       dy,      // 0=+Y(N), 1=-Y(S)
  input  wire [3:0] hx,
  input  wire [3:0] hy,
  output wire       req_n,
  output wire       req_s,
  output wire       req_e,
  output wire       req_w,
  output wire       req_pe,
  output wire       shift_x,
  output wire       shift_y,
  output wire [3:0] hx_next,
  output wire [3:0] hy_next
);
  wire hx_zero = (hx==4'b0000);
  wire hy_zero = (hy==4'b0000);

  assign req_e   = (~hx_zero) & (dx==1'b0);
  assign req_w   = (~hx_zero) & (dx==1'b1);
  assign req_n   = ( hx_zero) & (~hy_zero) & (dy==1'b0);
  assign req_s   = ( hx_zero) & (~hy_zero) & (dy==1'b1);
  assign req_pe  = ( hx_zero) & ( hy_zero);

  assign shift_x = (~hx_zero);
  assign shift_y = ( hx_zero) & (~hy_zero);

  assign hx_next = shift_x ? {1'b0, hx[3:1]} : hx;
  assign hy_next = shift_y ? {1'b0, hy[3:1]} : hy;
endmodule
