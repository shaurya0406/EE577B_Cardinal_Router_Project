//============================================================
// Cardinal Node = Processor + NIC + Router + Memories
// - Integrates: PE, nic, gold_router, imem, dmem
// - Exposes N/S/E/W router ports so this node can later
//   be dropped into the 4x4 mesh.
// - Focus here: correct PE <-> NIC <-> Router wiring
//   for NIC instructions.
//============================================================

module cardinal_node #(
    parameter integer TILE_X = 0,
    parameter integer TILE_Y = 0
)(
    input  wire clk,
    input  wire reset,

    // Router mesh connections (to neighbors)
    // North
    input  wire        n_si,
    input  wire [63:0] n_di,
    output wire        n_ri,
    output wire        n_so,
    output wire [63:0] n_do,
    input  wire        n_ro,

    // South
    input  wire        s_si,
    input  wire [63:0] s_di,
    output wire        s_ri,
    output wire        s_so,
    output wire [63:0] s_do,
    input  wire        s_ro,

    // East
    input  wire        e_si,
    input  wire [63:0] e_di,
    output wire        e_ri,
    output wire        e_so,
    output wire [63:0] e_do,
    input  wire        e_ro,

    // West
    input  wire        w_si,
    input  wire [63:0] w_di,
    output wire        w_ri,
    output wire        w_so,
    output wire [63:0] w_do,
    input  wire        w_ro
);

    // --------------------------------------------------------
    // Wires between PE and memories
    // --------------------------------------------------------
    wire [0:31] instr_addr;
    wire [0:31] instr;

    wire [0:31] data_addr;
    wire [0:63] data_in_from_dmem;
    wire [0:63] data_out_to_dmem;
    wire        mem_en;
    wire        mem_wr_en;

    // --------------------------------------------------------
    // Wires between PE and NIC (processor-side NIC interface)
    // --------------------------------------------------------
    wire  [0:1]  nic_addr;
    wire  [0:63] pe_to_nic_data;    // d_in (PE -> NIC)
    wire  [0:63] nic_to_pe_data;    // d_out (NIC -> PE)
    wire         nic_en;
    wire         nic_wr_en;

    // --------------------------------------------------------
    // Wires between NIC and Router (network side)
    // --------------------------------------------------------
    wire         net_si;       // router -> NIC (send)
    wire         net_ri;       // NIC -> router (ready)
    wire [63:0]  net_di;       // router -> NIC data

    wire         net_so;       // NIC -> router (send)
    wire         net_ro;       // router -> NIC (ready)
    wire [63:0]  net_do;       // NIC -> router data

    wire         net_polarity; // from router to NIC

    // ========================================================
    // 1) Processor (PE)
    //    Assumption: This PE already decodes memAddr[17:16]
    //    internally to generate nic_en / nic_wr_en / nic_addr
    //    as per NIC spec. :contentReference[oaicite:0]{index=0}
    // ========================================================
    PE u_pe (
        .clk        (clk),
        .reset      (reset),

        // Instruction memory
        .instr_addr (instr_addr),
        .instr      (instr),

        // Data memory
        .data_addr  (data_addr),
        .data_in    (data_in_from_dmem),
        .data_out   (data_out_to_dmem),
        .mem_en     (mem_en),
        .mem_wr_en  (mem_wr_en),

        // NIC interface (processor-side)
        .nic_addr   (nic_addr),
        .d_in       (pe_to_nic_data),
        .d_out      (nic_to_pe_data),
        .nic_en     (nic_en),
        .nic_wr_en  (nic_wr_en)
    );

    // ========================================================
    // 2) Instruction Memory (async read)
    // ========================================================
    imem u_imem (
        .memAddr (instr_addr),
        .dataOut (instr)
    );

    // ========================================================
    // 3) Data Memory (sync read/write)
    // ========================================================
    dmem u_dmem (
        .clk     (clk),
        .memEn   (mem_en),
        .memWrEn (mem_wr_en),
        .memAddr (data_addr),
        .dataIn  (data_out_to_dmem),
        .dataOut (data_in_from_dmem)
    );

    // ========================================================
    // 4) NIC
    //    Processor side: nicEn/nicWrEN/addr/d_in/d_out
    //    Router side:    net_si/ri/di, net_so/ro/do, net_polarity
    // ========================================================
    nic u_nic (
        .clk         (clk),
        .reset       (reset),

        // Processor-side interface
        .nicEn       (nic_en),
        .nicWrEn     (nic_wr_en),
        .net_polarity(net_polarity),

        // Router -> NIC (network input channel)
        .net_si      (net_si),        // router send
        .net_ro      (net_ro),        // router ready for NIC->router path
        .addr        (nic_addr[1:0]),
        .net_di      (net_di),        // data from router
        .d_in        (pe_to_nic_data),// data from PE (stores to NIC)

        // NIC -> PE and router
        .d_out       (nic_to_pe_data),// data to PE (loads from NIC)
        .net_ri      (net_ri),        // NIC ready for router->NIC path
        .net_so      (net_so),        // NIC send to router
        .net_do      (net_do)         // data to router
    );

    // ========================================================
    // 5) Router
    //
    // Mapping PE port of router <-> NIC network side:
    //
    //  - NIC output channel (processor -> network):
    //        NIC.net_do/net_so/net_ro/net_polarity
    //        connect to router PE *input* (pedi/pesi/peri) and polarity.
    //
    //  - NIC input channel (network -> processor):
    //        NIC.net_di/net_si/net_ri
    //        connect to router PE *output* (pedo/peso/pero).
    //
    // From router spec: PE channel signals :contentReference[oaicite:1]{index=1}
    //    input  pe_si,  input [63:0] pe_di,  output pe_ri  (PE -> router)
    //    output pe_so,  output [63:0] pe_do, input  pe_ro  (router -> PE)
    //
    // Network output channel (processor->router) in NIC spec: :contentReference[oaicite:2]{index=2}
    //    NIC.net_do/net_so, with NIC.net_ro as ready input from router.
    //
    // Network input channel (router->processor) in NIC spec:
    //    NIC.net_di/net_si, with NIC.net_ri as ready output to router.
    //
    // So:
    //   router.pe_si  <-- NIC.net_so
    //   router.pe_di  <-- NIC.net_do
    //   router.pe_ri  --> NIC.net_ro
    //
    //   router.pe_so  --> NIC.net_si
    //   router.pe_do  --> NIC.net_di
    //   router.pe_ro  <-- NIC.net_ri
    //
    //   router.polarity --> NIC.net_polarity
    // ========================================================

    gold_router u_router (
        .clk     (clk),
        .reset   (reset),

        // N/S/E/W mesh ports are just passed through this node
        // to be wired to neighbors by the mesh-level module.

        // Inputs from neighbors / PE
        .n_si    (n_si),
        .n_di    (n_di),
        .n_ri    (n_ri),

        .s_si    (s_si),
        .s_di    (s_di),
        .s_ri    (s_ri),

        .e_si    (e_si),
        .e_di    (e_di),
        .e_ri    (e_ri),

        .w_si    (w_si),
        .w_di    (w_di),
        .w_ri    (w_ri),

        // PE input channel = NIC -> router
        .pe_si   (net_so),   // NIC sends when it has a packet
        .pe_di   (net_do),   // packet from NIC to router
        .pe_ri   (net_ro),   // router ready -> NIC.net_ro

        // Outputs to neighbors / PE
        .n_so    (n_so),
        .n_do    (n_do),
        .n_ro    (n_ro),

        .s_so    (s_so),
        .s_do    (s_do),
        .s_ro    (s_ro),

        .e_so    (e_so),
        .e_do    (e_do),
        .e_ro    (e_ro),

        .w_so    (w_so),
        .w_do    (w_do),
        .w_ro    (w_ro),

        // PE output channel = router -> NIC
        .pe_so   (net_si),   // router sends towards NIC
        .pe_do   (net_di),   // packet from router to NIC
        .pe_ro   (net_ri),   // NIC ready -> router.pe_ro

        // Polarity to NIC
        .polarity(net_polarity)
    );

    // ========================================================
    // 6) Snooping logic (simulation-only logging)
    //     - net_so/net_ro/net_do : NIC -> Router injections
    //     - nic_en/nic_wr_en/nic_addr/nic_to_pe_data :
    //         packets delivered to the processor (NIC -> PE)
    // ========================================================
    packet_snoop_logger #(
        .TILE_X (TILE_X),
        .TILE_Y (TILE_Y)
    ) u_pkt_snoop (
        .clk            (clk),
        .reset          (reset),

        // NIC -> Router
        .net_so         (net_so),
        .net_ro         (net_ro),
        .net_do         (net_do),

        // NIC -> Processor
        .nic_en         (nic_en),
        .nic_wr_en      (nic_wr_en),
        .nic_addr       (nic_addr[1:0]),
        .nic_to_pe_data (nic_to_pe_data)
    );


endmodule
