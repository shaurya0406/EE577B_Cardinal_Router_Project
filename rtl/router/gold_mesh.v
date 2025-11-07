//======================================================================
// cardinal_router.v
//  - Parameterized mesh of cardinal_router_mesh_xy nodes
//  - Strict XY routing (Dx=0:E, Dx=1:W, Dy=0:N, Dy=1:S)
//----------------------------------------------------------------------
// Geometry:
//    X increases → right  (East)
//    Y increases → down   (South)
// Linear index: IDX = (Y * COLS) + X
//======================================================================

module gold_mesh
#(
  parameter ROWS    = 4,
  parameter COLS    = 4,
  parameter DATA_W  = 64
)
(
  input  wire                         clk,
  input  wire                         reset,

  // NIC → Router
  input  wire [ROWS*COLS-1:0]         pe_si,
  input  wire [ROWS*COLS-1:0]         pe_ro,
  input  wire [ROWS*COLS*DATA_W-1:0]  pe_di,

  // Router → NIC
  output wire [ROWS*COLS-1:0]         pe_ri,
  output wire [ROWS*COLS-1:0]         pe_so,
  output wire [ROWS*COLS*DATA_W-1:0]  pe_do,
  output wire [ROWS*COLS-1:0]         pe_polarity
);

  // Interconnect arrays (per-direction)
  wire [ROWS*COLS-1:0]         n_si, s_si, e_si, w_si;
  wire [ROWS*COLS-1:0]         n_so, s_so, e_so, w_so;
  wire [ROWS*COLS-1:0]         n_ri, s_ri, e_ri, w_ri;
  wire [ROWS*COLS-1:0]         n_ro, s_ro, e_ro, w_ro;  // mirrors of *ro_in for visibility
  wire [ROWS*COLS*DATA_W-1:0]  n_di, s_di, e_di, w_di;
  wire [ROWS*COLS*DATA_W-1:0]  n_do, s_do, e_do, w_do;

  genvar X, Y;
  generate
    for (Y = 0; Y < ROWS; Y = Y + 1) begin : G_ROW
      for (X = 0; X < COLS; X = X + 1) begin : G_COL
        // Local constants for indices/ranges (all elaboration-time constants)
        localparam integer IDX      = (Y*COLS) + X;
        localparam integer SL_BASE  = IDX*DATA_W;
        localparam integer SL_HI    = SL_BASE + DATA_W - 1;

        // Neighbor indices (only used in valid branches)
        localparam integer IDX_N    = ((Y-1)*COLS) + X;
        localparam integer IDX_S    = ((Y+1)*COLS) + X;
        localparam integer IDX_W    = (Y*COLS) + (X-1);
        localparam integer IDX_E    = (Y*COLS) + (X+1);

        localparam integer SL_N     = IDX_N*DATA_W;
        localparam integer SL_S     = IDX_S*DATA_W;
        localparam integer SL_W     = IDX_W*DATA_W;
        localparam integer SL_E     = IDX_E*DATA_W;

        // -----------------------------
        // Neighbor connections (edge-safe with generate-if)
        // -----------------------------
        wire              n_si_in, s_si_in, e_si_in, w_si_in;
        wire [DATA_W-1:0] n_di_in, s_di_in, e_di_in, w_di_in;
        wire              n_ro_in, s_ro_in, e_ro_in, w_ro_in;
        wire              n_ri_out, s_ri_out, e_ri_out, w_ri_out;

        // NORTH
        if (Y == 0) begin : G_N_TOP
          assign n_si_in = 1'b0;
          assign n_di_in = {DATA_W{1'b0}};
          assign n_ro_in = 1'b0;
        end else begin : G_N_MID
          assign n_si_in = s_so[IDX_N];
          assign n_di_in = s_do[SL_N + DATA_W - 1 : SL_N];
          assign n_ro_in = s_ri[IDX_N];
        end

        // SOUTH
        if (Y == (ROWS-1)) begin : G_S_BOT
          assign s_si_in = 1'b0;
          assign s_di_in = {DATA_W{1'b0}};
          assign s_ro_in = 1'b0;
        end else begin : G_S_MID
          assign s_si_in = n_so[IDX_S];
          assign s_di_in = n_do[SL_S + DATA_W - 1 : SL_S];
          assign s_ro_in = n_ri[IDX_S];
        end

        // WEST
        if (X == 0) begin : G_W_LEFT
          assign w_si_in = 1'b0;
          assign w_di_in = {DATA_W{1'b0}};
          assign w_ro_in = 1'b0;
        end else begin : G_W_MID
          assign w_si_in = e_so[IDX_W];
          assign w_di_in = e_do[SL_W + DATA_W - 1 : SL_W];
          assign w_ro_in = e_ri[IDX_W];
        end

        // EAST
        if (X == (COLS-1)) begin : G_E_RIGHT
          assign e_si_in = 1'b0;
          assign e_di_in = {DATA_W{1'b0}};
          assign e_ro_in = 1'b0;
        end else begin : G_E_MID
          assign e_si_in = w_so[IDX_E];
          assign e_di_in = w_do[SL_E + DATA_W - 1 : SL_E];
          assign e_ro_in = w_ri[IDX_E];
        end

        // Mirror *ro_in to arrays for waveform visibility (optional)
        assign n_ro[IDX] = n_ro_in;
        assign s_ro[IDX] = s_ro_in;
        assign w_ro[IDX] = w_ro_in;
        assign e_ro[IDX] = e_ro_in;

        // Optional: mirror si/di for easy scoping
        assign n_si[IDX] = n_si_in;
        assign s_si[IDX] = s_si_in;
        assign w_si[IDX] = w_si_in;
        assign e_si[IDX] = e_si_in;

        assign n_di[SL_BASE + DATA_W - 1 : SL_BASE] = n_di_in;
        assign s_di[SL_BASE + DATA_W - 1 : SL_BASE] = s_di_in;
        assign w_di[SL_BASE + DATA_W - 1 : SL_BASE] = w_di_in;
        assign e_di[SL_BASE + DATA_W - 1 : SL_BASE] = e_di_in;

        // -----------------------------
        // PE slice
        // -----------------------------
        wire              pe_si_in, pe_ro_in;
        wire [DATA_W-1:0] pe_di_in;
        wire              pe_ri_out, pe_so_out, pe_pol_out;
        wire [DATA_W-1:0] pe_do_out;

        assign pe_si_in = pe_si[IDX];
        assign pe_ro_in = pe_ro[IDX];
        assign pe_di_in = pe_di[SL_BASE + DATA_W - 1 : SL_BASE];

        // -----------------------------
        // Router Node Instance
        // -----------------------------
        gold_router u_node (
          .clk   (clk),
          .reset (reset),

          // North link
          .n_si (n_si_in),
          .n_di (n_di_in),
          .n_ri (n_ri_out),                                    // OUTPUT to neighbor
          .n_so (n_so[IDX]),                                   // OUTPUT bit
          .n_do (n_do[SL_BASE + DATA_W - 1 : SL_BASE]),        // OUTPUT slice
          .n_ro (n_ro_in),                                     // INPUT from neighbor

          // South link
          .s_si (s_si_in),
          .s_di (s_di_in),
          .s_ri (s_ri_out),
          .s_so (s_so[IDX]),
          .s_do (s_do[SL_BASE + DATA_W - 1 : SL_BASE]),
          .s_ro (s_ro_in),

          // East link
          .e_si (e_si_in),
          .e_di (e_di_in),
          .e_ri (e_ri_out),
          .e_so (e_so[IDX]),
          .e_do (e_do[SL_BASE + DATA_W - 1 : SL_BASE]),
          .e_ro (e_ro_in),

          // West link
          .w_si (w_si_in),
          .w_di (w_di_in),
          .w_ri (w_ri_out),
          .w_so (w_so[IDX]),
          .w_do (w_do[SL_BASE + DATA_W - 1 : SL_BASE]),
          .w_ro (w_ro_in),

          // PE link
          .pe_si   (pe_si_in),
          .pe_di   (pe_di_in),
          .pe_ro   (pe_ro_in),
          .pe_ri   (pe_ri_out),
          .pe_so   (pe_so_out),
          .pe_do   (pe_do_out),
          .polarity(pe_pol_out)
        );

        // Backward connections (node outputs to arrays)
        assign n_ri[IDX] = n_ri_out;
        assign s_ri[IDX] = s_ri_out;
        assign e_ri[IDX] = e_ri_out;
        assign w_ri[IDX] = w_ri_out;

        // Router → NIC mapping
        assign pe_ri[IDX] = pe_ri_out;
        assign pe_so[IDX] = pe_so_out;
        assign pe_do[SL_BASE + DATA_W - 1 : SL_BASE] = pe_do_out;
        assign pe_polarity[IDX] = pe_pol_out;

      end
    end
  endgenerate

endmodule
