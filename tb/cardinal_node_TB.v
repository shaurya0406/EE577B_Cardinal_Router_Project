`timescale 1ns/1ps

module cardinal_node_tb;

  // ------------------------------------------------------------
  // Parameters for this tile (used by router + snoop logger)
  // ------------------------------------------------------------
  localparam int TILE_X = 1;
  localparam int TILE_Y = 2;

  // Clock / reset
  reg clk;
  reg reset;

  // Mesh-side signals (neighbors tied off)
  wire        n_si, s_si, e_si, w_si;
  wire [63:0] n_di, s_di, e_di, w_di;
  wire        n_ri, s_ri, e_ri, w_ri;
  wire        n_so, s_so, e_so, w_so;
  wire [63:0] n_do, s_do, e_do, w_do;
  wire        n_ro, s_ro, e_ro, w_ro;

  // Tie-offs for neighbors:
  assign n_si = 1'b0;
  assign s_si = 1'b0;
  assign e_si = 1'b0;
  assign w_si = 1'b0;

  assign n_di = 64'd0;
  assign s_di = 64'd0;
  assign e_di = 64'd0;
  assign w_di = 64'd0;

  // Neighbors always ready to accept (no backpressure)
  assign n_ro = 1'b1;
  assign s_ro = 1'b1;
  assign e_ro = 1'b1;
  assign w_ro = 1'b1;

  // ------------------------------------------------------------
  // DUT: single cardinal node
  // ------------------------------------------------------------
  cardinal_node #(
    .TILE_X (TILE_X),
    .TILE_Y (TILE_Y)
  ) u_dut (
    .clk   (clk),
    .reset (reset),

    .n_si (n_si), .n_di (n_di), .n_ri (n_ri),
    .n_so (n_so), .n_do (n_do), .n_ro (n_ro),

    .s_si (s_si), .s_di (s_di), .s_ri (s_ri),
    .s_so (s_so), .s_do (s_do), .s_ro (s_ro),

    .e_si (e_si), .e_di (e_di), .e_ri (e_ri),
    .e_so (e_so), .e_do (e_do), .e_ro (e_ro),

    .w_si (w_si), .w_di (w_di), .w_ri (w_ri),
    .w_so (w_so), .w_do (w_do), .w_ro (w_ro)
  );

  // ------------------------------------------------------------
  // Clock generation
  // ------------------------------------------------------------
  initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 100 MHz
  end

  // ------------------------------------------------------------
  // Simple reset sequence
  // ------------------------------------------------------------
  initial begin
    reset = 1'b1;
    repeat (5) @(posedge clk);
    reset = 1'b0;
  end

  // ------------------------------------------------------------
  // Small "assembler": NIC test program (26 instructions)
  //
  // Program:
  //   - Load DMEM[0..2] into R10/R20/R30
  //   - Send them out via NIC output channel with polling
  //   - Receive 3 packets via NIC input channel into R5/R15/R25
  //   - Store them to DMEM[5..7]
  // ------------------------------------------------------------
  localparam int PROG_LEN = 26;

  reg [31:0] prog_mem [0:PROG_LEN-1];

  initial begin
    // You can tweak the last instruction if you prefer 00000000.
    prog_mem[ 0] = 32'hF0000000; // VNOP
    prog_mem[ 1] = 32'h81400000; // VLD  r10, DMEM[0]
    prog_mem[ 2] = 32'h82800001; // VLD  r20, DMEM[1]
    prog_mem[ 3] = 32'h83C00002; // VLD  r30, DMEM[2]

    prog_mem[ 4] = 32'h8020C003; // VLD  r1,  NIC[3] (OUT_STATUS)
    prog_mem[ 5] = 32'h8C200010; // VBNEZ r1, 0x0010 (loop on full)

    prog_mem[ 6] = 32'h8540C002; // VSD  r10, NIC[2] (OUT_DATA)

    prog_mem[ 7] = 32'h8020C003; // VLD  r1,  NIC[3]
    prog_mem[ 8] = 32'h8C20001C; // VBNEZ r1, 0x001C

    prog_mem[ 9] = 32'h8680C002; // VSD  r20, NIC[2]

    prog_mem[10] = 32'h8020C003; // VLD  r1,  NIC[3]
    prog_mem[11] = 32'h8C200028; // VBNEZ r1, 0x0028

    prog_mem[12] = 32'h87C0C002; // VSD  r30, NIC[2]

    prog_mem[13] = 32'h8040C001; // VLD  r2,  NIC[1] (IN_STATUS)
    prog_mem[14] = 32'h88400034; // VBEZ r2, 0x0034 (loop until non-zero)
    prog_mem[15] = 32'h80A0C000; // VLD  r5,  NIC[0] (IN_DATA)

    prog_mem[16] = 32'h8040C001; // VLD  r2,  NIC[1]
    prog_mem[17] = 32'h88400040; // VBEZ r2, 0x0040
    prog_mem[18] = 32'h81E0C000; // VLD  r15, NIC[0]

    prog_mem[19] = 32'h8040C001; // VLD  r2,  NIC[1]
    prog_mem[20] = 32'h8840004C; // VBEZ r2, 0x004C
    prog_mem[21] = 32'h8320C000; // VLD  r25, NIC[0]

    prog_mem[22] = 32'h84A00005; // VSD  r5,  DMEM[5]
    prog_mem[23] = 32'h85E00006; // VSD  r15, DMEM[6]
    prog_mem[24] = 32'h87200007; // VSD  r25, DMEM[7]
    prog_mem[25] = 32'hF0000000; // VNOP (pad / end)
  end

  // ------------------------------------------------------------
  // Helper: build a 64-bit packet from header fields + payload
  // Header map (63..32):
  //   VC[63], Dx[62], Dy[61], Rsv[60:56],
  //   Hx[55:52], Hy[51:48], SrcX[47:40], SrcY[39:32]
  // ------------------------------------------------------------
  function automatic [63:0] make_pkt;
    input bit        vc;
    input bit        dx;
    input bit        dy;
    input [4:0]      rsv;
    input [3:0]      hx;
    input [3:0]      hy;
    input [7:0]      srcx;
    input [7:0]      srcy;
    input [31:0]     payload;
    reg   [31:0]     hdr;
  begin
    hdr[31]    = vc;
    hdr[30]    = dx;
    hdr[29]    = dy;
    hdr[28:24] = rsv;
    hdr[23:20] = hx;
    hdr[19:16] = hy;
    hdr[15:8]  = srcx;
    hdr[7:0]   = srcy;
    make_pkt   = {hdr, payload};
  end
  endfunction

  // ------------------------------------------------------------
  // Initialize imem & dmem via hierarchical access
  //
  // NOTE: You MUST adapt these paths to your actual memory arrays:
  //   - u_dut.u_imem.<mem_name> [...]
  //   - u_dut.u_dmem.<mem_name> [...]
  //
  // Common patterns in class projects are:
  //   reg [31:0] mem [0:IMEM_DEPTH-1];
  //   reg [63:0] mem [0:DMEM_DEPTH-1];
  // ------------------------------------------------------------

  localparam int PKT_SRC0_ADDR = 0;
  localparam int PKT_SRC1_ADDR = 1;
  localparam int PKT_SRC2_ADDR = 2;

  localparam int PKT_DST0_ADDR = 5;
  localparam int PKT_DST1_ADDR = 6;
  localparam int PKT_DST2_ADDR = 7;

  // Expected packets
  reg [63:0] pkt0, pkt1, pkt2;

  initial begin : init_memories
    integer i;

    // Wait until after reset has been asserted once
    @(negedge reset);

    //----------------------------------------------------------
    // 1) Build three distinct packets targeting this tile
    //----------------------------------------------------------
    pkt0 = make_pkt(
      /*vc*/    1'b0,
      /*dx*/    1'b0,
      /*dy*/    1'b0,
      /*rsv*/   5'd0,
      /*hx*/    TILE_X[3:0],
      /*hy*/    TILE_Y[3:0],
      /*srcx*/  TILE_X[7:0],
      /*srcy*/  TILE_Y[7:0],
      /*payload*/32'hDEAD_BEEF
    );

    pkt1 = make_pkt(
      1'b0, 1'b0, 1'b0, 5'd0,
      TILE_X[3:0], TILE_Y[3:0],
      TILE_X[7:0], TILE_Y[7:0],
      32'hCAFEBABE
    );

    pkt2 = make_pkt(
      1'b0, 1'b0, 1'b0, 5'd0,
      TILE_X[3:0], TILE_Y[3:0],
      TILE_X[7:0], TILE_Y[7:0],
      32'hC001_D00D
    );

    //----------------------------------------------------------
    // 2) Initialize instruction memory
    //----------------------------------------------------------
    // Replace "mem" with actual array name in your imem module.
    for (i = 0; i < PROG_LEN; i = i + 1) begin
      u_dut.u_imem.mem[i] = prog_mem[i];
    end

    // Optionally zero-fill rest of imem (if small/known depth)
    // for (i = PROG_LEN; i < IMEM_DEPTH; i = i + 1)
    //   u_dut.u_imem.mem[i] = 32'hF0000000;

    //----------------------------------------------------------
    // 3) Initialize data memory
    //----------------------------------------------------------
    // Replace "mem" with actual array name in your dmem module.
    // Zero everything first (assuming depth at least 16 for demo)
    for (i = 0; i < 16; i = i + 1) begin
      u_dut.u_dmem.mem[i] = 64'd0;
    end

    // Source packets at DMEM[0..2]
    u_dut.u_dmem.mem[PKT_SRC0_ADDR] = pkt0;
    u_dut.u_dmem.mem[PKT_SRC1_ADDR] = pkt1;
    u_dut.u_dmem.mem[PKT_SRC2_ADDR] = pkt2;

    // Dest locations 5..7 initially zero
    u_dut.u_dmem.mem[PKT_DST0_ADDR] = 64'd0;
    u_dut.u_dmem.mem[PKT_DST1_ADDR] = 64'd0;
    u_dut.u_dmem.mem[PKT_DST2_ADDR] = 64'd0;
  end

  // ------------------------------------------------------------
  // Run simulation and check results
  // ------------------------------------------------------------
  initial begin : run_and_check
    // Let the program run for a while
    // (tune this if you change clock or program)
    repeat (1000) @(posedge clk);

    // Check DMEM results
    if (u_dut.u_dmem.mem[PKT_DST0_ADDR] !== pkt0) begin
      $display("ERROR: DMEM[%0d] mismatch. Got %016h, expected %016h",
               PKT_DST0_ADDR,
               u_dut.u_dmem.mem[PKT_DST0_ADDR], pkt0);
      $fatal;
    end

    if (u_dut.u_dmem.mem[PKT_DST1_ADDR] !== pkt1) begin
      $display("ERROR: DMEM[%0d] mismatch. Got %016h, expected %016h",
               PKT_DST1_ADDR,
               u_dut.u_dmem.mem[PKT_DST1_ADDR], pkt1);
      $fatal;
    end

    if (u_dut.u_dmem.mem[PKT_DST2_ADDR] !== pkt2) begin
      $display("ERROR: DMEM[%0d] mismatch. Got %016h, expected %016h",
               PKT_DST2_ADDR,
               u_dut.u_dmem.mem[PKT_DST2_ADDR], pkt2);
      $fatal;
    end

    $display("==================================================");
    $display("  PASS: 3-packet PE <-> NIC <-> Router loopback OK");
    $display("  Tile (%0d,%0d)", TILE_X, TILE_Y);
    $display("  Check inject_log.txt and deliver_log.txt for");
    $display("  matching INJ/DEL entries for these packets.");
    $display("==================================================");

    $finish;
  end

endmodule
