// route_xy_tb.v
`timescale 1ns/1ps
module route_xy_tb;
  reg dx, dy;
  reg [3:0] hx, hy;
  wire req_n, req_s, req_e, req_w, req_pe;
  wire shift_x, shift_y;
  wire [3:0] hx_next, hy_next;

  route_xy dut (
    .dx(dx), .dy(dy), .hx(hx), .hy(hy),
    .req_n(req_n), .req_s(req_s), .req_e(req_e), .req_w(req_w), .req_pe(req_pe),
    .shift_x(shift_x), .shift_y(shift_y), .hx_next(hx_next), .hy_next(hy_next)
  );

  integer errors;
  initial begin
    errors=0;

    // Case 1: hx=0011 (2 hops X), hy=0011; dx=0 => go East, shift X
    dx=0; dy=0; hx=4'b0011; hy=4'b0011; #1;
    if (!(req_e==1 && shift_x==1 && hx_next==4'b0001 && hy_next==hy)) begin
      $display("ERR: Case1"); errors=errors+1;
    end

    // Case 2: hx=0000, hy=0011; dy=0 => go North, shift Y
    dx=0; dy=0; hx=4'b0000; hy=4'b0011; #1;
    if (!(req_n==1 && shift_y==1 && hy_next==4'b0001 && hx_next==hx)) begin
      $display("ERR: Case2"); errors=errors+1;
    end

    // Case 3: hx=0, hy=0 => PE
    dx=0; dy=0; hx=4'b0000; hy=4'b0000; #1;
    if (!(req_pe==1 && shift_x==0 && shift_y==0)) begin
      $display("ERR: Case3"); errors=errors+1;
    end

    // Case 4: dx=1 and hx!=0 => go West // TODO: 
    dx=1; dy=0; hx=4'b0100; hy=4'b0001; #1;
    if (!(req_w==1 && shift_x==1 && hx_next==4'b0010)) begin
      $display("ERR: Case4"); errors=errors+1;
    end

    if (errors==0) $display("TB RESULT: PASS");
    else           $display("TB RESULT: FAIL (%0d)", errors);
    $finish;
  end
endmodule
