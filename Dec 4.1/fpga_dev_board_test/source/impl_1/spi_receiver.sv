/*
 * Module: spi_receiver
 * Description:
 * - Acts as an SPI Slave (Mode 0).
 * - Includes Byte Swapping to fix Endianness issues.
 */
module spi_receiver #(
    parameter BYTE_SWAP = 1 // Set to 1 if audio sounds like static
)(
    input  logic clk_12mhz,
    input  logic rst,

    // External SPI Pins
    input  logic spi_sck,
    input  logic spi_mosi,
    input  logic spi_cs,    // Active Low

    // FIFO Interface
    input  logic        fifo_full,
    output logic [15:0] fifo_data_out,
    output logic        fifo_write_en
);

    // --- 1. Signal Synchronization ---
    logic [1:0] sck_sync;
    logic [1:0] cs_sync;
    logic [1:0] mosi_sync;

    always_ff @(posedge clk_12mhz) begin
        sck_sync  <= {sck_sync[0],  spi_sck};
        cs_sync   <= {cs_sync[0],   spi_cs};
        mosi_sync <= {mosi_sync[0], spi_mosi};
    end

    wire sck_rising = (sck_sync[1] == 1'b0 && sck_sync[0] == 1'b1);
    wire cs_active  = (cs_sync[1] == 1'b0); 

    // --- 2. Deserialization Logic ---
    logic [15:0] shift_reg;
    logic [3:0]  bit_count;

    always_ff @(posedge clk_12mhz) begin
        fifo_write_en <= 0; 

        if (rst || !cs_active) begin
            bit_count <= 0;
        end else if (sck_rising) begin
            // Shift in new bit
            shift_reg <= {shift_reg[14:0], mosi_sync[1]};
            
            if (bit_count == 15) begin
                // Word Complete
                if (!fifo_full) begin
                    fifo_write_en <= 1;
                    
                    // --- BYTE SWAP LOGIC ---
                    if (BYTE_SWAP) begin
                        // Reconstruct as [Low Byte] [High Byte]
                        // shift_reg[7:0] was the FIRST byte received (now in lower bits?)
                        // Wait, standard shift: First bit ends up in [15].
                        // If we shift MSB first:
                        // Byte 1 (High?) -> ends up in [15:8]
                        // Byte 2 (Low?)  -> ends up in [7:0]
                        
                        // If STM32 sends Low Byte then High Byte:
                        // shift_reg[15:8] = Low Byte
                        // shift_reg[7:0]  = High Byte
                        // We want {High, Low}, so we keep [7:0] then [15:8]
                        
                        // Let's capture the very last bit into the swap logic
                        logic [15:0] raw_word;
                        raw_word = {shift_reg[14:0], mosi_sync[1]};
                        
                        // Swap: {Lower 8, Upper 8}
                        fifo_data_out <= {raw_word[7:0], raw_word[15:8]};
                    end else begin
                        // Passthrough
                        fifo_data_out <= {shift_reg[14:0], mosi_sync[1]}; 
                    end
                end
                bit_count <= 0;
            end else begin
                bit_count <= bit_count + 1;
            end
        end
    end

endmodule