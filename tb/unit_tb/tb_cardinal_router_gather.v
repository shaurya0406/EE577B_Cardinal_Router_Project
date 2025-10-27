// //======================================================================
// // tb_cardinal_router_gather.v
// // Robust Verilog-2001 testbench for cardinal_router
// // - 4 ns clock (250 MHz)
// // - Phased "gather": in phase k, all nodes except k send 1 flit to node k
// // - Per-phase logs: gather_phase<k>.res
// // - Start/end log:  start_end_time.out
// // - Rising-edge logging (no duplicates), unique-source barrier
// // - Per-phase summary line at end: SeenUnique, TotalLines
// // - Pure Verilog-2001 (no join_any/join_none, no $fflush)
// //======================================================================
// `timescale 1ns/1ps

// module tb_cardinal_router_gather;

//   // -------------------------------------------------------------------
//   // Parameters
//   // -------------------------------------------------------------------
//   parameter ROWS   = 4;
//   parameter COLS   = 4;
//   parameter DATA_W = 64;
//   localparam NODES = ROWS*COLS;

//   // -------------------------------------------------------------------
//   // Clock / Reset (250 MHz)
//   // -------------------------------------------------------------------
//   reg clk;
//   reg reset;

//   initial begin
//     clk = 1'b0;
//     forever #2 clk = ~clk;   // 4 ns period
//   end

//   initial begin
//     reset = 1'b1;
//     #20;
//     reset = 1'b0;
//   end

//   // -------------------------------------------------------------------
//   // DUT Interface
//   // -------------------------------------------------------------------
//   reg  [NODES-1:0]        pe_si;
//   reg  [NODES-1:0]        pe_ro;
//   reg  [NODES*DATA_W-1:0] pe_di;

//   wire [NODES-1:0]        pe_ri;
//   wire [NODES-1:0]        pe_so;
//   wire [NODES*DATA_W-1:0] pe_do;
//   wire [NODES-1:0]        pe_polarity;

//   // -------------------------------------------------------------------
//   // Instantiate DUT
//   // -------------------------------------------------------------------
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

//   // -------------------------------------------------------------------
//   // VCD
//   // -------------------------------------------------------------------
//   initial begin
//     $dumpfile("tb_cardinal_router_gather.vcd");
//     $dumpvars(0, tb_cardinal_router_gather);
//   end

//   // =========================================================================
//   // Helpers (plain Verilog)
//   // =========================================================================

//   // Linear index: idx = y*COLS + x
//   function integer idx;
//     input integer x, y;
//     begin
//       idx = (y * COLS) + x;
//     end
//   endfunction

//   // Decode (x,y) from linear index
//   task coord_from_idx;
//     input  integer i;
//     output integer x, y;
//     begin
//       y = i / COLS;
//       x = i % COLS;
//     end
//   endtask

//   // Unary (shift-right countdown) hop encoding: d in [0..3]
//   function [3:0] enc_hops;
//     input integer d;
//     begin
//       case (d)
//         0: enc_hops = 4'b0000;
//         1: enc_hops = 4'b0001;
//         2: enc_hops = 4'b0010;
//         3: enc_hops = 4'b0100;
//         default: enc_hops = 4'b1000; // saturate at 4 hops if larger
//       endcase
//     end
//   endfunction

//   // Build header for src -> dst, VC provided by caller
//   // Fields [63:VC][62:Dx][61:Dy][60:56:RSV][55:52:Hx][51:48:Hy][47:40:SrcX][39:32:SrcY][31:0:Payload]
//   task build_header;
//     input  integer src_i;
//     input  integer dst_i;
//     input  reg     vc_bit;
//     input  [31:0]  payload;
//     output [DATA_W-1:0] pkt;
//     integer sx, sy, dx_i, dy_i;
//     integer dxh, dyh;
//     reg dx_bit, dy_bit;
//     reg [3:0] hx, hy;
//     begin
//       coord_from_idx(src_i, sx, sy);
//       coord_from_idx(dst_i, dx_i, dy_i);

//       // Dx/Dy per RTL: Dx=0:E(+X),1:W(-X) ; Dy=0:N(-Y),1:S(+Y)
//       if (dx_i >= sx) begin
//         dx_bit = 1'b0; dxh =  dx_i - sx;
//       end else begin
//         dx_bit = 1'b1; dxh =  sx - dx_i;
//       end
//       if (dy_i >= sy) begin
//         dy_bit = 1'b1; dyh =  dy_i - sy;
//       end else begin
//         dy_bit = 1'b0; dyh =  sy - dy_i;
//       end

//       hx = enc_hops(dxh[3:0]);
//       hy = enc_hops(dyh[3:0]);

//       pkt = {
//         vc_bit,          // [63]
//         dx_bit,          // [62]
//         dy_bit,          // [61]
//         5'b00000,        // [60:56] RSV
//         hx,              // [55:52]
//         hy,              // [51:48]
//         sx[7:0],         // [47:40]
//         sy[7:0],         // [39:32]
//         payload          // [31:0]
//       };
//     end
//   endtask

//   // Inject one packet from src_i
//   // - Drive pe_di on negedge for setup
//   // - Wait pe_ri[src_i] == 1
//   // - Stamp VC at inject posedge from pe_polarity[src_i]
//   // - Pulse pe_si for exactly one cycle
//   task inject_one;
//     input integer src_i;
//     input [DATA_W-1:0] pkt_in;
//     reg [DATA_W-1:0] pkt;
//     reg vc_local;
//     begin
//       pkt = pkt_in;

//       // setup on negedge
//       @(negedge clk);
//       pe_di[src_i*DATA_W +: DATA_W] = pkt;

//       // wait for READY, then inject on posedge
//       wait (pe_ri[src_i] == 1'b1);
//       @(posedge clk);
//       vc_local = pe_polarity[src_i];
//       pe_di[src_i*DATA_W + DATA_W-1] = vc_local;  // MSB is VC
//       pe_si[src_i] = 1'b1;

//       @(posedge clk);
//       pe_si[src_i] = 1'b0;
//     end
//   endtask

//   // =========================================================================
//   // Logging helpers
//   // =========================================================================
//   integer fd_times;   // start_end_time.out
//   integer fd_phase;   // per-phase result file

//   // Open start_end_time.out once (write mode)
//   initial begin
//     fd_times = $fopen("start_end_time.out", "w");
//     if (fd_times == 0) begin
//       $display("ERROR: cannot open start_end_time.out");
//       $finish;
//     end
//   end

//   // Open per-phase result file for k (0..15 supported). If k>15, use fallback.
//   task open_phase_file;
//     input integer k;
//     output integer fd;
//     begin
//       case (k)
//         0:  fd = $fopen("gather_phase0.res" , "w");
//         1:  fd = $fopen("gather_phase1.res" , "w");
//         2:  fd = $fopen("gather_phase2.res" , "w");
//         3:  fd = $fopen("gather_phase3.res" , "w");
//         4:  fd = $fopen("gather_phase4.res" , "w");
//         5:  fd = $fopen("gather_phase5.res" , "w");
//         6:  fd = $fopen("gather_phase6.res" , "w");
//         7:  fd = $fopen("gather_phase7.res" , "w");
//         8:  fd = $fopen("gather_phase8.res" , "w");
//         9:  fd = $fopen("gather_phase9.res" , "w");
//         10: fd = $fopen("gather_phase10.res", "w");
//         11: fd = $fopen("gather_phase11.res", "w");
//         12: fd = $fopen("gather_phase12.res", "w");
//         13: fd = $fopen("gather_phase13.res", "w");
//         14: fd = $fopen("gather_phase14.res", "w");
//         15: fd = $fopen("gather_phase15.res", "w");
//         default: fd = $fopen("gather_phase_other.res", "w");
//       endcase
//       if (fd == 0) begin
//         $display("ERROR: cannot open per-phase result file for k=%0d", k);
//         $finish;
//       end
//     end
//   endtask

//   // =========================================================================
//   // Phase controller & destination logger (with rising-edge & unique barrier)
//   // =========================================================================
//   integer current_phase;
//   integer recv_count;      // total lines logged (for summary)
//   integer unique_cnt;      // unique sources seen
//   integer phase_active;
//   integer watchdog_cycles;

//   // Rising-edge detect for pe_so[current_phase]
//   reg  [NODES-1:0] pe_so_d1;
//   wire             pe_so_k_rise;
//   assign pe_so_k_rise = pe_so[current_phase] & ~pe_so_d1[current_phase];

//   // Unique-source bitmap for the current phase (per source node)
//   reg [NODES-1:0] recv_bitmap;

//   // Edge tracker
//   always @(posedge clk or posedge reset) begin
//     if (reset)
//       pe_so_d1 <= {NODES{1'b0}};
//     else
//       pe_so_d1 <= pe_so;
//   end

//   // Destination logger: log exactly once per arriving flit (rising edge)
//   always @(posedge clk) begin
//     if (!reset && phase_active) begin
//       if (pe_so_k_rise) begin
//         reg [DATA_W-1:0] do_sample;
//         reg [7:0] srcx, srcy;
//         integer src_idx_lin;

//         do_sample    = pe_do[current_phase*DATA_W +: DATA_W];
//         srcx         = do_sample[47:40];
//         srcy         = do_sample[39:32];
//         src_idx_lin  = (srcy * COLS) + srcx;

//         // Log one line per arriving packet
//         $fwrite(fd_phase,
//           "Phase=%0d Time=%0t Destination=%0d Source=(%0d,%0d) SrcIdx=%0d Packet=%h\n",
//           current_phase, $time, current_phase, srcx, srcy, src_idx_lin, do_sample);

//         // Track totals & uniqueness
//         recv_count = recv_count + 1;

//         if (src_idx_lin == current_phase) begin
//           $display("[%0t] TB WARN: Destination %0d sent to itself?", $time, current_phase);
//         end else if (!recv_bitmap[src_idx_lin]) begin
//           recv_bitmap[src_idx_lin] = 1'b1;
//           unique_cnt = unique_cnt + 1;
//         end else begin
//           $display("[%0t] TB WARN: Duplicate from source %0d in Phase %0d",
//                    $time, src_idx_lin, current_phase);
//         end
//       end
//     end
//   end

//   // =========================================================================
//   // Test sequencing: GATHER phases
//   // =========================================================================
//   integer k, si;

//   initial begin
//     // NIC defaults
//     pe_si = {NODES{1'b0}};
//     pe_ro = {NODES{1'b0}};
//     pe_di = {NODES*DATA_W{1'b0}};

//     // Wait reset
//     @(negedge reset);
//     repeat (4) @(posedge clk);

//     // ---------------------------
//     // GATHER PHASES  k=0..NODES-1
//     // ---------------------------
//     for (k = 0; k < NODES; k = k + 1) begin
//       current_phase   = k;
//       recv_count      = 0;
//       unique_cnt      = 0;
//       phase_active    = 1'b1;
//       watchdog_cycles = 0;
//       recv_bitmap     = {NODES{1'b0}};
//       pe_so_d1        = {NODES{1'b0}};

//       // Open per-phase file and log phase start
//       open_phase_file(k, fd_phase);
//       $fwrite(fd_times, "Phase=%0d StartTime=%0t\n", k, $time);

//       // Only destination k is ready
//       pe_ro = {NODES{1'b0}};
//       pe_ro[k] = 1'b1;

//       // Run three parallel branches: watchdog, sources, destination-done
//       fork
//         // (1) Watchdog branch
//         begin : watchdog_blk
//           while (phase_active) begin
//             @(posedge clk);
//             watchdog_cycles = watchdog_cycles + 1;
//             if (watchdog_cycles > 100000) begin
//               $display("[%0t] ERROR: Phase %0d watchdog timeout", $time, k);
//               $finish;
//             end
//           end
//         end

//         // (2) Sources launcher (parallel for all s != k)
//         begin : sources_blk
//           fork
//             for (si = 0; si < NODES; si = si + 1) begin : per_src
//               if (si != k) begin : one_src
//                 integer s;
//                 reg [DATA_W-1:0] pkt_pre; // VC placeholder (0)
//                 begin
//                   s = si;
//                   build_header(s, k, 1'b0, k[31:0], pkt_pre); // payload = k
//                   inject_one(s, pkt_pre);
//                 end
//               end
//             end
//           join
//           // sources branch ends after all injections finish
//         end

//         // (3) Destination completion branch (barrier on unique sources)
//         begin : dest_done_blk
//           wait (unique_cnt == (NODES-1));
//           phase_active = 1'b0;
//         end
//       join

//       // Phase end: summary, times, close file, clear ready
//       $fwrite(fd_phase, "SUMMARY Phase=%0d SeenUnique=%0d TotalLines=%0d\n",
//               k, unique_cnt, recv_count);
//       $fwrite(fd_times, "Phase=%0d EndTime=%0t\n", k, $time);
//       $fclose(fd_phase);
//       pe_ro[k] = 1'b0;

//       // Inter-phase gap
//       repeat (6) @(posedge clk);
//     end

//     $display("=== Gather test complete ===");
//     $finish;
//   end

// endmodule


//======================================================================
// tb_cardinal_router_gather.v
// Robust Verilog-2001 testbench for cardinal_router
// - 4 ns clock (250 MHz)
// - Phased "gather": in phase k, all nodes except k send 1 flit to node k
// - Per-phase logs: gather_phase<k>.res
// - Start/end log:  start_end_time.out
// - Logging on data-change while pe_so==1 (handles continuous streams)
// - Unique-source barrier (phase advances only after all NODES-1 sources)
// - Per-phase summary line: SeenUnique, TotalLines
// - Pure Verilog-2001 (no join_any/join_none, no $fflush)
//======================================================================
`timescale 1ns/1ps

module tb_cardinal_router_gather;

  // -------------------------------------------------------------------
  // Parameters
  // -------------------------------------------------------------------
  parameter ROWS   = 4;
  parameter COLS   = 4;
  parameter DATA_W = 64;
  localparam NODES = ROWS*COLS;

  // -------------------------------------------------------------------
  // Clock / Reset (250 MHz)
  // -------------------------------------------------------------------
  reg clk;
  reg reset;

  initial begin
    clk = 1'b0;
    forever #2 clk = ~clk;   // 4 ns period
  end

  initial begin
    reset = 1'b1;
    #20;
    reset = 1'b0;
  end

  // -------------------------------------------------------------------
  // DUT Interface
  // -------------------------------------------------------------------
  reg  [NODES-1:0]        pe_si;
  reg  [NODES-1:0]        pe_ro;
  reg  [NODES*DATA_W-1:0] pe_di;

  wire [NODES-1:0]        pe_ri;
  wire [NODES-1:0]        pe_so;
  wire [NODES*DATA_W-1:0] pe_do;
  wire [NODES-1:0]        pe_polarity;

  // -------------------------------------------------------------------
  // Instantiate DUT
  // -------------------------------------------------------------------
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

  // -------------------------------------------------------------------
  // VCD
  // -------------------------------------------------------------------
  initial begin
    $dumpfile("tb_cardinal_router_gather.vcd");
    $dumpvars(0, tb_cardinal_router_gather);
  end

  // =========================================================================
  // Helpers (plain Verilog)
  // =========================================================================

  function integer idx; // linear index: idx = y*COLS + x
    input integer x, y;
    begin
      idx = (y * COLS) + x;
    end
  endfunction

  task coord_from_idx; // decode (x,y) from linear index
    input  integer i;
    output integer x, y;
    begin
      y = i / COLS;
      x = i % COLS;
    end
  endtask

  function [3:0] enc_hops; // unary (shift-right countdown) hop encoding
    input integer d;
    begin
      case (d)
        0: enc_hops = 4'b0000;
        1: enc_hops = 4'b0001;
        2: enc_hops = 4'b0010;
        3: enc_hops = 4'b0100;
        default: enc_hops = 4'b1000;
      endcase
    end
  endfunction

  // [63:VC][62:Dx][61:Dy][60:56:RSV][55:52:Hx][51:48:Hy][47:40:SrcX][39:32:SrcY][31:0:Payload]
  task build_header;
    input  integer src_i;
    input  integer dst_i;
    input  reg     vc_bit;
    input  [31:0]  payload;
    output [DATA_W-1:0] pkt;
    integer sx, sy, dx_i, dy_i;
    integer dxh, dyh;
    reg dx_bit, dy_bit;
    reg [3:0] hx, hy;
    begin
      coord_from_idx(src_i, sx, sy);
      coord_from_idx(dst_i, dx_i, dy_i);

      // Dx/Dy per RTL: Dx=0:E(+X),1:W(-X) ; Dy=0:N(-Y),1:S(+Y)
      if (dx_i >= sx) begin dx_bit = 1'b0; dxh =  dx_i - sx; end
      else            begin dx_bit = 1'b1; dxh =  sx - dx_i; end
      if (dy_i >= sy) begin dy_bit = 1'b1; dyh =  dy_i - sy; end
      else            begin dy_bit = 1'b0; dyh =  sy - dy_i; end

      hx = enc_hops(dxh[3:0]);
      hy = enc_hops(dyh[3:0]);

      pkt = { vc_bit, dx_bit, dy_bit, 5'b00000, hx, hy, sx[7:0], sy[7:0], payload };
    end
  endtask

  // Inject one flit from src_i:
  // - Drive pe_di on negedge for setup
  // - Wait pe_ri[src_i] == 1
  // - Stamp VC at inject posedge from pe_polarity[src_i]
  // - Pulse pe_si for exactly one cycle
  task inject_one;
    input integer src_i;
    input [DATA_W-1:0] pkt_in;
    reg [DATA_W-1:0] pkt;
    reg vc_local;
    begin
      pkt = pkt_in;

      @(negedge clk);
      pe_di[src_i*DATA_W +: DATA_W] = pkt;

      wait (pe_ri[src_i] == 1'b1);
      @(posedge clk);
      vc_local = pe_polarity[src_i];
      pe_di[src_i*DATA_W + DATA_W-1] = vc_local;  // MSB is VC
      pe_si[src_i] = 1'b1;

      @(posedge clk);
      pe_si[src_i] = 1'b0;
    end
  endtask

  // =========================================================================
  // Logging & phase control
  // =========================================================================
  integer fd_times;    // start_end_time.out
  integer fd_phase;    // per-phase result file

  // Open start_end_time.out once (write mode)
  initial begin
    fd_times = $fopen("start_end_time.out", "w");
    if (fd_times == 0) begin
      $display("ERROR: cannot open start_end_time.out");
      $finish;
    end
  end

  // Open per-phase result file for k (0..15 supported)
  task open_phase_file;
    input integer k;
    output integer fd;
    begin
      case (k)
        0:  fd = $fopen("gather_phase0.res" , "w");
        1:  fd = $fopen("gather_phase1.res" , "w");
        2:  fd = $fopen("gather_phase2.res" , "w");
        3:  fd = $fopen("gather_phase3.res" , "w");
        4:  fd = $fopen("gather_phase4.res" , "w");
        5:  fd = $fopen("gather_phase5.res" , "w");
        6:  fd = $fopen("gather_phase6.res" , "w");
        7:  fd = $fopen("gather_phase7.res" , "w");
        8:  fd = $fopen("gather_phase8.res" , "w");
        9:  fd = $fopen("gather_phase9.res" , "w");
        10: fd = $fopen("gather_phase10.res", "w");
        11: fd = $fopen("gather_phase11.res", "w");
        12: fd = $fopen("gather_phase12.res", "w");
        13: fd = $fopen("gather_phase13.res", "w");
        14: fd = $fopen("gather_phase14.res", "w");
        15: fd = $fopen("gather_phase15.res", "w");
        default: fd = $fopen("gather_phase_other.res", "w");
      endcase
      if (fd == 0) begin
        $display("ERROR: cannot open per-phase result file for k=%0d", k);
        $finish;
      end
    end
  endtask

  // Phase state
  integer current_phase;
  integer recv_count;       // total lines logged (for summary)
  integer unique_cnt;       // unique sources seen this phase
  integer phase_active;
  integer watchdog_cycles;
  reg [NODES-1:0] recv_bitmap;    // per-source arrival flags

  // Data-change logger state
  reg               have_last;
  reg [DATA_W-1:0]  last_do_sample;

  // Destination logger: log each cycle pe_so[k]==1 when data changes (or first sample)
  always @(posedge clk) begin
    if (!reset && phase_active) begin
      if (pe_so[current_phase]) begin
        reg [DATA_W-1:0] do_sample;
        reg [7:0] srcx, srcy;
        integer src_idx_lin;

        do_sample    = pe_do[current_phase*DATA_W +: DATA_W];

        if (!have_last || (do_sample !== last_do_sample)) begin
          // take & log this new flit
          srcx         = do_sample[47:40];
          srcy         = do_sample[39:32];
          src_idx_lin  = (srcy * COLS) + srcx;

          $fwrite(fd_phase,
            "Phase=%0d Time=%0t Destination=%0d Source=(%0d,%0d) SrcIdx=%0d Packet=%h\n",
            current_phase, $time, current_phase, srcx, srcy, src_idx_lin, do_sample);

          recv_count = recv_count + 1;

          if (src_idx_lin == current_phase) begin
            $display("[%0t] TB WARN: Destination %0d sent to itself?", $time, current_phase);
          end else if (!recv_bitmap[src_idx_lin]) begin
            recv_bitmap[src_idx_lin] = 1'b1;
            unique_cnt = unique_cnt + 1;
          end else begin
            // duplicate source in same phase (ok but noted)
            $display("[%0t] TB WARN: Duplicate from source %0d in Phase %0d",
                     $time, src_idx_lin, current_phase);
          end

          last_do_sample <= do_sample;
          have_last      <= 1'b1;
        end
      end
    end
  end

  // =========================================================================
  // Test sequencing: GATHER phases
  // =========================================================================
  integer k, si;

  initial begin
    // NIC defaults
    pe_si = {NODES{1'b0}};
    pe_ro = {NODES{1'b0}};
    pe_di = {NODES*DATA_W{1'b0}};

    // Wait reset
    @(negedge reset);
    repeat (4) @(posedge clk);

    // GATHER PHASES  k=0..NODES-1
    for (k = 0; k < NODES; k = k + 1) begin
      current_phase   = k;
      recv_count      = 0;
      unique_cnt      = 0;
      phase_active    = 1'b1;
      watchdog_cycles = 0;
      recv_bitmap     = {NODES{1'b0}};
      have_last       = 1'b0;
      last_do_sample  = {DATA_W{1'b0}};

      open_phase_file(k, fd_phase);
      $fwrite(fd_times, "Phase=%0d StartTime=%0t\n", k, $time);

      // Only destination k is ready
      pe_ro = {NODES{1'b0}};
      pe_ro[k] = 1'b1;

      fork
        // (1) Watchdog branch
        begin : watchdog_blk
          while (phase_active) begin
            @(posedge clk);
            watchdog_cycles = watchdog_cycles + 1;
            if (watchdog_cycles > 100000) begin
              $display("[%0t] ERROR: Phase %0d watchdog timeout", $time, k);
              $finish;
            end
          end
        end

        // (2) Sources launcher (parallel injectors for all s != k)
        begin : sources_blk
          fork
            for (si = 0; si < NODES; si = si + 1) begin : per_src
              if (si != k) begin : one_src
                integer s;
                reg [DATA_W-1:0] pkt_pre; // VC placeholder (0)
                begin
                  s = si;
                  build_header(s, k, 1'b0, k[31:0], pkt_pre); // payload = k
                  inject_one(s, pkt_pre);
                end
              end
            end
          join
          // all injections complete
        end

        // (3) Destination completion branch (barrier on unique sources)
        begin : dest_done_blk
          wait (unique_cnt == (NODES-1));
          phase_active = 1'b0;
        end
      join

      // Phase end: summary, times, close file, clear ready
      $fwrite(fd_phase, "SUMMARY Phase=%0d SeenUnique=%0d TotalLines=%0d\n",
              k, unique_cnt, recv_count);
      $fwrite(fd_times, "Phase=%0d EndTime=%0t\n", k, $time);
      $fclose(fd_phase);
      pe_ro[k] = 1'b0;

      // Inter-phase gap
      repeat (6) @(posedge clk);
    end

    $display("=== Gather test complete ===");
    $finish;
  end

endmodule
