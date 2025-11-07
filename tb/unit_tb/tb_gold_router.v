// tb_gold_router.v 
`timescale 1ns/1ps

module tb_gold_router;

  // ---------------- Clock & Reset ----------------
  reg clk, reset;
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;          // 100 MHz
  end

  initial begin
    reset = 1'b1;
    repeat (4) @(posedge clk);
    reset = 1'b0;
  end

  // ---------------- DUT I/O ----------------
  reg        n_si, s_si, e_si, w_si, pe_si;
  reg [63:0] n_di, s_di, e_di, w_di, pe_di;
  wire       n_ri, s_ri, e_ri, w_ri, pe_ri;

  wire       n_so, s_so, e_so, w_so, pe_so;
  wire [63:0] n_do, s_do, e_do, w_do, pe_do;
  reg        n_ro, s_ro, e_ro, w_ro, pe_ro;

  wire polarity;

  // ---------------- Instantiate DUT ----------------
  gold_router dut (
    .clk(clk), .reset(reset),
    .n_si(n_si), .n_di(n_di), .n_ri(n_ri),
    .s_si(s_si), .s_di(s_di), .s_ri(s_ri),
    .e_si(e_si), .e_di(e_di), .e_ri(e_ri),
    .w_si(w_si), .w_di(w_di), .w_ri(w_ri),
    .pe_si(pe_si), .pe_di(pe_di), .pe_ri(pe_ri),
    .n_so(n_so), .n_do(n_do), .n_ro(n_ro),
    .s_so(s_so), .s_do(s_do), .s_ro(s_ro),
    .e_so(e_so), .e_do(e_do), .e_ro(e_ro),
    .w_so(w_so), .w_do(w_do), .w_ro(w_ro),
    .pe_so(pe_so), .pe_do(pe_do), .pe_ro(pe_ro),
    .polarity(polarity)
  );

  // ---------------- Defaults ----------------
  integer cycles;
  initial begin
    cycles = 0;
    // outputs ready by default
    n_ro = 1'b1; s_ro = 1'b1; e_ro = 1'b1; w_ro = 1'b1; pe_ro = 1'b1;
    // inputs idle by default
    n_si = 1'b0; s_si = 1'b0; e_si = 1'b0; w_si = 1'b0; pe_si = 1'b0;
    n_di = 64'h0; s_di = 64'h0; e_di = 64'h0; w_di = 64'h0; pe_di = 64'h0;
  end
  always @(posedge clk) cycles <= cycles + 1;

  // ---------------- VCD dump ----------------
  initial begin
    $dumpfile("tb_gold_router.vcd");
    // Dump EVERYTHING under this TB, including DUT hierarchy
    $dumpvars(0, tb_gold_router);
  end

  // ---------------- Packet builder ----------------
  // Format: [63]VC [62]DX(0=E,1=W) [61]DY(0=S,1=N) [60:56]RSV [55:52]HX [51:48]HY [47:40]SRCX [39:32]SRCY [31:0]PAY
  function [63:0] make_pkt;
    input vc, dx, dy;
    input [4:0]  rsv;
    input [3:0]  hx, hy;
    input [7:0]  srcx, srcy;
    input [31:0] payload;
    begin
      make_pkt = {vc, dx, dy, rsv, hx, hy, srcx, srcy, payload};
    end
  endfunction

  // ---------------- Event trace (human readable) ----------------
  // Sample after each posedge to avoid races with combinational 'so'.
  always @(posedge clk) begin
    #1;
    $display("[%0t ns | cyc=%0d | pol=%0b]  RI: N%0b S%0b E%0b W%0b PE%0b   SO&RO: N%0b S%0b E%0b W%0b PE%0b   pe_si=%0b",
             $time, cycles, polarity,
             n_ri, s_ri, e_ri, w_ri, pe_ri,
             (n_so & n_ro), (s_so & s_ro), (e_so & e_ro), (w_so & w_ro), (pe_so & pe_ro),
             pe_si);
  end

  // ---------------- Simple stimulus ----------------
  // Goal: inject one packet from PE that *should* go East on first hop.
  // We hold pe_si HIGH for 4 cycles so that at least one external phase can capture it.
  // Then we drop it and wait (with a timeout) to see any output handshake.
  initial begin : SIMPLE_SEQUENCE
    reg [63:0] pkt;
    integer    t_start, t_seen;
    integer    timeout;

    @(negedge reset);
    @(posedge clk); #1;

    // Create a packet that will route East first: HX>0, DX=0
    pkt = make_pkt(1'b0, 1'b0, 1'b1, 5'h00, 4'd2, 4'd1, 8'hAA, 8'h55, 32'hFEED_BEEF);

    // Drive for 4 cycles to straddle phases
    $display("\n--- Driving PE for 4 cycles (straddling phases) ---");
    @(negedge clk);
    pe_di <= pkt;
    pe_si <= 1'b1;
    t_start = cycles + 1;   // will increment at next posedge

    repeat (4) @(posedge clk); #1;
    pe_si <= 1'b0;

    // Now wait up to 64 cycles for ANY output handshake (and print what we saw)
    timeout = 0;
    t_seen  = -1;
    while (timeout < 64 && t_seen < 0) begin
      @(posedge clk); #1;
      if ((n_so & n_ro) | (s_so & s_ro) | (e_so & e_ro) | (w_so & w_ro) | (pe_so & pe_ro)) begin
        t_seen = cycles;
        $display("\n*** FIRST output handshake at cyc=%0d  (N=%0b S=%0b E=%0b W=%0b PE=%0b) ***\n",
                 cycles, (n_so & n_ro), (s_so & s_ro), (e_so & e_ro), (w_so & w_ro), (pe_so & pe_ro));
      end
      timeout = timeout + 1;
    end

    if (t_seen < 0) begin
      $display("!!! TIMEOUT: No output handshake observed within 64 cycles after drive.");
    end else begin
      $display("Done: drove at ~cyc %0d, saw first handshake at cyc %0d", t_start, t_seen);
    end

    // Finish after a few extra cycles
    repeat (5) @(posedge clk);
    $finish;
  end

endmodule