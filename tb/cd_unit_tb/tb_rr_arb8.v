`timescale 1ns/1ps
module tb_rr_arb8;

  reg        clk, reset;
  reg  [7:0] req;
  reg        en;
  wire [7:0] gnt;

  rr_arb8 dut (.clk(clk), .reset(reset), .req(req), .en(en), .gnt(gnt));

  // clock
  initial begin clk=1'b0; forever #5 clk=~clk; end

  // one-hot helper (no loops)
  function [7:0] oh8;
    input [2:0] idx;
    begin
      oh8 = (idx==3'd0) ? 8'b0000_0001 :
            (idx==3'd1) ? 8'b0000_0010 :
            (idx==3'd2) ? 8'b0000_0100 :
            (idx==3'd3) ? 8'b0000_1000 :
            (idx==3'd4) ? 8'b0001_0000 :
            (idx==3'd5) ? 8'b0010_0000 :
            (idx==3'd6) ? 8'b0100_0000 :
                           8'b1000_0000;
    end
  endfunction

  // shadow pointer tracking dut.ptr (starts at 0 after reset)
  reg [2:0] exp_ptr;
  reg [2:0] exp_ptr_hold;

  // check current grant equals oh8(exp_ptr) BEFORE ptr advances
  task check_fair_once;
    begin
      #1; // settle combinational
      if (gnt!==oh8(exp_ptr))
        $display("[ERR] RR exp=%b got=%b (ptr=%0d)", oh8(exp_ptr), gnt, exp_ptr);
      @(posedge clk); // now ptr advances in DUT
      exp_ptr = (exp_ptr==3'd7) ? 3'd0 : (exp_ptr + 3'd1);
    end
  endtask

  initial begin
    $dumpfile("tb_rr_arb8.vcd");
    $dumpvars(0, tb_rr_arb8);

    // ===== Global reset =====
    reset=1'b1; en=1'b0; req=8'h00; exp_ptr=3'd0;
    repeat(3) @(posedge clk);
    reset=1'b0;

    // ---------------- Test A: walking single request ----------------
    en = 1'b1;

    // For one-hot req, grant should equal req regardless of ptr.
    req = 8'b0000_0001; #1; if (gnt!==req) $display("[ERR] walk idx0 gnt=%b", gnt); @(posedge clk);
    req = 8'b0000_0010; #1; if (gnt!==req) $display("[ERR] walk idx1 gnt=%b", gnt); @(posedge clk);
    req = 8'b0000_0100; #1; if (gnt!==req) $display("[ERR] walk idx2 gnt=%b", gnt); @(posedge clk);
    req = 8'b0000_1000; #1; if (gnt!==req) $display("[ERR] walk idx3 gnt=%b", gnt); @(posedge clk);
    req = 8'b0001_0000; #1; if (gnt!==req) $display("[ERR] walk idx4 gnt=%b", gnt); @(posedge clk);
    req = 8'b0010_0000; #1; if (gnt!==req) $display("[ERR] walk idx5 gnt=%b", gnt); @(posedge clk);
    req = 8'b0100_0000; #1; if (gnt!==req) $display("[ERR] walk idx6 gnt=%b", gnt); @(posedge clk);
    req = 8'b1000_0000; #1; if (gnt!==req) $display("[ERR] walk idx7 gnt=%b", gnt); @(posedge clk);

    // ===== Reset between tests so ptr=0 again =====
    en = 1'b0; req = 8'h00;
    reset = 1'b1; @(posedge clk); @(posedge clk);
    reset = 1'b0;
    exp_ptr = 3'd0;

    // ---------------- Test B: all-ones fairness (combinational sample) ------
    en  = 1'b1;
    req = 8'hFF;

    // sample BEFORE ptr advances, then tick clock to advance
    check_fair_once; // expect 0
    check_fair_once; // expect 1
    check_fair_once; // expect 2
    check_fair_once; // expect 3
    check_fair_once; // expect 4
    check_fair_once; // expect 5
    check_fair_once; // expect 6
    check_fair_once; // expect 7
    check_fair_once; // wrap -> 0
    check_fair_once; // -> 1

    // ---------------- Test C: en gating (clean reset first) --------------
    en = 1'b0; req = 8'h00;
    reset = 1'b1; @(posedge clk); @(posedge clk); reset = 1'b0;

    // Hold req=FF but en=0 → gnt must be 0; ptr must not advance
    req = 8'hFF; en = 1'b0;
    #1; if (gnt!==8'b0) $display("[ERR] C0 gnt under en=0");
    @(posedge clk);
    #1; if (gnt!==8'b0) $display("[ERR] C1 gnt under en=0");
    @(posedge clk);
    #1; if (gnt!==8'b0) $display("[ERR] C2 gnt under en=0");

    // Now enable; since ptr reset to 0, first grant must be index 0
    en = 1'b1;
    #1; if (gnt!==8'b0000_0001) $display("[ERR] C3 exp=00000001 got=%b", gnt);
    @(posedge clk);


    $display("[PASS] rr_arb8 basic tests passed.");
    $finish;
  end

endmodule
