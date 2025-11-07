//======================================================================
// llc_proxy.v — simple LLC responder
// - 1-flit request accepted when si&ri
// - emits BURST reply flits after LAT cycles
//======================================================================
`timescale 1ns/1ps
`ifndef LLC_PROXY_V
`define LLC_PROXY_V

module llc_proxy
#(
  parameter DATA_W = 64,
  parameter BURST  = 4,      // reply flits
  parameter LAT    = 3       // pipeline latency to first reply
)
(
  input  wire                 clk,
  input  wire                 reset,

  // request in
  input  wire                 si,
  output wire                 ri,
  input  wire [DATA_W-1:0]    di,

  // reply out
  output wire                 so,
  input  wire                 ro,
  output wire [DATA_W-1:0]    dout
);

  // Simple two-state: IDLE -> WAIT_LAT -> SEND_BURST
  reg [1:0] state;
  reg [7:0] lat_cnt;    // small counters (8-bit reg is fine; not 'integer')
  reg [7:0] burst_cnt;
  reg [DATA_W-1:0] hold;

  wire idle      = (state==2'd0);
  wire wait_lat  = (state==2'd1);
  wire send_b    = (state==2'd2);

  assign ri = idle;                      // accept only in IDLE
  assign so = send_b & ro;               // drive when sending and downstream ready
  assign dout = hold;                      // echo held word (could add tag/beat# if needed)

  always @(posedge clk) begin
    if (reset) begin
      state <= 2'd0;
      lat_cnt <= 8'd0;
      burst_cnt <= 8'd0;
      hold <= {DATA_W{1'b0}};
    end else begin
      if (idle) begin
        if (si & ri) begin
          hold <= di;                   // capture header/addr
          state <= 2'd1;                // WAIT_LAT
          lat_cnt <= LAT[7:0];
        end
      end else if (wait_lat) begin
        if (lat_cnt!=8'd0) lat_cnt <= lat_cnt - 8'd1;
        else begin
          state <= 2'd2;                // SEND_BURST
          burst_cnt <= BURST[7:0];
        end
      end else if (send_b) begin
        if (so) begin
          if (burst_cnt!=8'd0) burst_cnt <= burst_cnt - 8'd1;
          if (burst_cnt==8'd1) begin
            state <= 2'd0;              // done
          end
        end
      end
    end
  end

endmodule
`endif
