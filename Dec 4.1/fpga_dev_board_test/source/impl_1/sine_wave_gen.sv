/*
 * Module: sine_wave_gen
 * Description:
 * Generates a clean Sine Wave, but triggers output based on 
 * SPI Activity (Mock Sniffer).
 * * - Counts 16 SPI SCK pulses -> Sends 1 Sine Sample.
 * - Mimics the MCU's bursty timing exactly.
 */
module sine_wave_gen (
    input  logic          clk_12mhz,
    
    // SPI Trigger Inputs (To mimic timing)
    input  logic          spi_sck,
    input  logic          spi_cs,

    // FIFO Interface
    input  logic          fifo_full,
    output logic signed [15:0] fifo_write_data,
    output logic          fifo_write_en,
    
    output logic          led
);

    // --- 1. SPI Signal Synchronization ---
    // We must sync external pins to 12MHz to detect edges safely
    logic [2:0] sck_sync;
    logic [2:0] cs_sync;

    always_ff @(posedge clk_12mhz) begin
        sck_sync <= {sck_sync[1:0], spi_sck};
        cs_sync  <= {cs_sync[1:0],  spi_cs};
    end

    wire sck_rising = (sck_sync[1] == 1'b1 && sck_sync[2] == 1'b0);
    wire cs_active  = (cs_sync[1] == 1'b0); // Active Low

    // --- 2. Bit Counter (The "Cue") ---
    logic [4:0] bit_count = 0;
    logic       sample_trigger;

    always_ff @(posedge clk_12mhz) begin
        sample_trigger <= 0;

        if (!cs_active) begin
            bit_count <= 0; // Reset if CS is high
        end else if (sck_rising) begin
            // Increment count on every SPI Clock
            if (bit_count == 15) begin
                // We found 16 bits (0-15)! 
                // This is our "Cue" that the MCU sent a sample.
                sample_trigger <= 1; 
                bit_count <= 0;
            end else begin
                bit_count <= bit_count + 1;
            end
        end
    end

    // --- 3. Phase Accumulator (Increments on Trigger) ---
    // We only step through the sine wave when the MCU sends data
    localparam logic [15:0] PHASE_INC = 16'd420;
    logic [15:0] phase_accum = 0;
    
    always_ff @(posedge clk_12mhz) begin
        if (sample_trigger && !fifo_full) begin
            phase_accum <= phase_accum + PHASE_INC;
        end
    end

    // --- 4. Sine ROM Look-Up ---
    logic [5:0] rom_addr;
    logic signed [15:0] rom_data;
    
    assign rom_addr = phase_accum[15:10]; 

    sine_rom i_rom (
        .addr(rom_addr),
        .data(rom_data)
    );

    // --- 5. Output to FIFO ---
    // Write valid sine data when the trigger fires
    assign fifo_write_data = rom_data;
    assign fifo_write_en   = sample_trigger & ~fifo_full;
    
    // Debug: LED flashes with Sine Frequency
    assign led = (rom_addr < 6'd16); 
    
endmodule