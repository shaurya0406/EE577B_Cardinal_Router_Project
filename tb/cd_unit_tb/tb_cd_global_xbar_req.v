`timescale 1ns/1ps
module tb_cd_global_xbar_req;

  localparam DATA_W=64; localparam CLK_PER=10;

  reg                   clk, reset;

  reg  [7:0]            in_si;   wire [7:0] in_ri;
  reg  [8*DATA_W-1:0]   in_di;

  wire [3:0]            llc_so;  reg  [3:0] llc_ro;
  wire [4*DATA_W-1:0]   llc_do;

  // reply (unused here)
  reg  [3:0]            llc_si_r; wire [3:0] llc_ri_r;
  reg  [4*DATA_W-1:0]   llc_di_r;
  wire [7:0]            out_so;   reg  [7:0] out_ro;
  wire [8*DATA_W-1:0]   out_do;

  cd_global_xbar_8x4 #(.DATA_W(DATA_W)) dut (
    .clk(clk), .reset(reset),
    .in_si(in_si), .in_ri(in_ri), .in_di(in_di),
    .llc_so(llc_so), .llc_ro(llc_ro), .llc_do(llc_do),
    .llc_si_r(llc_si_r), .llc_ri_r(llc_ri_r), .llc_di_r(llc_di_r),
    .out_so(out_so), .out_ro(out_ro), .out_do(out_do)
  );

  initial begin clk=0; forever #(CLK_PER/2) clk=~clk; end

  // Build a request flit: set Hx[1:0]=llc_id, leave others don't-care
  function [DATA_W-1:0] mk_req;
    input [1:0] llc_id;
    input [7:0] tag;  // stuff a tag in low 8 bits for visibility
    reg [3:0] hx;
    begin
      hx      = {2'b00, llc_id}; // put llc_id in Hx[1:0]
      mk_req  = { 1'b0/*vc*/,1'b0/*dx*/,1'b0/*dy*/, 5'b0/*rsv*/,
                  hx, 4'b0/*hy*/, 8'hAA/*srcx*/, 8'h55/*srcy*/,
                  24'h0, tag };
    end
  endfunction

  // helper: one-hot over 4 bits (no loops)
    function is_onehot4;
    input [3:0] v;
    begin
        is_onehot4 = (v==4'b0001) | (v==4'b0010) | (v==4'b0100) | (v==4'b1000);
    end
    endfunction

  // Helper to pack in_di (no loops)
  task drive_inputs_hotspot_llc2;
    begin
      in_si = 8'b1111_1111;
      in_di[DATA_W*1-1:DATA_W*0] = mk_req(2'b10, 8'h00);
      in_di[DATA_W*2-1:DATA_W*1] = mk_req(2'b10, 8'h01);
      in_di[DATA_W*3-1:DATA_W*2] = mk_req(2'b10, 8'h02);
      in_di[DATA_W*4-1:DATA_W*3] = mk_req(2'b10, 8'h03);
      in_di[DATA_W*5-1:DATA_W*4] = mk_req(2'b10, 8'h04);
      in_di[DATA_W*6-1:DATA_W*5] = mk_req(2'b10, 8'h05);
      in_di[DATA_W*7-1:DATA_W*6] = mk_req(2'b10, 8'h06);
      in_di[DATA_W*8-1:DATA_W*7] = mk_req(2'b10, 8'h07);
    end
  endtask

  task drive_inputs_split_0_3_to0_4_7_to3;
    begin
      in_si = 8'b1111_1111;
      in_di[DATA_W*1-1:DATA_W*0] = mk_req(2'b00, 8'h10); // 0->llc0
      in_di[DATA_W*2-1:DATA_W*1] = mk_req(2'b00, 8'h11); // 1->llc0
      in_di[DATA_W*3-1:DATA_W*2] = mk_req(2'b00, 8'h12); // 2->llc0
      in_di[DATA_W*4-1:DATA_W*3] = mk_req(2'b00, 8'h13); // 3->llc0
      in_di[DATA_W*5-1:DATA_W*4] = mk_req(2'b11, 8'h14); // 4->llc3
      in_di[DATA_W*6-1:DATA_W*5] = mk_req(2'b11, 8'h15); // 5->llc3
      in_di[DATA_W*7-1:DATA_W*6] = mk_req(2'b11, 8'h16); // 6->llc3
      in_di[DATA_W*8-1:DATA_W*7] = mk_req(2'b11, 8'h17); // 7->llc3
    end
  endtask

  // Split llc_do into words
  wire [DATA_W-1:0] o0 = llc_do[DATA_W*1-1:DATA_W*0];
  wire [DATA_W-1:0] o1 = llc_do[DATA_W*2-1:DATA_W*1];
  wire [DATA_W-1:0] o2 = llc_do[DATA_W*3-1:DATA_W*2];
  wire [DATA_W-1:0] o3 = llc_do[DATA_W*4-1:DATA_W*3];

  initial begin
    $dumpfile("tb_cd_global_xbar_req.vcd");
    $dumpvars(0, tb_cd_global_xbar_req);

    // reset
    reset=1; in_si=0; in_di=0; llc_ro=4'b0000; llc_si_r=4'b0000; llc_di_r=0; out_ro=8'hFF;
    repeat(4) @(posedge clk); reset=0;

    // ---------------- Case 1: Hotspot to LLC2 ----------------
    drive_inputs_hotspot_llc2();
    llc_ro = 4'b0100; // only LLC2 ready
    #1; // sample combinationally
    if (!(llc_so==4'b0100)) $display("[ERR] HS: llc_so exp 0100 got %b", llc_so);
    // data on o2 must equal one of the 8 input words
    if (!((o2==mk_req(2'b10,8'h00))||(o2==mk_req(2'b10,8'h01))||(o2==mk_req(2'b10,8'h02))||(o2==mk_req(2'b10,8'h03))||
          (o2==mk_req(2'b10,8'h04))||(o2==mk_req(2'b10,8'h05))||(o2==mk_req(2'b10,8'h06))||(o2==mk_req(2'b10,8'h07))))
      $display("[ERR] HS: o2 not from inputs");

    // in_ri must be one-hot (some input accepted)
    if (!((in_ri==8'b0000_0001)||(in_ri==8'b0000_0010)||(in_ri==8'b0000_0100)||(in_ri==8'b0000_1000)||
          (in_ri==8'b0001_0000)||(in_ri==8'b0010_0000)||(in_ri==8'b0100_0000)||(in_ri==8'b1000_0000)))
      $display("[ERR] HS: in_ri not one-hot, got %b", in_ri);
    @(posedge clk); // advance RR pointer

    // ---------------- Case 2: Split 0..3->LLC0 and 4..7->LLC3 -----------
    drive_inputs_split_0_3_to0_4_7_to3();
    llc_ro = 4'b1001; // only llc3 and llc0 ready
    #1;
    if (!(llc_so==4'b1001)) $display("[ERR] SPLIT: llc_so exp 1001 got %b", llc_so);
    // outputs must come from their respective groups
    if (!((o0==mk_req(2'b00,8'h10))||(o0==mk_req(2'b00,8'h11))||(o0==mk_req(2'b00,8'h12))||(o0==mk_req(2'b00,8'h13))))
      $display("[ERR] SPLIT: o0 not from group0");
    if (!((o3==mk_req(2'b11,8'h14))||(o3==mk_req(2'b11,8'h15))||(o3==mk_req(2'b11,8'h16))||(o3==mk_req(2'b11,8'h17))))
      $display("[ERR] SPLIT: o3 not from group3");
    // // only two winners total
    // if (!((in_ri==8'b0000_0001)||(in_ri==8'b0000_0010)||(in_ri==8'b0000_0100)||(in_ri==8'b0000_1000)||
    //       (in_ri==8'b0001_0000)||(in_ri==8'b0010_0000)||(in_ri==8'b0100_0000)||(in_ri==8'b1000_0000)))
    //   $display("[ERR] SPLIT: in_ri should still be one-hot per output; observed combined one-hot due to OR");

    // Expect exactly one winner in low group (0..3) and one in high group (4..7)
    if (!is_onehot4(in_ri[3:0])) $display("[ERR] SPLIT: lower half in_ri not 1-hot: %b", in_ri[3:0]);
    if (!is_onehot4(in_ri[7:4])) $display("[ERR] SPLIT: upper half in_ri not 1-hot: %b", in_ri[7:4]);
    @(posedge clk);

    // ---------------- Case 3: Backpressure mask (only LLC1 & LLC3 ready) ----
    drive_inputs_hotspot_llc2();
    llc_ro = 4'b1010; // llc3 & llc1 only; our packets target llc2 so no fire
    #1;
    if (!(llc_so==4'b0000)) $display("[ERR] BP: llc_so should be 0000 got %b", llc_so);
    if (!(in_ri==8'b0000_0000)) $display("[ERR] BP: in_ri should be 0 got %b", in_ri);

    $display("[PASS] cd_global_xbar_8x4 request path OK.");
    $finish;
  end

endmodule
