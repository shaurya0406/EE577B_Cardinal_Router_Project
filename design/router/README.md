# EE577B Cardinal Router — RTL Overview


## Module Summary

| Module | File | Role | Key I/O | Timing / Handshake | Notes |
|:--|:--|:--|:--|:--|:--|
| **cardinal_router_mesh_xy** | `rtl/router/cardinal_router_mesh_xy.v` | **Top level mesh router tile.** Instantiates 2 VCs + phase controller. | 5× bidirectional ports `{n,s,e,w,pe}_{si,ri,di}` in / `{so,ro,do}` out; `clk,reset`, `polarity` out | Alternates VC0/VC1 each cycle using `vc_phase`. One VC’s `phase_external` = other’s `phase_internal`. | Muxes I/O so external VC drives physical links. Achieves 2-cycle hop latency. |
| **router_vc_block** | `rtl/router/router_vc_block.v` | 5×5 router plane for one VC. | `{n,s,e,w,pe}_{si,ri,di}` / `{so,ro,do}`; `phase_internal/external` | One “color” plane (even/odd). Phased pipeline: internal compute + external send. | Instantiates 5× `inbuf_cell`, 5× `outbuf_cell`, 5× `rr_arb_5`, `req_matrix`, `xbar_internal`. |
| **vc_phase** | `rtl/router/vc_phase.v` | Global phase toggle (even/odd). | `clk,reset`, `polarity` out | Toggles every cycle on `posedge clk`. | Defines which VC is currently external. |
| **inbuf_cell** | `rtl/router/inbuf_cell.v` | One-flit receive buffer per input/VC. | `si,di[63:0]` in; `ri` out; `deq` in; `full` out; `q[63:0]` out; `phase_external/internal` in | Accepts flit when `si & ri`. `ri=~full`. Dequeues on `phase_internal & deq`. | 1-deep FIFO. Reset clears `full`. |
| **outbuf_cell** | `rtl/router/outbuf_cell.v` | One-flit transmit buffer per output/VC. | `enq,d_in[63:0]` in; `so` out; `ro` in; `dout[63:0]` out; `phase_internal/external` in; `full` out | Enqueue when `phase_internal & enq & ~full`. Send when `phase_external & full & ro`. | Dequeues at handshake. Implements 2nd pipeline phase. |
| **route_xy** | `rtl/router/route_xy.v` | XY route computation + hop-counter update. | `dx,dy,hx[3:0],hy[3:0]` in; `req_{n,s,e,w,pe}` out; `hx_next,hy_next` out | Pure combinational. | If `hx>0` → E/W by `dx`; else if `hy>0` → N/S by `dy`; else `PE`. |
| **hdr_fields** | `rtl/router/hdr_fields.v` | Header bit-field decoder (64-bit flit). | `pkt[63:0]` in → `vc,dx,dy,rsv[4:0],hx,hy,srcx,srcy` out | Pure combinational. | Used inside `req_matrix`. |
| **req_matrix** | `rtl/router/req_matrix.v` | Builds per-output request vectors and next headers. | From each input: `{*_full, *_q}`; outputs: `req_to_*[4:0]`, `{*_pkt_next}` | Comb logic. | Uses `hdr_fields` + `route_xy`. Gates by `*_full`. |
| **rr_arb_5** | `rtl/router/rr_arb_5.v` | 5-way round-robin arbiter (one per output). | `req[4:0]`, `outbuf_full` in; `gnt[4:0]` out; `clk,reset` | Sequential pointer update. | Ignores requests if outbuf full. |
| **xbar_internal** | `rtl/router/xbar_internal.v` | Connects granted inputs → outbufs. | `req_to_*`, `gnt_to_*`, `{*_pkt_next}`, `outbuf_full_*`; outputs `enq_*,d_in_*`, `deq_*`; `phase_internal` | Active when `phase_internal=1`. | Asserts `enq` and `deq` per grant. |
| **vc_phase** | `rtl/router/vc_phase.v` | Toggles `polarity` every clock. | `clk,reset` | Free-running. | Drives per-VC `phase_internal/external`. |

---

## Packet Format

| Bits | Field | Meaning |
|:--:|:--|:--|
| [63] | `VC` | Virtual channel ID (0/1) |
| [62] | `DX` | X-direction (0 = East, 1 = West) |
| [61] | `DY` | Y-direction (0 = South, 1 = North) |
| [60:56] | `RSV` | Reserved for metadata |
| [55:52] | `HX` | Remaining hops in X |
| [51:48] | `HY` | Remaining hops in Y |
| [47:40] | `SRCX` | Source X coordinate |
| [39:32] | `SRCY` | Source Y coordinate |
| [31:0] | `PAYLOAD` | Application data |

---

## Dataflow (1 Hop)

1. **External phase:** incoming link → `inbuf_cell` (`si & ri`).  
2. **Internal phase:** `req_matrix` + `rr_arb_5` + `xbar_internal` enqueue selected output buffers.  
3. **Next external phase:** `outbuf_cell` drives link (`so & ro`), clears full.  
**2 cycles total**: accept + forward + send.

---

