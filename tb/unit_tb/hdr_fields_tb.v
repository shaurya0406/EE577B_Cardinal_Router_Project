// tb_hdr_fields.v
`timescale 1ns/1ps
module tb_hdr_fields;
  reg  [63:0] pkt;
  wire vc, dx, dy;
  wire [4:0] rsv;
  wire [3:0] hx, hy;
  wire [7:0] srcx, srcy;

  hdr_fields dut (.pkt(pkt), .vc(vc), .dx(dx), .dy(dy), .rsv(rsv), .hx(hx), .hy(hy), .srcx(srcx), .srcy(srcy));

  integer errors;
  initial begin
    errors=0;
    // VC=1, Dx=0, Dy=0, Rsv=5'b01010, Hx=4'b0011, Hy=4'b0011, SrcX=8'h01, SrcY=8'h01
    pkt = {1'b1,1'b0,1'b0,5'b01010,4'b0011,4'b0011,8'h01,8'h01,32'hDEAD_BEEF};
    #1;
    if (vc!==1 || dx!==0 || dy!==0) begin $display("ERR: vc/dx/dy wrong"); errors=errors+1; end
    if (rsv!==5'b01010) begin $display("ERR: rsv wrong"); errors=errors+1; end
    if (hx!==4'b0011 || hy!==4'b0011) begin $display("ERR: hx/hy wrong"); errors=errors+1; end
    if (srcx!==8'h01 || srcy!==8'h01) begin $display("ERR: src wrong"); errors=errors+1; end

    if (errors==0) $display("TB RESULT: PASS");
    else           $display("TB RESULT: FAIL (%0d)", errors);
    $finish;
  end
endmodule
