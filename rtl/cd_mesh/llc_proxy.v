//======================================================================
// llc_proxy.v — Fixed handshake/latency model (TB-compatible)
//======================================================================
`timescale 1ns/1ps
`ifndef LLC_PROXY_V
`define LLC_PROXY_V

module llc_proxy
#(
  parameter DATA_W    = 64,
  parameter [3:0] LAT0 = 4'd2,
  parameter [3:0] LAT1 = 4'd3,
  parameter [3:0] LAT2 = 4'd0,
  parameter [3:0] LAT3 = 4'd5
)
(
  input  wire                   clk,
  input  wire                   reset,

  input  wire  [3:0]            llc_so,   // xbar -> LLC valid
  output wire  [3:0]            llc_ro,   // LLC -> xbar ready
  input  wire  [4*DATA_W-1:0]   llc_do,   // xbar -> LLC data

  output wire  [3:0]            llc_si_r, // LLC -> xbar valid
  input  wire  [3:0]            llc_ri_r, // xbar -> LLC ready
  output wire  [4*DATA_W-1:0]   llc_di_r  // LLC -> xbar data
);

  // unpack request data
  wire [DATA_W-1:0] d0 = llc_do[DATA_W*1-1:DATA_W*0];
  wire [DATA_W-1:0] d1 = llc_do[DATA_W*2-1:DATA_W*1];
  wire [DATA_W-1:0] d2 = llc_do[DATA_W*3-1:DATA_W*2];
  wire [DATA_W-1:0] d3 = llc_do[DATA_W*4-1:DATA_W*3];

  // state 0=empty,1=busy,2=reply
  reg [1:0] s0,s1,s2,s3;
  reg [3:0] c0,c1,c2,c3;
  reg [DATA_W-1:0] q0,q1,q2,q3;

  // combinational outputs
  assign llc_ro   = { (s3==2'd0), (s2==2'd0), (s1==2'd0), (s0==2'd0) };
  assign llc_si_r = { (s3==2'd2), (s2==2'd2), (s1==2'd2), (s0==2'd2) };

  assign llc_di_r[DATA_W*1-1:DATA_W*0] = q0;
  assign llc_di_r[DATA_W*2-1:DATA_W*1] = q1;
  assign llc_di_r[DATA_W*3-1:DATA_W*2] = q2;
  assign llc_di_r[DATA_W*4-1:DATA_W*3] = q3;

  // ---------------- Port 0 ----------------
  always @(posedge clk) begin
    if (reset) begin
      s0<=0; c0<=0; q0<={DATA_W{1'b0}};
    end else begin
      case (s0)
        2'd0: if (llc_so[0]) begin
                s0 <= (LAT0==0) ? 2'd2 : 2'd1;
                c0 <= LAT0;
                q0 <= d0;
              end
        2'd1: if (c0==1) s0 <= 2'd2;
              else c0 <= c0 - 1;
        2'd2: if (llc_ri_r[0]) s0 <= 2'd0;
      endcase
    end
  end

  // ---------------- Port 1 ----------------
  always @(posedge clk) begin
    if (reset) begin
      s1<=0; c1<=0; q1<={DATA_W{1'b0}};
    end else begin
      case (s1)
        2'd0: if (llc_so[1]) begin
                s1 <= (LAT1==0) ? 2'd2 : 2'd1;
                c1 <= LAT1;
                q1 <= d1;
              end
        2'd1: if (c1==1) s1 <= 2'd2;
              else c1 <= c1 - 1;
        2'd2: if (llc_ri_r[1]) s1 <= 2'd0;
      endcase
    end
  end

  // ---------------- Port 2 ----------------
  always @(posedge clk) begin
    if (reset) begin
      s2<=0; c2<=0; q2<={DATA_W{1'b0}};
    end else begin
      case (s2)
        2'd0: if (llc_so[2]) begin
                s2 <= (LAT2==0) ? 2'd2 : 2'd1;
                c2 <= LAT2;
                q2 <= d2;
              end
        2'd1: if (c2==1) s2 <= 2'd2;
              else c2 <= c2 - 1;
        2'd2: if (llc_ri_r[2]) s2 <= 2'd0;
      endcase
    end
  end

  // ---------------- Port 3 ----------------
  always @(posedge clk) begin
    if (reset) begin
      s3<=0; c3<=0; q3<={DATA_W{1'b0}};
    end else begin
      case (s3)
        2'd0: if (llc_so[3]) begin
                s3 <= (LAT3==0) ? 2'd2 : 2'd1;
                c3 <= LAT3;
                q3 <= d3;
              end
        2'd1: if (c3==1) s3 <= 2'd2;
              else c3 <= c3 - 1;
        2'd2: if (llc_ri_r[3]) s3 <= 2'd0;
      endcase
    end
  end

endmodule
`endif
