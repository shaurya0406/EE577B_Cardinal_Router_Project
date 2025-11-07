`timescale 1ns/1ps

module tb_cd_local_xbar_4x2;

  localparam DATA_W  = 64;
  localparam CLK_PER = 10;

  reg                  clk, reset;

  reg  [3:0]           in_si;
  wire [3:0]           in_ri;
  reg  [4*DATA_W-1:0]  in_di;

  wire [1:0]           cv_so;
  reg  [1:0]           cv_ro;
  wire [2*DATA_W-1:0]  cv_do;

  reg  [1:0]           cv_si_r;
  wire [1:0]           cv_ri_r;
  reg  [2*DATA_W-1:0]  cv_di_r;

  wire [3:0]           out_so;
  reg  [3:0]           out_ro;
  wire [4*DATA_W-1:0]  out_do;

  // DUT
  cd_local_xbar_4x2 #(.DATA_W(DATA_W)) dut (
    .clk(clk), .reset(reset),
    .in_si(in_si), .in_ri(in_ri), .in_di(in_di),
    .cv_so(cv_so), .cv_ro(cv_ro), .cv_do(cv_do),
    .cv_si_r(cv_si_r), .cv_ri_r(cv_ri_r), .cv_di_r(cv_di_r),
    .out_so(out_so), .out_ro(out_ro), .out_do(out_do)
  );

  // Clock
  initial begin
    clk = 1'b0;
    forever #(CLK_PER/2) clk = ~clk;
  end

  // Word maker (unique tags per input)
  function [DATA_W-1:0] mk_word;
    input [7:0] src_id;
    input [7:0] cnt;
    begin
      mk_word = { 32'hF00DFACE, 8'h00, src_id, cnt };
    end
  endfunction

  // Per-input counters (8-bit is enough)
  reg [7:0] c0, c1, c2, c3;

  // Convenience wires for cv_do split
  wire [DATA_W-1:0] cv_do0 = cv_do[DATA_W*1-1:DATA_W*0];
  wire [DATA_W-1:0] cv_do1 = cv_do[DATA_W*2-1:DATA_W*1];

  // prev-cycle snapshots of input words (Z1 = one-cycle delayed)
    reg [DATA_W-1:0] d0_z1, d1_z1, d2_z1, d3_z1;


  // VCD
  initial begin
    $dumpfile("tb_cd_local_xbar_4x2.vcd");
    $dumpvars(0, tb_cd_local_xbar_4x2);
  end

  // Reset & defaults
  initial begin
    reset   = 1'b1;
    in_si   = 4'b0000;
    in_di   = {4*DATA_W{1'b0}};
    cv_ro   = 2'b00;
    cv_si_r = 2'b00;
    cv_di_r = {2*DATA_W{1'b0}};
    out_ro  = 4'b1111;
    c0 = 8'd0; c1 = 8'd0; c2 = 8'd0; c3 = 8'd0;

    repeat (4) @(posedge clk);
    reset = 1'b0;
  end

  // -------------------- Test sequence (UNROLLED, no loops) --------------------

  initial begin : TEST
    wait(!reset);


    // PH1: all inputs valid, both outputs ready; one warm-up cycle
    cv_ro = 2'b11;
    in_si = 4'b1111;
    in_di = { mk_word(8'd3,c3), mk_word(8'd2,c2), mk_word(8'd1,c1), mk_word(8'd0,c0) };

    // Prime previous-snapshots
    d0_z1 = mk_word(8'd0, c0);
    d1_z1 = mk_word(8'd1, c1);
    d2_z1 = mk_word(8'd2, c2);
    d3_z1 = mk_word(8'd3, c3);

    @(posedge clk); // warm-up

    // Run a few cycles, check data and grants without loops
    repeat (8) begin
      @(posedge clk);

      // Observe output 0
        if (cv_so[0]) begin
            // accept a hit on current OR previous words
            if      (cv_do0==mk_word(8'd0,c0) || cv_do0==d0_z1) c0 <= c0 + 1;
            else if (cv_do0==mk_word(8'd1,c1) || cv_do0==d1_z1) c1 <= c1 + 1;
            else if (cv_do0==mk_word(8'd2,c2) || cv_do0==d2_z1) c2 <= c2 + 1;
            else if (cv_do0==mk_word(8'd3,c3) || cv_do0==d3_z1) c3 <= c3 + 1;
            else $display("[ERR][%0t] cv_do0 not equal to any input (curr/prev)", $time);
        end


      // Observe output 1
        if (cv_so[1]) begin
            if (cv_so[0] && (cv_do1==cv_do0)) $display("[ERR][%0t] both outputs equal", $time);

            if      (cv_do1==mk_word(8'd0,c0) || cv_do1==d0_z1) c0 <= c0 + 1;
            else if (cv_do1==mk_word(8'd1,c1) || cv_do1==d1_z1) c1 <= c1 + 1;
            else if (cv_do1==mk_word(8'd2,c2) || cv_do1==d2_z1) c2 <= c2 + 1;
            else if (cv_do1==mk_word(8'd3,c3) || cv_do1==d3_z1) c3 <= c3 + 1;
            else $display("[ERR][%0t] cv_do1 not equal to any input (curr/prev)", $time);
        end


      // Drive next-cycle words
      in_di = { mk_word(8'd3,c3), mk_word(8'd2,c2), mk_word(8'd1,c1), mk_word(8'd0,c0) };
      // After driving next-cycle in_di, update Z1 snapshots
        d0_z1 <= mk_word(8'd0, c0);
        d1_z1 <= mk_word(8'd1, c1);
        d2_z1 <= mk_word(8'd2, c2);
        d3_z1 <= mk_word(8'd3, c3);

    end

    // PH2: backpressure output 0 → cv_ro=10 (stall o0)
    cv_ro = 2'b10;
    repeat (4) begin
      @(posedge clk);
      if (cv_so[0]) $display("[ERR][%0t] cv_so[0]=1 under backpressure", $time);
      // consume only o1
      if (cv_so[1]) begin
        if      (cv_do1==mk_word(8'd0,c0)) c0 <= c0 + 1;
        else if (cv_do1==mk_word(8'd1,c1)) c1 <= c1 + 1;
        else if (cv_do1==mk_word(8'd2,c2)) c2 <= c2 + 1;
        else if (cv_do1==mk_word(8'd3,c3)) c3 <= c3 + 1;
      end
      in_di = { mk_word(8'd3,c3), mk_word(8'd2,c2), mk_word(8'd1,c1), mk_word(8'd0,c0) };
    end

    // PH3: backpressure output 1 → cv_ro=01 (stall o1)
    cv_ro = 2'b01;
    repeat (4) begin
      @(posedge clk);
      if (cv_so[1]) $display("[ERR][%0t] cv_so[1]=1 under backpressure", $time);
      if (cv_so[0]) begin
        if      (cv_do0==mk_word(8'd0,c0)) c0 <= c0 + 1;
        else if (cv_do0==mk_word(8'd1,c1)) c1 <= c1 + 1;
        else if (cv_do0==mk_word(8'd2,c2)) c2 <= c2 + 1;
        else if (cv_do0==mk_word(8'd3,c3)) c3 <= c3 + 1;
      end
      in_di = { mk_word(8'd3,c3), mk_word(8'd2,c2), mk_word(8'd1,c1), mk_word(8'd0,c0) };
    end

    // PH4: randomized valids, both outputs ready
    cv_ro = 2'b11;
    repeat (8) begin
      @(posedge clk);
      // make a simple pseudo-random valid pattern without ints
      in_si[0] = $random;
      in_si[1] = $random;
      in_si[2] = $random;
      in_si[3] = $random;

      // Update counters based on outputs
      if (cv_so[0]) begin
        if      (cv_do0==mk_word(8'd0,c0)) c0 <= c0 + 1;
        else if (cv_do0==mk_word(8'd1,c1)) c1 <= c1 + 1;
        else if (cv_do0==mk_word(8'd2,c2)) c2 <= c2 + 1;
        else if (cv_do0==mk_word(8'd3,c3)) c3 <= c3 + 1;
      end
      if (cv_so[1]) begin
        if      (cv_do1==mk_word(8'd0,c0)) c0 <= c0 + 1;
        else if (cv_do1==mk_word(8'd1,c1)) c1 <= c1 + 1;
        else if (cv_do1==mk_word(8'd2,c2)) c2 <= c2 + 1;
        else if (cv_do1==mk_word(8'd3,c3)) c3 <= c3 + 1;
      end

      in_di = { mk_word(8'd3,c3), mk_word(8'd2,c2), mk_word(8'd1,c1), mk_word(8'd0,c0) };
    end

    $display("[DONE] tb_cd_local_xbar_4x2 finished.");
    $finish;
  end

endmodule
