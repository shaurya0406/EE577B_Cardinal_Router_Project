`timescale 1ns/1ps
//`default_nettype none  // optional: uncomment to catch undeclared nets

module tb_cardinal_nic;

  // -------------------
  // Parameters
  // -------------------
  parameter DATA_W  = 64;
  parameter VC_LSB  = 0;  // must match DUT (default 0)

  // -------------------
  // DUT I/O
  // -------------------
  reg                   clk;
  reg                   reset;

  // Processor side
  reg        [1:0]      addr;
  reg        [DATA_W-1:0] d_in;
  wire       [DATA_W-1:0] d_out;
  reg                   nicEn;
  reg                   nicWrEn;

  // Router side
  reg                   net_si;
  wire                  net_ri;
  reg        [DATA_W-1:0] net_di;

  wire                  net_so;
  reg                   net_ro;
  wire       [DATA_W-1:0] net_do;
  reg                   net_polarity;

  // -------------------
  // Clock
  // -------------------
  initial clk = 1'b0;
  always #5 clk = ~clk; // 100 MHz

  // -------------------
  // DUT
  // -------------------
  cardinal_nic #(.DATA_W(DATA_W), .VC_LSB(VC_LSB)) dut (
    .clk(clk),
    .reset(reset),
    .addr(addr),
    .d_in(d_in),
    .d_out(d_out),
    .nicEn(nicEn),
    .nicWrEn(nicWrEn),
    .net_si(net_si),
    .net_ri(net_ri),
    .net_di(net_di),
    .net_so(net_so),
    .net_ro(net_ro),
    .net_do(net_do),
    .net_polarity(net_polarity)
  );

  // -------------------
  // Wave dumps (VCD + optional SHM for ncsim)
  // -------------------
  initial begin
    // VCD (portable)
    $dumpfile("tb_cardinal_nic.vcd");
    $dumpvars(0, tb_cardinal_nic);
`ifdef USE_SHM
    // ncsim / SimVision
    $shm_open("tb_cardinal_nic.shm");
    $shm_probe(tb_cardinal_nic, "AS"); // all signals, by structure
`endif
  end

  // -------------------
  // Helpers
  // -------------------
  integer errors;
  reg [DATA_W-1:0] tmp_data;

  task tick; begin @(posedge clk); #1; end endtask

  // Synchronous NIC write (store) to 2'b10
  task nic_store(input [DATA_W-1:0] data);
    begin
      addr    <= 2'b10;
      d_in    <= data;
      nicEn   <= 1'b1;
      nicWrEn <= 1'b1;
      tick();            // capture on posedge in DUT
      nicEn   <= 1'b0;
      nicWrEn <= 1'b0;
      d_in    <= {DATA_W{1'b0}};
    end
  endtask

  // Synchronous NIC read (load) from addr
  task nic_load(input [1:0] a, output [DATA_W-1:0] data);
    begin
      addr    <= a;
      nicEn   <= 1'b1;
      nicWrEn <= 1'b0;
      tick();             // d_out updates on this edge
      data    = d_out;
      nicEn   <= 1'b0;
    end
  endtask

  // Read a status register (MSB contains status)
  task nic_read_status(input [1:0] a, output reg status);
    reg [DATA_W-1:0] r;
    begin
      nic_load(a, r);
      status = r[DATA_W-1];
    end
  endtask

  // Drive a router→NIC receive beat (1 cycle), respecting RI
  task router_send(input [DATA_W-1:0] flit);
    begin
      while (!net_ri) tick();
      net_di <= flit;
      net_si <= 1'b1;
      tick();
      net_si <= 1'b0;
      net_di <= {DATA_W{1'b0}};
    end
  endtask

  // Wait for a TX send beat (SO & RO)
  task wait_tx_fire(output [DATA_W-1:0] sent);
    begin
      while (!(net_so && net_ro)) tick();
      sent = net_do;
      tick(); // allow TX buffer to clear on handshake edge
    end
  endtask

  // Convenience: make a 64b flit by forcing bit VC_LSB = vc
  // (accept a full 64-bit payload; avoids width truncation warnings)
  function [DATA_W-1:0] mk_flit;
    input [DATA_W-1:0] payload_full;
    input              vc;  // 1-bit
    reg   [DATA_W-1:0] tmp;
    begin
      tmp              = payload_full;
      tmp[VC_LSB]      = vc;         // force VC bit
      mk_flit          = tmp;
    end
  endfunction

  // -------------------
  // Test sequence
  // -------------------
  reg [DATA_W-1:0] rdata;
  reg [DATA_W-1:0] f0, f1, got;
  reg               st;

  initial begin
    // Defaults
    errors        = 0;
    reset         = 1'b1;
    addr          = 2'b00;
    d_in          = {DATA_W{1'b0}};
    nicEn         = 1'b0;
    nicWrEn       = 1'b0;
    net_si        = 1'b0;
    net_di        = {DATA_W{1'b0}};
    net_ro        = 1'b0;
    net_polarity  = 1'b0;

    // Two distinct full-width flits; mk_flit will force LSB as VC
    f0 = mk_flit(64'h0123_4567_89AB_CDEF, 1'b0); // VC=0
    f1 = mk_flit(64'hF0E1_D2C3_B4A5_9687, 1'b1); // VC=1

    // -------------------------
    // Reset waveform & checks
    // -------------------------
    tick(); tick();
    reset = 1'b1; tick();
    reset = 1'b0; tick();

    if (!net_ri)         begin $display("[ERR] After reset, RI must be 1"); errors=errors+1; end
    if (net_so)          begin $display("[ERR] After reset, SO must be 0"); errors=errors+1; end
    nic_read_status(2'b01, st); if (st !== 1'b0) begin $display("[ERR] RX status not empty after reset"); errors=errors+1; end
    nic_read_status(2'b11, st); if (st !== 1'b0) begin $display("[ERR] TX status not empty after reset"); errors=errors+1; end
    $display("[PASS] Reset behavior");

    // -------------------------------------------------------
    // TX: store when available, reject second store while full
    //   - also show block via polarity first
    // -------------------------------------------------------
    net_ro       = 1'b1;    // router ready
    net_polarity = 1'b1;    // mismatch for f0 (VC=0)

    nic_store(f0);
    nic_read_status(2'b11, st);
    if (st !== 1'b1) begin
      $display("[ERR] TX status should be full after first store");
      errors=errors+1;
    end

    // second store rejected while full
    nic_store(f1);
    nic_read_status(2'b11, st);
    if (st !== 1'b1) begin
      $display("[ERR] TX status changed after rejected store");
      errors=errors+1;
    end

    // no send on polarity mismatch
    tick();
    if (net_so !== 1'b0) begin
      $display("[ERR] SO must be 0 when VC!=polarity");
      errors=errors+1;
    end
    $display("[PASS] TX rejects writes while full & blocks on polarity mismatch");

    // -------------------------------------------------------
    // TX only fires when vc==polarity AND net_ro==1
    // -------------------------------------------------------
    net_polarity = 1'b0; // match VC
    net_ro       = 1'b0; // still blocked
    tick();
    if (net_so !== 1'b0) begin
      $display("[ERR] SO must be 0 when RO==0");
      errors=errors+1;
    end

    net_ro = 1'b1; // allow send
    wait_tx_fire(got);
    if (got !== f0) begin
      $display("[ERR] Sent flit != first stored flit. got=%h exp=%h", got, f0);
      errors=errors+1;
    end
    nic_read_status(2'b11, st);
    if (st !== 1'b0) begin
      $display("[ERR] TX status should be empty after send");
      errors=errors+1;
    end
    $display("[PASS] TX sends only when vc==polarity & RO==1, then clears");

    // -------------------------------------------------------
    // RX holds data until PE reads addr==2'b00
    // -------------------------------------------------------
    net_ro       = 1'b1;
    net_polarity = 1'b0;

    router_send(f1);  // deliver VC=1 flit
    nic_read_status(2'b01, st);
    if (st !== 1'b1) begin
      $display("[ERR] RX status should be full after router_send");
      errors=errors+1;
    end
    if (net_ri !== 1'b0) begin
      $display("[ERR] RI should be 0 while RX full");
      errors=errors+1;
    end

    tick(); tick(); tick(); // hold a few cycles to prove "no auto-consume"
    nic_read_status(2'b01, st);
    if (st !== 1'b1) begin
      $display("[ERR] RX did not hold before read");
      errors=errors+1;
    end

    nic_load(2'b00, rdata);    // read input buffer (sync)
    if (rdata !== f1) begin
      $display("[ERR] RX read mismatch. got=%h exp=%h", rdata, f1);
      errors=errors+1;
    end
    tick();                    // allow consume to clear
    nic_read_status(2'b01, st);
    if (st !== 1'b0) begin
      $display("[ERR] RX status not empty after read");
      errors=errors+1;
    end
    if (net_ri !== 1'b1) begin
      $display("[ERR] RI should be 1 after RX read");
      errors=errors+1;
    end
    $display("[PASS] RX holds until PE read, then clears & re-advertises RI");

    // -------------------------------------------------------
    // Processor-NIC 4 cases (for waveforms)
    //   1) STORE when TX available   (done above)
    //   2) STORE when TX unavailable (done above)
    //   3) LOAD  when RX available   (done above)
    //   4) LOAD  when RX unavailable (below)
    // -------------------------------------------------------
    nic_read_status(2'b01, st); // RX status now 0
    if (st !== 1'b0) begin
      $display("[ERR] RX status expected 0 before unavailable load");
      errors=errors+1;
    end
    nic_load(2'b00, rdata); // undefined content per spec; just capture wave
    $display("[INFO] LOAD when RX unavailable -> d_out=%h (status was 0)", rdata);
    $display("[PASS] All 4 PE↔NIC cases are present in waveforms");

    // -------------------------------------------------------
    // Summary / Finish
    // -------------------------------------------------------
    if (errors == 0) begin
      $display("===== ALL TESTS PASSED ✅ =====");
      $finish(0);
    end else begin
      $display("===== TESTS FAILED with %0d error(s) ❌ =====", errors);
      $finish(2);
    end
  end

endmodule
