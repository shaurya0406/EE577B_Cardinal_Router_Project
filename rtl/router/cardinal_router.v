// // cardinal_router_mesh_xy_4x4.v
// // 4x4 mesh of cardinal_router_mesh_xy tiles
// // - Flattened PE port arrays for simple top-level integration
// //   Index mapping: IDX(y,x) = y*COLS + x  (y: 0..ROWS-1, x: 0..COLS-1)
// // - Edge links are terminated with ro=1, si=0, di=0

// `timescale 1ns/1ps

// module cardinal_router_mesh_xy_4x4
// #(
//   parameter ROWS = 4,
//   parameter COLS = 4
// )(
//   input  wire                     clk,
//   input  wire                     reset,

//   // Local PE link per tile (flattened arrays; N = ROWS*COLS)
//   input  wire [ROWS*COLS-1:0]     pe_si,      // PE -> router valid
//   input  wire [ROWS*COLS*64-1:0]  pe_di,      // PE -> router data
//   output wire [ROWS*COLS-1:0]     pe_ri,      // router ready for PE

//   output wire [ROWS*COLS-1:0]     pe_so,      // router -> PE valid
//   output wire [ROWS*COLS*64-1:0]  pe_do,      // router -> PE data
//   input  wire [ROWS*COLS-1:0]     pe_ro       // PE ready for router
// );

//   // ------------------------------
//   // Index helpers (functions)
//   // ------------------------------
//   function integer IDX;
//     input integer y, x;
//     begin
//       IDX = y*COLS + x;
//     end
//   endfunction

//   // Slice helpers for 64-bit flattened buses
//   function [63:0] SLICE64;
//     input [ROWS*COLS*64-1:0] VEC;
//     input integer idx;
//     begin
//       // Little helper: [ (idx+1)*64-1 : idx*64 ]
//       SLICE64 = VEC[(idx+1)*64-1 -: 64];
//     end
//   endfunction

//   // Drive helpers for 64-bit flattened outputs
//   // (implemented with continuous assigns below)

//   // ------------------------------
//   // Per-tile wires (N/S/E/W/PE)
//   // We keep these as 2-D arrays for readability.
//   // ------------------------------
//   // Inputs to each router from its neighbors/PE:
//   wire [ROWS-1:0][COLS-1:0]        n_si_w, s_si_w, e_si_w, w_si_w, pe_si_w;
//   wire [ROWS-1:0][COLS-1:0][63:0]  n_di_w, s_di_w, e_di_w, w_di_w, pe_di_w;
//   // Ready from router inputs (out of router, to neighbor's ro):
//   wire [ROWS-1:0][COLS-1:0]        n_ri_w, s_ri_w, e_ri_w, w_ri_w, pe_ri_w;

//   // Outputs from each router to its neighbors/PE:
//   wire [ROWS-1:0][COLS-1:0]        n_so_w, s_so_w, e_so_w, w_so_w, pe_so_w;
//   wire [ROWS-1:0][COLS-1:0][63:0]  n_do_w, s_do_w, e_do_w, w_do_w, pe_do_w;
//   // Ready into router outputs (from neighbor inputs):
//   wire [ROWS-1:0][COLS-1:0]        n_ro_w, s_ro_w, e_ro_w, w_ro_w, pe_ro_w;

//   // ------------------------------
//   // Tie PE ports to flattened top-level arrays
//   // ------------------------------
//   genvar yy, xx;
//   generate
//     for (yy = 0; yy < ROWS; yy = yy + 1) begin : GEN_PE_ROW
//       for (xx = 0; xx < COLS; xx = xx + 1) begin : GEN_PE_COL
//         localparam integer I = yy*COLS + xx;

//         // PE input side (to router)
//         assign pe_si_w[yy][xx] = pe_si[I];
//         assign pe_di_w[yy][xx] = SLICE64(pe_di, I);
//         assign pe_ri[I]        = pe_ri_w[yy][xx];

//         // PE output side (from router)
//         assign pe_so[I]            = pe_so_w[yy][xx];
//         assign pe_do[(I+1)*64-1 -: 64] = pe_do_w[yy][xx];
//         assign pe_ro_w[yy][xx]     = pe_ro[I];
//       end
//     end
//   endgenerate

//   // ------------------------------
//   // Edge terminations
//   //  - If a tile is on the boundary, that side’s inbound link = idle (si=0, di=0)
//   //    and outbound ready = 1 (ro=1) so packets can drain (drop) at the edge.
//   // ------------------------------
//   // North edge (y==0)
//   generate
//     for (xx = 0; xx < COLS; xx = xx + 1) begin : GEN_EDGE_N
//       assign n_si_w[0][xx] = 1'b0;
//       assign n_di_w[0][xx] = 64'h0;
//       assign n_ro_w[0][xx] = 1'b1;
//     end
//   endgenerate

//   // South edge (y==ROWS-1)
//   generate
//     for (xx = 0; xx < COLS; xx = xx + 1) begin : GEN_EDGE_S
//       assign s_si_w[ROWS-1][xx] = 1'b0;
//       assign s_di_w[ROWS-1][xx] = 64'h0;
//       assign s_ro_w[ROWS-1][xx] = 1'b1;
//     end
//   endgenerate

//   // West edge (x==0)
//   generate
//     for (yy = 0; yy < ROWS; yy = yy + 1) begin : GEN_EDGE_W
//       assign w_si_w[yy][0] = 1'b0;
//       assign w_di_w[yy][0] = 64'h0;
//       assign w_ro_w[yy][0] = 1'b1;
//     end
//   endgenerate

//   // East edge (x==COLS-1)
//   generate
//     for (yy = 0; yy < ROWS; yy = yy + 1) begin : GEN_EDGE_E
//       assign e_si_w[yy][COLS-1] = 1'b0;
//       assign e_di_w[yy][COLS-1] = 64'h0;
//       assign e_ro_w[yy][COLS-1] = 1'b1;
//     end
//   endgenerate

//   // ------------------------------
//   // Internal mesh wiring
//   // For each interior link, connect opposite ports of adjacent tiles:
//   //   Vertical adjacency between (y,x) and (y-1,x):
//   //     A = (y,x), B = (y-1,x)
//   //     A.n_so -> B.s_si
//   //     A.n_do -> B.s_di
//   //     B.s_ri -> A.n_ro
//   //     B.s_so -> A.n_si
//   //     B.s_do -> A.n_di
//   //     A.n_ri -> B.s_ro
//   //
//   //   Horizontal adjacency between (y,x) and (y,x-1):
//   //     A = (y,x), W = (y,x-1)
//   //     A.w_* ↔ W.e_* (symmetric as above)
//   // ------------------------------
//   generate
//     // Vertical neighbors
//     for (yy = 1; yy < ROWS; yy = yy + 1) begin : GEN_VERT
//       for (xx = 0; xx < COLS; xx = xx + 1) begin : GEN_VERT_COL
//         // (yy,xx) north <-> (yy-1,xx) south
//         // Connect data/valid from south-neighbor to north input
//         assign n_si_w[yy][xx] = s_so_w[yy-1][xx];
//         assign n_di_w[yy][xx] = s_do_w[yy-1][xx];
//         assign s_si_w[yy-1][xx] = n_so_w[yy][xx];
//         assign s_di_w[yy-1][xx] = n_do_w[yy][xx];

//         // Ready cross-connect
//         assign n_ro_w[yy][xx]    = s_ri_w[yy-1][xx];
//         assign s_ro_w[yy-1][xx]  = n_ri_w[yy][xx];
//       end
//     end

//     // Horizontal neighbors
//     for (yy = 0; yy < ROWS; yy = yy + 1) begin : GEN_HORZ
//       for (xx = 1; xx < COLS; xx = xx + 1) begin : GEN_HORZ_COL
//         // (yy,xx) west <-> (yy,xx-1) east
//         assign w_si_w[yy][xx]     = e_so_w[yy][xx-1];
//         assign w_di_w[yy][xx]     = e_do_w[yy][xx-1];
//         assign e_si_w[yy][xx-1]   = w_so_w[yy][xx];
//         assign e_di_w[yy][xx-1]   = w_do_w[yy][xx];

//         assign w_ro_w[yy][xx]     = e_ri_w[yy][xx-1];
//         assign e_ro_w[yy][xx-1]   = w_ri_w[yy][xx];
//       end
//     end
//   endgenerate

//   // ------------------------------
//   // Instantiate all 16 routers
//   // ------------------------------
//   generate
//     for (yy = 0; yy < ROWS; yy = yy + 1) begin : GEN_ROWS
//       for (xx = 0; xx < COLS; xx = xx + 1) begin : GEN_COLS
//         cardinal_router_mesh_xy U_ROUT (
//           .clk(clk), .reset(reset),

//           // Inputs (from neighbors/PE) -> router
//           .n_si(n_si_w[yy][xx]), .n_di(n_di_w[yy][xx]), .n_ri(n_ri_w[yy][xx]),
//           .s_si(s_si_w[yy][xx]), .s_di(s_di_w[yy][xx]), .s_ri(s_ri_w[yy][xx]),
//           .e_si(e_si_w[yy][xx]), .e_di(e_di_w[yy][xx]), .e_ri(e_ri_w[yy][xx]),
//           .w_si(w_si_w[yy][xx]), .w_di(w_di_w[yy][xx]), .w_ri(w_ri_w[yy][xx]),
//           .pe_si(pe_si_w[yy][xx]), .pe_di(pe_di_w[yy][xx]), .pe_ri(pe_ri_w[yy][xx]),

//           // Outputs (to neighbors/PE) <- router
//           .n_so(n_so_w[yy][xx]), .n_do(n_do_w[yy][xx]), .n_ro(n_ro_w[yy][xx]),
//           .s_so(s_so_w[yy][xx]), .s_do(s_do_w[yy][xx]), .s_ro(s_ro_w[yy][xx]),
//           .e_so(e_so_w[yy][xx]), .e_do(e_do_w[yy][xx]), .e_ro(e_ro_w[yy][xx]),
//           .w_so(w_so_w[yy][xx]), .w_do(w_do_w[yy][xx]), .w_ro(w_ro_w[yy][xx]),
//           .pe_so(pe_so_w[yy][xx]), .pe_do(pe_do_w[yy][xx]), .pe_ro(pe_ro_w[yy][xx]),

//           // Phase visibility (each tile has its own; all align after reset)
//           .polarity() // unconnected (optional debug)
//         );
//       end
//     end
//   endgenerate

// endmodule






//======================================================================
// cardinal_router.v
//  - Parameterized mesh of cardinal_router_mesh_xy nodes
//  - Strict XY routing (Dx=0:E, Dx=1:W, Dy=0:N, Dy=1:S)
//  - Fully synthesizable plain Verilog (no SystemVerilog constructs)
//----------------------------------------------------------------------
// Geometry:
//    X increases → right  (East)
//    Y increases → down   (South)
// Linear index: idx = (y * COLS) + x
//======================================================================

module cardinal_router
#(
  parameter ROWS    = 4,           // number of rows (Y dimension)
  parameter COLS    = 4,           // number of columns (X dimension)
  parameter DATA_W  = 64           // packet width
)
(
  input  wire                         clk,
  input  wire                         reset,

  //==============================
  // NIC → Router (Ingress)
  //==============================
  input  wire [ROWS*COLS-1:0]         pe_si,
  input  wire [ROWS*COLS-1:0]         pe_ro,
  input  wire [ROWS*COLS*DATA_W-1:0]  pe_di,

  //==============================
  // Router → NIC (Egress)
  //==============================
  output wire [ROWS*COLS-1:0]         pe_ri,
  output wire [ROWS*COLS-1:0]         pe_so,
  output wire [ROWS*COLS*DATA_W-1:0]  pe_do,
  output wire [ROWS*COLS-1:0]         pe_polarity
);

  // -------------------------------------------------------------------
  // Internal interconnect wires between routers
  // Each direction has ROWS×COLS signals, connected between neighbors.
  // -------------------------------------------------------------------
  wire [ROWS*COLS-1:0] n_si, s_si, e_si, w_si;
  wire [ROWS*COLS-1:0] n_so, s_so, e_so, w_so;
  wire [ROWS*COLS-1:0] n_ri, s_ri, e_ri, w_ri;
  wire [ROWS*COLS-1:0] n_ro, s_ro, e_ro, w_ro;
  wire [ROWS*COLS*DATA_W-1:0] n_di, s_di, e_di, w_di;
  wire [ROWS*COLS*DATA_W-1:0] n_do, s_do, e_do, w_do;

  // -------------------------------------------------------------------
  // Function to compute linear index (for readability only)
  // idx = y * COLS + x
  // -------------------------------------------------------------------
  function integer idx;
    input integer x, y;
    begin
      idx = (y * COLS) + x;
    end
  endfunction

  // -------------------------------------------------------------------
  // Instantiate mesh nodes and connect neighbors
  // -------------------------------------------------------------------
  genvar x, y;
  generate
    for (y = 0; y < ROWS; y = y + 1) begin : row_gen
      for (x = 0; x < COLS; x = x + 1) begin : col_gen

        localparam integer I = (y * COLS) + x;

        // -----------------------------
        // Neighbor connections (tie-offs at edges)
        // -----------------------------
        // NORTH neighbor
        wire        n_si_in  = (y == 0) ? 1'b0                   : s_so[idx(x, y-1)];
        wire [DATA_W-1:0] n_di_in  = (y == 0) ? {DATA_W{1'b0}}   : s_do[idx(x, y-1)*DATA_W +: DATA_W];
        wire        n_ro_in  = (y == 0) ? 1'b0                   : s_ri[idx(x, y-1)];
        wire        n_ri_out;  // to be connected back below

        // SOUTH neighbor
        wire        s_si_in  = (y == ROWS-1) ? 1'b0              : n_so[idx(x, y+1)];
        wire [DATA_W-1:0] s_di_in  = (y == ROWS-1) ? {DATA_W{1'b0}} : n_do[idx(x, y+1)*DATA_W +: DATA_W];
        wire        s_ro_in  = (y == ROWS-1) ? 1'b0              : n_ri[idx(x, y+1)];
        wire        s_ri_out;

        // WEST neighbor
        wire        w_si_in  = (x == 0) ? 1'b0                   : e_so[idx(x-1, y)];
        wire [DATA_W-1:0] w_di_in  = (x == 0) ? {DATA_W{1'b0}}   : e_do[idx(x-1, y)*DATA_W +: DATA_W];
        wire        w_ro_in  = (x == 0) ? 1'b0                   : e_ri[idx(x-1, y)];
        wire        w_ri_out;

        // EAST neighbor
        wire        e_si_in  = (x == COLS-1) ? 1'b0              : w_so[idx(x+1, y)];
        wire [DATA_W-1:0] e_di_in  = (x == COLS-1) ? {DATA_W{1'b0}} : w_do[idx(x+1, y)*DATA_W +: DATA_W];
        wire        e_ro_in  = (x == COLS-1) ? 1'b0              : w_ri[idx(x+1, y)];
        wire        e_ri_out;

        // -----------------------------
        // PE interface slice
        // -----------------------------
        wire        pe_si_in  = pe_si[I];
        wire        pe_ro_in  = pe_ro[I];
        wire [DATA_W-1:0] pe_di_in  = pe_di[I*DATA_W +: DATA_W];
        wire        pe_ri_out;
        wire        pe_so_out;
        wire [DATA_W-1:0] pe_do_out;
        wire        pe_pol_out;

        // -----------------------------
        // Router Node Instance
        // -----------------------------
        cardinal_router_mesh_xy u_node (
          .clk       (clk),
          .reset     (reset),

          // North link
          .n_si (n_si_in),
          .n_di (n_di_in),
          .n_ri (n_ri_out),
          .n_so (n_so[I]),
          .n_do (n_do[I*DATA_W +: DATA_W]),
          .n_ro (n_ro[I]),

          // South link
          .s_si (s_si_in),
          .s_di (s_di_in),
          .s_ri (s_ri_out),
          .s_so (s_so[I]),
          .s_do (s_do[I*DATA_W +: DATA_W]),
          .s_ro (s_ro[I]),

          // East link
          .e_si (e_si_in),
          .e_di (e_di_in),
          .e_ri (e_ri_out),
          .e_so (e_so[I]),
          .e_do (e_do[I*DATA_W +: DATA_W]),
          .e_ro (e_ro[I]),

          // West link
          .w_si (w_si_in),
          .w_di (w_di_in),
          .w_ri (w_ri_out),
          .w_so (w_so[I]),
          .w_do (w_do[I*DATA_W +: DATA_W]),
          .w_ro (w_ro[I]),

          // PE link
          .pe_si (pe_si_in),
          .pe_di (pe_di_in),
          .pe_ro (pe_ro_in),
          .pe_ri (pe_ri_out),
          .pe_so (pe_so_out),
          .pe_do (pe_do_out),
          .polarity (pe_pol_out)
        );

        // -----------------------------
        // Backward connections (readies)
        // -----------------------------
        assign n_ri[I] = n_ri_out;
        assign s_ri[I] = s_ri_out;
        assign e_ri[I] = e_ri_out;
        assign w_ri[I] = w_ri_out;

        // -----------------------------
        // Output mapping to flat buses
        // -----------------------------
        assign pe_ri[I]                     = pe_ri_out;
        assign pe_so[I]                     = pe_so_out;
        assign pe_do[I*DATA_W +: DATA_W]    = pe_do_out;
        assign pe_polarity[I]               = pe_pol_out;

      end
    end
  endgenerate

endmodule
