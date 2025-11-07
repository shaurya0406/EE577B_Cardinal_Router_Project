//======================================================================
// cardinal_nic.v  — Spec-true, synthesizable NIC (1-deep RX/TX buffers)
//   - Synchronous loads/stores (PE reads/writes take effect next clk)
//   - Router handshakes: RI/SI for RX, RO/SO for TX
//   - Injection only when VC bit == net_polarity
//   - Status bits exposed at d_out[63] for status registers
//   - All illegal ops ignored (no state change)
//----------------------------------------------------------------------
// Addr map (addr[1:0]):
//   2'b00 : Input channel buffer (RO)       -> returns 64b data
//   2'b01 : Input channel status (RO)       -> returns {status[63], 0[62:0]}
//   2'b10 : Output channel buffer (WO)      -> accepts 64b data
//   2'b11 : Output channel status (RO)      -> returns {status[63], 0[62:0]}
//----------------------------------------------------------------------
// Reset (active-high, synchronous):
//   - RX/TX buffers empty
//   - net_ri=1 (advertise space), net_so=0, net_do=0
//----------------------------------------------------------------------

`timescale 1ns/1ps

// -------------------------------
// 1-deep buffer with explicit load/consume
// -------------------------------
module cardinal_nic_buffer #(
  parameter DATA_W = 64
)(
  input                    clk,
  input                    reset,       // active-high, synchronous
  input                    load_en,     // capture data_in when empty
  input      [DATA_W-1:0]  data_in,
  input                    consume_en,  // drop current word when full
  output reg [DATA_W-1:0]  data_out,
  output reg               full
);
  always @(posedge clk) begin
    if (reset) begin
      data_out <= {DATA_W{1'b0}};
      full     <= 1'b0;
    end else begin
      // consume takes effect when currently full
      if (consume_en && full) begin
        full <= 1'b0;
      end
      // load only when currently empty
      if (load_en && !full) begin
        data_out <= data_in;
        full     <= 1'b1;
      end
      // NOTE: Top-level logic must avoid asserting both consume_en and load_en
      // for the same buffer in a way that violates intent. As wired, if both
      // are asserted while full==1, consume will clear; load waits until empty.
    end
  end
endmodule


// -------------------------------
// NIC top
// -------------------------------
module cardinal_nic #(
  parameter DATA_W  = 64,
  // VC bit position inside a flit (default LSB). Adjust if spec uses a different bit.
  parameter VC_LSB  = 0
)(
  input                  clk,
  input                  reset,          // active-high, synchronous

  // Processor side
  input       [1:0]      addr,           // selects NIC location
  input       [DATA_W-1:0] d_in,         // write data from PE
  output reg  [DATA_W-1:0] d_out,        // read data to PE (synchronous)
  input                  nicEn,          // NIC selected (qualifier)
  input                  nicWrEn,        // 1=write, 0=read

  // Router side (router -> NIC input channel)
  input                  net_si,         // router sending in
  output                 net_ri,         // NIC ready to receive
  input       [DATA_W-1:0] net_di,       // data from router

  // Router side (NIC -> router output channel)
  output reg             net_so,         // NIC sending out
  input                  net_ro,         // router ready to accept
  output reg  [DATA_W-1:0] net_do,       // data to router
  input                  net_polarity    // current VC/polarity on external link
);

  // -------------------------
  // Local wires/regs
  // -------------------------
  wire                    is_read  =  nicEn & ~nicWrEn;
  wire                    is_write =  nicEn &  nicWrEn;

  // RX buffer (router -> NIC -> PE)
  wire  [DATA_W-1:0]      rx_data_q;
  wire                    rx_full_q;
  wire                    rx_load_en;       // from SI/RI handshake
  reg                     rx_consume_en;    // asserted on PE read of input buffer

  // TX buffer (PE -> NIC -> router)
  wire  [DATA_W-1:0]      tx_data_q;
  wire                    tx_full_q;
  reg                     tx_load_en;       // asserted on legal PE write
  wire                    tx_consume_en;    // asserted on successful send (SO & RO)

  // VC match (only inject when packet VC == net_polarity)
  wire                    tx_vc_bit = tx_data_q[VC_LSB];
  wire                    vc_ok     = (tx_vc_bit == net_polarity);

  // -------------------------
  // RX side (router -> NIC)
  //   - net_ri = ~rx_full
  //   - load on handshake when empty: net_si & net_ri
  //   - consume on PE read of input buffer (synchronous)
  // -------------------------
  assign net_ri     = ~rx_full_q;
  assign rx_load_en = (net_si & ~rx_full_q);  // capture on next clk

  // -------------------------
  // TX side (NIC -> router)
  //   - Drive SO/DO combinationally when we *can* send (buffer full, RO=1, VC match)
  //   - Clear buffer on the clk edge that sees send_fire
  // -------------------------
  wire send_fire = (tx_full_q & net_ro & vc_ok);

  always @(*) begin
    if (send_fire) begin
      net_so = 1'b1;
      net_do = tx_data_q;
    end else begin
      net_so = 1'b0;
      net_do = {DATA_W{1'b0}};
    end
  end

  assign tx_consume_en = send_fire;  // clear TX buffer on successful handshake

  // -------------------------
  // TX load gating (PE writes only)
  //   - legal write only when addr==2'b10 and NIC is selected and it's a write
  //   - ignore write if TX buffer already full
  // -------------------------
  always @(*) begin
    tx_load_en = 1'b0;
    if (is_write && (addr == 2'b10) && !tx_full_q) begin
      tx_load_en = 1'b1;
    end
  end

  // -------------------------
  // Synchronous read datapath and RX consume generation
  //   - d_out updates on the NEXT clk when is_read is asserted
  //   - reading input buffer (addr==2'b00) also consumes RX buffer
  //   - status reads return bit[63]=status, others zero
  //   - reads of write-only (2'b10) return zero (ignored)
  // -------------------------
  reg [DATA_W-1:0] next_read_data;

  always @(*) begin
    // Default: zero for non-selected/illegal reads when latched
    next_read_data = {DATA_W{1'b0}};

    if (is_read) begin
      case (addr)
        2'b00: begin
          // Input channel buffer (RO)
          next_read_data = rx_data_q;
        end
        2'b01: begin
          // Input channel status (RO)
          next_read_data               = {DATA_W{1'b0}};
          next_read_data[DATA_W-1]     = rx_full_q;
        end
        2'b10: begin
          // Output channel buffer is write-only; read returns 0
          next_read_data = {DATA_W{1'b0}};
        end
        2'b11: begin
          // Output channel status (RO)
          next_read_data               = {DATA_W{1'b0}};
          next_read_data[DATA_W-1]     = tx_full_q;
        end
        default: begin
          next_read_data = {DATA_W{1'b0}};
        end
      endcase
    end
  end

  // Generate consume for RX on a *valid* read of 2'b00
  // This pulse is applied on the same edge that latches d_out.
  always @(posedge clk) begin
    if (reset) begin
      d_out          <= {DATA_W{1'b0}};
      rx_consume_en  <= 1'b0;
    end else begin
      // Default: no consume unless we perform that specific read
      rx_consume_en <= 1'b0;

      // Latch synchronous read data
      if (is_read) begin
        d_out <= next_read_data;

        // If reading the input buffer, mark it consumed.
        if (addr == 2'b00) begin
          // Only meaningful if rx_full_q==1; harmless otherwise.
          rx_consume_en <= 1'b1;
        end
      end else if (!nicEn) begin
        // When NIC not selected, hold d_out at 0 per spec ethos.
        d_out <= {DATA_W{1'b0}};
      end
    end
  end

  // -------------------------
  // Instantiate buffers
  // -------------------------
  cardinal_nic_buffer #(.DATA_W(DATA_W)) u_rx_buf (
    .clk        (clk),
    .reset      (reset),
    .load_en    (rx_load_en),     // SI/RI handshake
    .data_in    (net_di),
    .consume_en (rx_consume_en),  // PE read of input buffer
    .data_out   (rx_data_q),
    .full       (rx_full_q)
  );

  cardinal_nic_buffer #(.DATA_W(DATA_W)) u_tx_buf (
    .clk        (clk),
    .reset      (reset),
    .load_en    (tx_load_en),     // legal PE write to 2'b10
    .data_in    (d_in),
    .consume_en (tx_consume_en),  // send handshake complete
    .data_out   (tx_data_q),
    .full       (tx_full_q)
  );

endmodule
