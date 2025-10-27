// //======================================================================
// // tb_cardinal_router.v
// // Final Verilog-2001 testbench for cardinal_router
// // Sends one packet (3,0) → (1,2) and checks payload
// //======================================================================
// `timescale 1ns/1ps

// module tb_cardinal_router;

//   // Parameters
//   parameter ROWS   = 4;
//   parameter COLS   = 4;
//   parameter DATA_W = 64;

//   // Clock / Reset
//   reg clk;
//   reg reset;

//   // NIC <-> Router links
//   reg  [ROWS*COLS-1:0]        pe_si;
//   reg  [ROWS*COLS-1:0]        pe_ro;
//   reg  [ROWS*COLS*DATA_W-1:0] pe_di;

//   wire [ROWS*COLS-1:0]        pe_ri;
//   wire [ROWS*COLS-1:0]        pe_so;
//   wire [ROWS*COLS*DATA_W-1:0] pe_do;
//   wire [ROWS*COLS-1:0]        pe_polarity;

//   // Capture at destination
//   reg  [DATA_W-1:0]           cap_do_dst;
//   reg                          seen_dst;

//   //--------------------------------------------------------------------
//   // Instantiate DUT
//   //--------------------------------------------------------------------
//   cardinal_router #(
//     .ROWS(ROWS),
//     .COLS(COLS),
//     .DATA_W(DATA_W)
//   ) dut (
//     .clk(clk),
//     .reset(reset),
//     .pe_si(pe_si),
//     .pe_ro(pe_ro),
//     .pe_di(pe_di),
//     .pe_ri(pe_ri),
//     .pe_so(pe_so),
//     .pe_do(pe_do),
//     .pe_polarity(pe_polarity)
//   );

//   //--------------------------------------------------------------------
//   // Clock generation (100 MHz)
//   //--------------------------------------------------------------------
//   initial begin
//     clk = 1'b0;
//     forever #5 clk = ~clk;
//   end

//   //--------------------------------------------------------------------
//   // Reset
//   //--------------------------------------------------------------------
//   initial begin
//     reset = 1'b1;
//     #20;
//     reset = 1'b0;
//   end

//   //--------------------------------------------------------------------
//   // VCD waves
//   //--------------------------------------------------------------------
//   initial begin
//     $dumpfile("tb_cardinal_router.vcd");
//     $dumpvars(0, tb_cardinal_router);
//   end

//   //--------------------------------------------------------------------
//   // Helper: linear index  idx = y*COLS + x
//   //--------------------------------------------------------------------
//   function integer idx;
//     input integer x, y;
//     begin
//       idx = (y * COLS) + x;
//     end
//   endfunction

//   //--------------------------------------------------------------------
//   // Monitors (source (3,0) and dest (1,2))
//   //--------------------------------------------------------------------
//   initial begin
//     $display("TB: Mesh ROWS=%0d COLS=%0d DATA_W=%0d", ROWS, COLS, DATA_W);
//     $display("TB: Source (3,0) idx=%0d  ->  Dest (1,2) idx=%0d",
//               idx(3,0), idx(1,2));
//   end

//   // initial begin
//   //   $monitor("MON[%0t] SRC(3,0): pol=%b ri=%b si=%b | "
//   //            "DST(1,2): so=%b ro=%b",
//   //            $time,
//   //            pe_polarity[idx(3,0)], pe_ri[idx(3,0)], pe_si[idx(3,0)],
//   //            pe_so[idx(1,2)], pe_ro[idx(1,2)]);
//   // end

//   //--------------------------------------------------------------------
//   // Stimulus
//   //--------------------------------------------------------------------
//   integer src_idx, dst_idx;
//   reg [DATA_W-1:0] packet;
//   reg vc_bit;
//   reg [3:0] hx, hy;
//   reg dx, dy;

//   initial begin
//     // Initialize
//     pe_si = {ROWS*COLS{1'b0}};
//     pe_ro = {ROWS*COLS{1'b0}};
//     pe_di = {ROWS*COLS*DATA_W{1'b0}};
//     cap_do_dst = {DATA_W{1'b0}};
//     seen_dst   = 1'b0;

//     @(negedge reset);
//     repeat (2) @(posedge clk);

//     // -----------------------------------------------------------------
//     // Route: (3,0) → (1,2)
//     // Dx=1 (West, -X), Dy=1 (South, +Y),
//     // Hx=2, Hy=2, unary shift-right codes: 2 -> 4'b0010
//     // -----------------------------------------------------------------
//     src_idx = idx(3,0);
//     dst_idx = idx(1,2);

//     dx = 1'b1;       // West
//     dy = 1'b1;       // South
//     hx = 4'b0010;    // 2 hops (shift-right countdown)
//     hy = 4'b0010;    // 2 hops

//     // Keep destination ready to consume
//     pe_ro[dst_idx] = 1'b1;

//     // Align VC with source router's current external phase
//     wait (pe_polarity[src_idx] == 1'b0 || pe_polarity[src_idx] == 1'b1);
//     vc_bit = pe_polarity[src_idx];

//     // Build packet
//     packet = {
//       vc_bit,       // [63] VC
//       dx,           // [62] Dx (0:E, 1:W)
//       dy,           // [61] Dy (0:N, 1:S)
//       5'b00000,     // [60:56] RSV
//       hx,           // [55:52] Hx
//       hy,           // [51:48] Hy
//       8'd3,         // [47:40] SrcX = 3
//       8'd0,         // [39:32] SrcY = 0
//       32'hDEADBEEF  // [31:0]  Payload
//     };

//     // Drive data, then inject on a READY cycle; pulse for one beat
//     pe_di[src_idx*DATA_W +: DATA_W] = packet;
//     wait (pe_ri[src_idx] == 1'b1);
//     @(posedge clk);
//     $display("[%0t] TB: Injecting flit at SRC (3,0) idx=%0d | VC=%0d Dx=%0d Dy=%0d Hx=%b Hy=%b Payload=%h",
//              $time, src_idx, vc_bit, dx, dy, hx, hy, packet[31:0]);
//     pe_si[src_idx] = 1'b1;
//     @(posedge clk);
//     pe_si[src_idx] = 1'b0;

//     // Wait for SO at destination, then sample DO on the next clock edge
//     wait (pe_so[dst_idx] == 1'b1);
//     @(posedge clk);
//     cap_do_dst = pe_do[dst_idx*DATA_W +: DATA_W];
//     seen_dst   = 1'b1;

//     $display("[%0t] TB: Captured flit at DST (1,2) idx=%0d | DO=%h (Payload=%h)",
//              $time, dst_idx, cap_do_dst, cap_do_dst[31:0]);

//     if (cap_do_dst[31:0] !== 32'hDEADBEEF) begin
//       $display("[%0t] TB: ERROR: Payload mismatch! got=%h exp=DEADBEEF",
//                $time, cap_do_dst[31:0]);
//     end else begin
//       $display("[%0t] TB: PASS: Payload matches.", $time);
//     end

//     // Finish
//     repeat (5) @(posedge clk);
//     $finish;
//   end

// endmodule




//======================================================================
// tb_cardinal_router.v
// Final Verilog-2001 testbench for cardinal_router
// Sends one packet (3,0) → (1,2) and checks payload
//======================================================================
`timescale 1ns/1ps

module tb_cardinal_router;

  // Parameters
  parameter ROWS   = 4;
  parameter COLS   = 4;
  parameter DATA_W = 64;

  // Clock / Reset
  reg clk;
  reg reset;

  // NIC <-> Router links
  reg  [ROWS*COLS-1:0]        pe_si;
  reg  [ROWS*COLS-1:0]        pe_ro;
  reg  [ROWS*COLS*DATA_W-1:0] pe_di;

  wire [ROWS*COLS-1:0]        pe_ri;
  wire [ROWS*COLS-1:0]        pe_so;
  wire [ROWS*COLS*DATA_W-1:0] pe_do;
  wire [ROWS*COLS-1:0]        pe_polarity;

  // Capture at destination
  reg  [DATA_W-1:0]           cap_do_dst;
  reg                          seen_dst;

  //--------------------------------------------------------------------
  // Instantiate DUT
  //--------------------------------------------------------------------
  cardinal_router #(
    .ROWS(ROWS),
    .COLS(COLS),
    .DATA_W(DATA_W)
  ) dut (
    .clk(clk),
    .reset(reset),
    .pe_si(pe_si),
    .pe_ro(pe_ro),
    .pe_di(pe_di),
    .pe_ri(pe_ri),
    .pe_so(pe_so),
    .pe_do(pe_do),
    .pe_polarity(pe_polarity)
  );

  //--------------------------------------------------------------------
  // Clock generation (100 MHz)
  //--------------------------------------------------------------------
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  //--------------------------------------------------------------------
  // Reset
  //--------------------------------------------------------------------
  initial begin
    reset = 1'b1;
    #20;
    reset = 1'b0;
  end

  //--------------------------------------------------------------------
  // VCD waves
  //--------------------------------------------------------------------
  initial begin
    $dumpfile("tb_cardinal_router.vcd");
    $dumpvars(0, tb_cardinal_router);
  end

  //--------------------------------------------------------------------
  // Helper: linear index  idx = y*COLS + x
  //--------------------------------------------------------------------
  function integer idx;
    input integer x, y;
    begin
      idx = (y * COLS) + x;
    end
  endfunction

  //--------------------------------------------------------------------
  // Monitors (source (3,0) and dest (1,2))
  //--------------------------------------------------------------------
  initial begin
    $display("TB: Mesh ROWS=%0d COLS=%0d DATA_W=%0d", ROWS, COLS, DATA_W);
    $display("TB: Source (0,2) idx=%0d  ->  Dest (0,1) idx=%0d",
              idx(0,2), idx(0,1));
  end

  // initial begin
  //   $monitor("MON[%0t] SRC(3,0): pol=%b ri=%b si=%b | "
  //            "DST(1,2): so=%b ro=%b",
  //            $time,
  //            pe_polarity[idx(3,0)], pe_ri[idx(3,0)], pe_si[idx(3,0)],
  //            pe_so[idx(1,2)], pe_ro[idx(1,2)]);
  // end

  //--------------------------------------------------------------------
  // Stimulus
  //--------------------------------------------------------------------
  integer src_idx, dst_idx;
  reg [DATA_W-1:0] packet;
  reg vc_bit;
  reg [3:0] hx, hy;
  reg dx, dy;

  initial begin
    // Initialize
    pe_si = {ROWS*COLS{1'b0}};
    pe_ro = {ROWS*COLS{1'b0}};
    pe_di = {ROWS*COLS*DATA_W{1'b0}};
    cap_do_dst = {DATA_W{1'b0}};
    seen_dst   = 1'b0;

    @(negedge reset);
    repeat (2) @(posedge clk);

    // -----------------------------------------------------------------
    // Route: (3,0) → (1,2)
    // Dx=1 (West, -X), Dy=1 (South, +Y),
    // Hx=2, Hy=2, unary shift-right codes: 2 -> 4'b0010
    // -----------------------------------------------------------------
    src_idx = idx(0,2);
    dst_idx = idx(0,1);

    dx = 1'b0;       // EAST
    dy = 1'b0;       // NORTH
    hx = 4'b0000;    // 0 hops (shift-right countdown)
    hy = 4'b0001;    // 1 hops

    // Keep destination ready to consume
    pe_ro[dst_idx] = 1'b1;

    // Align VC with source router's current external phase
    wait (pe_polarity[src_idx] == 1'b0 || pe_polarity[src_idx] == 1'b1);
    vc_bit = pe_polarity[src_idx];

    // Build packet
    packet = {
      vc_bit,       // [63] VC
      dx,           // [62] Dx (0:E, 1:W)
      dy,           // [61] Dy (0:N, 1:S)
      5'b00000,     // [60:56] RSV
      hx,           // [55:52] Hx
      hy,           // [51:48] Hy
      8'd0,         // [47:40] SrcX = 3
      8'd2,         // [39:32] SrcY = 0
      32'hDEADBEEF  // [31:0]  Payload
    };

    // Drive data, then inject on a READY cycle; pulse for one beat
    pe_di[src_idx*DATA_W +: DATA_W] = packet;
    wait (pe_ri[src_idx] == 1'b1);
    @(posedge clk);
    $display("[%0t] TB: Injecting flit at SRC (0,2) idx=%0d | VC=%0d Dx=%0d Dy=%0d Hx=%b Hy=%b Payload=%h",
             $time, src_idx, vc_bit, dx, dy, hx, hy, packet[31:0]);
    pe_si[src_idx] = 1'b1;
    @(posedge clk);
    pe_si[src_idx] = 1'b0;

    // Wait for SO at destination, then sample DO on the next clock edge
    wait (pe_so[dst_idx] == 1'b1);
    @(posedge clk);
    cap_do_dst = pe_do[dst_idx*DATA_W +: DATA_W];
    seen_dst   = 1'b1;

    $display("[%0t] TB: Captured flit at DST (0,1) idx=%0d | DO=%h (Payload=%h)",
             $time, dst_idx, cap_do_dst, cap_do_dst[31:0]);

    if (cap_do_dst[31:0] !== 32'hDEADBEEF) begin
      $display("[%0t] TB: ERROR: Payload mismatch! got=%h exp=DEADBEEF",
               $time, cap_do_dst[31:0]);
    end else begin
      $display("[%0t] TB: PASS: Payload matches.", $time);
    end

    // Finish
    repeat (5) @(posedge clk);
    $finish;
  end

endmodule
