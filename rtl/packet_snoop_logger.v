//============================================================
// packet_snoop_logger
//------------------------------------------------------------
// Logs:
//   1) Packets injected into the network (NIC -> Router)
//   2) Packets delivered to the processor (NIC -> PE)
//
// Uses hdr_fields to decode header bits and prints:
//   time, tile (x,y), type(INJ/DEL), pkt, vc, dx, dy, hx, hy, srcx, srcy
//
// Simulation-only (guarded by `ifndef SYNTHESIS`).
//============================================================

module packet_snoop_logger #(
    parameter integer TILE_X = 0,
    parameter integer TILE_Y = 0
)(
    input  wire        clk,
    input  wire        reset,

    // -------- NIC -> Router (injection) --------
    input  wire        net_so,      // NIC valid towards router
    input  wire        net_ro,      // router ready
    input  wire [63:0] net_do,      // packet from NIC to router

    // -------- NIC -> Processor (delivery) ------
    input  wire        nic_en,        // NIC access enable
    input  wire        nic_wr_en,     // 1 = write, 0 = read
    input  wire [1:0]  nic_addr,      // NIC register address
    input  wire [63:0] nic_to_pe_data // NIC data returned to PE
);

`ifndef SYNTHESIS

    // File handles
    integer inject_fd;
    integer deliver_fd;

    //--------------------------------------------------------
    // Header decoders
    //--------------------------------------------------------

    // Injected packet header fields
    wire inj_vc, inj_dx, inj_dy;
    wire [4:0] inj_rsv;
    wire [3:0] inj_hx, inj_hy;
    wire [7:0] inj_srcx, inj_srcy;

    hdr_fields u_hdr_inject (
        .pkt  (net_do),
        .vc   (inj_vc),
        .dx   (inj_dx),
        .dy   (inj_dy),
        .rsv  (inj_rsv),
        .hx   (inj_hx),
        .hy   (inj_hy),
        .srcx (inj_srcx),
        .srcy (inj_srcy)
    );

    // Delivered packet header fields
    wire del_vc, del_dx, del_dy;
    wire [4:0] del_rsv;
    wire [3:0] del_hx, del_hy;
    wire [7:0] del_srcx, del_srcy;

    hdr_fields u_hdr_deliver (
        .pkt  (nic_to_pe_data),
        .vc   (del_vc),
        .dx   (del_dx),
        .dy   (del_dy),
        .rsv  (del_rsv),
        .hx   (del_hx),
        .hy   (del_hy),
        .srcx (del_srcx),
        .srcy (del_srcy)
    );

    //--------------------------------------------------------
    // Open log files
    //--------------------------------------------------------
    initial begin
        inject_fd  = $fopen("inject_log.txt",  "w");
        if (inject_fd == 0) begin
            $display("ERROR: Could not open inject_log.txt");
            $finish;
        end

        deliver_fd = $fopen("deliver_log.txt", "w");
        if (deliver_fd == 0) begin
            $display("ERROR: Could not open deliver_log.txt");
            $finish;
        end

        $display("[SNOOP] Tile (%0d,%0d): inject_log.txt / deliver_log.txt",
                 TILE_X, TILE_Y);
    end

    //--------------------------------------------------------
    // Injection logger: NIC -> Router
    // Handshake: net_so && net_ro
    //--------------------------------------------------------
    always @(posedge clk) begin
        if (!reset) begin
            if (net_so && net_ro) begin
                // Format: time tile_x tile_y INJ packet vc dx dy hx hy srcx srcy
                $fwrite(inject_fd,
                        "%0t (%0d,%0d) INJ %016h vc=%0d dx=%0d dy=%0d hx=%0d hy=%0d srcx=%0d srcy=%0d\n",
                        $time,
                        TILE_X, TILE_Y,
                        net_do,
                        inj_vc, inj_dx, inj_dy,
                        inj_hx, inj_hy,
                        inj_srcx, inj_srcy);
            end
        end
    end

    //--------------------------------------------------------
    // Delivery logger: NIC -> Processor
    // Log when PE reads NIC data register (addr = 2'b00)
    //--------------------------------------------------------
    always @(posedge clk) begin
        if (!reset) begin
            if (nic_en && (nic_wr_en == 1'b0) && (nic_addr == 2'b00)) begin
                $fwrite(deliver_fd,
                        "%0t (%0d,%0d) DEL %016h vc=%0d dx=%0d dy=%0d hx=%0d hy=%0d srcx=%0d srcy=%0d\n",
                        $time,
                        TILE_X, TILE_Y,
                        nic_to_pe_data,
                        del_vc, del_dx, del_dy,
                        del_hx, del_hy,
                        del_srcx, del_srcy);
            end
        end
    end

`endif  // !SYNTHESIS

endmodule
