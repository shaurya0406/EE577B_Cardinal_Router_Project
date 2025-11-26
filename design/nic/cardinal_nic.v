//============================================================
// Network Interface Controller (NIC)
//------------------------------------------------------------
// This module interfaces between the Processing Element (PE)
// and the router. It provides input and output buffering,
// ready/valid handshaking, and register-based communication.
//
// Address Map:
//   addr = 2'b00 → Data Read/Write
//   addr = 2'b01 → Input buffer status
//   addr = 2'b10 → Output buffer write
//   addr = 2'b11 → Output buffer status
//============================================================

module nic(
    input         clk,
    input         reset,

    input         nicEn,          // Enable signal for PE interface
    input         nicWrEN,        // Write enable (1=write, 0=read)
    input         net_polarity,   // Network polarity bit

    // Router → NIC interface
    input         net_si,         // Router valid (data from router valid)
    input         net_ro,         // Router ready (router ready to accept)
    input  [1:0]  addr,           // Address for NIC register access
    input  [63:0] net_di,         // Data from router
    input  [63:0] d_in,           // Data from PE

    // NIC → PE and router interface
    output reg [63:0] d_out,      // Data to PE
    output reg        net_ri,     // NIC ready (for router to send data)
    output            net_so,     // NIC valid (data available for router)
    output [63:0]     net_do      // Data to router
);

    //------------------------------------------------------------
    // Internal Buffers and Status Flags
    //------------------------------------------------------------
    reg [63:0] input_channel_buffer;
    reg [63:0] output_channel_buffer;

    reg input_status;   // 1 = input buffer full
    reg output_status;  // 1 = output buffer full


    //------------------------------------------------------------
    // Combinational Logic: NIC → Router (TX path)
    //------------------------------------------------------------
    // net_so (valid) is high when output buffer has data and
    // the polarity bit matches the MSB of the packet.
    // net_do always reflects the contents of the output buffer.
    //------------------------------------------------------------
    assign net_so = output_status && (net_polarity == output_channel_buffer[63]);
    assign net_do = output_channel_buffer;


    //------------------------------------------------------------
    // Sequential Logic: Main State Machine
    //------------------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            //----------------------------------------------------
            // Reset all internal state and outputs
            //----------------------------------------------------
            input_status          <= 1'b0;
            output_status         <= 1'b0;
            input_channel_buffer  <= 64'h0;
            output_channel_buffer <= 64'h0;
            d_out                 <= 64'h0;
            net_ri                <= 1'b1;  // Empty → ready
        end 
        else begin
            //----------------------------------------------------
            // 1. Router → NIC (Receive Path)
            //----------------------------------------------------
            // Accept data only when router asserts valid (net_si)
            // and NIC is ready (net_ri).
            //----------------------------------------------------
            if (net_si && net_ri) begin
                input_channel_buffer <= net_di;
                input_status         <= 1'b1;
                net_ri               <= 1'b0; // Buffer now full
            end

            //----------------------------------------------------
            // 2. PE Reads Input Data
            //----------------------------------------------------
            // When PE reads addr=00 and input buffer has data,
            // provide it and clear the buffer.
            //----------------------------------------------------
            if (nicEn && !nicWrEN && addr == 2'b00) begin
                if (input_status) begin
                    d_out        <= input_channel_buffer;
                    input_status <= 1'b0;
                    net_ri       <= 1'b1; // Buffer empty again
                end 
                else begin
                    d_out <= 64'h0; // Read from empty buffer → return 0
                end
            end

            //----------------------------------------------------
            // 3. PE Writes to Output Buffer
            //----------------------------------------------------
            // When PE writes addr=10, store packet to send to router.
            //----------------------------------------------------
            if (nicEn && nicWrEN && addr == 2'b10) begin
                if (!output_status) begin
                    output_channel_buffer <= d_in;
                    output_status         <= 1'b1; // Have data to send
                end
                // Else: Ignore write if output buffer full
            end

            //----------------------------------------------------
            // 4. Router Accepts Packet (TX Handshake)
            //----------------------------------------------------
            // Clear output buffer only when both NIC valid (net_so)
            // and router ready (net_ro) are asserted in same cycle.
            //----------------------------------------------------
            if (output_status && net_so && net_ro) begin
                output_status <= 1'b0;
            end

            //----------------------------------------------------
            // 5. Status Register Reads
            //----------------------------------------------------
            // addr = 01 → Input buffer status
            // addr = 11 → Output buffer status
            //----------------------------------------------------
            if (nicEn && !nicWrEN && addr == 2'b01) begin
                d_out <= {63'b0, input_status};
            end

            if (nicEn && !nicWrEN && addr == 2'b11) begin
                d_out <= {63'b0, output_status};
            end
        end
    end

endmodule

