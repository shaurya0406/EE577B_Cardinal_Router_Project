// //======================================================================
// // tb_cardinal_router.v
// // Simple directed test: send one packet from (3,0) → (1,2)
// //======================================================================
// `timescale 1ns/1ps

// module tb_cardinal_router;

//   // Parameters
//   localparam ROWS   = 4;
//   localparam COLS   = 4;
//   localparam DATA_W = 64;

//   // Clock / Reset
//   reg clk;
//   reg reset;

//   // NIC <-> Router link signals
//   reg  [ROWS*COLS-1:0]        pe_si;
//   reg  [ROWS*COLS-1:0]        pe_ro;
//   reg  [ROWS*COLS*DATA_W-1:0] pe_di;

//   wire [ROWS*COLS-1:0]        pe_ri;
//   wire [ROWS*COLS-1:0]        pe_so;
//   wire [ROWS*COLS*DATA_W-1:0] pe_do;
//   wire [ROWS*COLS-1:0]        pe_polarity;

//   // DUT instantiation
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
//   // Clock generation
//   //--------------------------------------------------------------------
//   initial begin
//     clk = 0;
//     forever #2 clk = ~clk; // 250 MHz
//   end

//   // Waves
//   initial begin
//     $dumpfile("tb_cardinal_router.vcd");
//     $dumpvars(0, tb_cardinal_router);
//   end

//   //--------------------------------------------------------------------
//   // Reset
//   //--------------------------------------------------------------------
//   initial begin
//     reset = 1;
//     #20;
//     reset = 0;
//   end

//   //--------------------------------------------------------------------
//   // Helpers
//   //--------------------------------------------------------------------
//   function integer idx;
//     input integer x, y;
//     begin
//       idx = (y * COLS) + x;
//     end
//   endfunction

//   //--------------------------------------------------------------------
//   // Stimulus
//   //--------------------------------------------------------------------
//   integer src_idx, dst_idx;
//   reg [DATA_W-1:0] packet;

//   initial begin
//     // Defaults
//     pe_si = 0;
//     pe_ro = 0;
//     pe_di = 0;

//     @(negedge reset);
//     #10;

//     // Route: (3,0) → (1,2)
//     src_idx = idx(3,0);
//     dst_idx = idx(1,2);

//     // Encode header
//     // Dx=1 (West), Dy=1 (South)
//     // Hx=2, Hy=2, SrcX=3, SrcY=0
//     packet = {
//       1'b0,         // VC
//       1'b1,         // Dx (West)
//       1'b1,         // Dy (South)
//       5'b0,         // RSV
//       4'b0011,      // Hx (2 hops)
//       4'b0011,      // Hy (2 hops)
//       8'd3,         // SrcX
//       8'd0,         // SrcY
//       32'hDEADBEEF  // Payload
//     };

//     // Prepare destination NIC ready
//     pe_ro[dst_idx] = 1'b1;

//     // Wait a few cycles, then inject packet
//     #20;
//     $display("[%0t] Injecting packet at (3,0) -> (1,2)", $time);
//     pe_di[src_idx*DATA_W +: DATA_W] = packet;
//     pe_si[src_idx] = 1'b1;

//     // Wait for router to accept it
//     wait (pe_ri[src_idx] == 1'b1);
//     @(posedge clk);
//     pe_si[src_idx] = 1'b0; // stop sending

//     // Wait for packet to arrive at destination
//     wait (pe_so[dst_idx] == 1'b1);
//     $display("[%0t] Packet arrived at (1,2)!", $time);
//     $display("Data Out = %h", pe_do[dst_idx*DATA_W +: DATA_W]);

//     #50;
//     $finish;
//   end

// endmodule


//======================================================================
// tb_cardinal_router.v
// Clean Verilog-2001 testbench for cardinal_router
// Sends one packet (3,0) → (1,2)
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
  // Clock generation
  //--------------------------------------------------------------------
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;   // 100 MHz clock
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
  // Helper function: linear index
  //--------------------------------------------------------------------
  function integer idx;
    input integer x, y;
    begin
      idx = (y * COLS) + x;
    end
  endfunction

    // Waves
  initial begin
    $dumpfile("tb_cardinal_router.vcd");
    $dumpvars(0, tb_cardinal_router);
  end

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
    pe_si = 0;
    pe_ro = 0;
    pe_di = 0;

    @(negedge reset);
    #10;

    // Source (3,0) → Destination (1,2)
    src_idx = idx(3,0);
    dst_idx = idx(1,2);

    // Offsets and directions
    dx = 1'b1; // West (-X)
    dy = 1'b1; // South (+Y)
    hx = 4'b0011; // 2 hops
    hy = 4'b0011; // 2 hops

    // Destination ready
    pe_ro[dst_idx] = 1'b1;

    // Wait for correct polarity at source
    wait (pe_polarity[src_idx] == 1'b0 || pe_polarity[src_idx] == 1'b1);
    vc_bit = pe_polarity[src_idx];

    // Build packet header
    packet = {
      vc_bit,       // VC bit
      dx,           // Dx
      dy,           // Dy
      5'b00000,     // RSV
      hx,           // Hx
      hy,           // Hy
      8'd3,         // SrcX
      8'd0,         // SrcY
      32'hDEADBEEF  // Payload
    };

    // Inject packet when router is ready
    pe_di[src_idx*DATA_W +: DATA_W] = packet;
    wait (pe_ri[src_idx] == 1'b1);
    @(posedge clk);
    pe_si[src_idx] = 1'b1;
    @(posedge clk);
    pe_si[src_idx] = 1'b0;

    // Wait for arrival
    wait (pe_so[dst_idx] == 1'b1);
    $display("[%0t] Packet arrived at (1,2)! Data = %h",
              $time, pe_do[dst_idx*DATA_W +: DATA_W]);

    #50;
    $finish;
  end

endmodule
