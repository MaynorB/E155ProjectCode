/*
 * Module: top
 * Description: 
 * - Full pipeline: SPI -> FIFO -> RateSync -> FIR -> Mixer -> I2S.
 * - CLOCK: Internal 48MHz.
 * - PIN 43: Sync Trigger (Variable Rate).
 * - PIN 42: Mixer Control CS.
 */
module top (
    // input  logic clk_12mhz_pin,  // Unused (We use Internal Osc)
    
    // SPI Audio (Source)
    input  logic spi_sck_pin,      // Pin 38
    input  logic spi_mosi_pin,     // Pin 19
    input  logic spi_cs_pin,       // Pin 2
    
    // SPI Control (Mixer)
    input  logic spi_cs_mix_pin,   // Pin 42
    
    // Sync Trigger
    input  logic clk_48k_pin,      // Pin 43

    // I2S DAC Output
    output logic dac_bclk_pin,     // Pin 26
    output logic dac_lrck_pin,     // Pin 23
    output logic dac_din_pin      // Pin 25
);

    // --- Internal Oscillator (48MHz) ---
    logic clk_48mhz;
    HSOSC hf_osc (.CLKHFPU(1'b1), .CLKHFEN(1'b1), .CLKHF(clk_48mhz));

    // --- Signals ---
    logic signed [15:0] audio_raw_spi;
    logic               write_en_spi;
    logic               fifo_full;
    logic               fifo_empty;
    logic signed [15:0] fifo_out_data;
    logic               fifo_read_en;
    
    // Pipeline Signals
    logic signed [15:0] synced_sample;
    logic               sample_valid;
    
    logic signed [15:0] bass_sample;   // From Filter (Low Pass)
    logic signed [15:0] clean_sample;  // From Filter (Delayed Reference)
    logic signed [15:0] final_mixed_sample;
    
    logic [7:0]         mix_value;

    // 1. SPI Receiver (Audio)
    spi_receiver i_spi (
        .clk_12mhz(clk_48mhz), .rst(1'b0),
        .spi_sck(spi_sck_pin), .spi_mosi(spi_mosi_pin), .spi_cs(spi_cs_pin),
        .fifo_full(fifo_full), .fifo_data_out(audio_raw_spi), .fifo_write_en(write_en_spi)
    );
    
    // 2. SPI Control (Mixer Knob)
    spi_ctrl i_mixer_ctrl (
        .clk(clk_48mhz), .rst(1'b0),
        .spi_sck(spi_sck_pin), .spi_mosi(spi_mosi_pin), .spi_cs(spi_cs_mix_pin),
        .control_value(mix_value)
    );

    // 3. FIFO
    async_fifo i_fifo (
        .clk_write(clk_48mhz), .write_en(write_en_spi), .write_data(audio_raw_spi), .full(fifo_full),      
        .clk_read(clk_48mhz), .read_en(fifo_read_en), .read_data(fifo_out_data), .empty(fifo_empty), .rst(1'b0)
    );

    // 4. Rate Synchronizer (Variable Speed Safe)
    rate_synchronizer i_sync (
        .clk_12mhz(clk_48mhz), .mcu_48k_clk(clk_48k_pin),    
        .fifo_data(fifo_out_data), .fifo_empty(fifo_empty), .fifo_read_en(fifo_read_en), 
        .audio_out(synced_sample), .sample_valid(sample_valid)
    );
    
    // 5. FIR Filter (Configurable Delay)
    fir_filter #( 
        .DATA_WIDTH(16), 
        .TAPS_LOG2(7),     // 128 Taps
        .DELAY_SAMPLES(64) // <--- TUNE THIS FOR PHASE ALIGNMENT (1-127)
    ) i_filter (
        .clk(clk_48mhz), .rst(1'b0),
        .sample_valid(sample_valid),
        .data_in(synced_sample),
        
        .data_out(bass_sample),          // Output: Bass (Low Pass)
        .delayed_ref_out(clean_sample),  // Output: Clean (Delayed for Phase)
        .high_pass_out()                 // Unused (Calculated in Mixer)
    );

    // 6. Mixer (Calculates High Pass Internally)
    mixer i_mixer (
        .clk(clk_48mhz),
        .clean_in(clean_sample),
        .filtered_in(bass_sample),
        .mix_ratio(mix_value), // 0 = Treble, 255 = Bass
        .mixed_out(final_mixed_sample)
    );

    // 7. I2S Player (Standard Mono Output)
    i2s_player i_player (
        .clk_12mhz(clk_48mhz), 
        .audio_in(final_mixed_sample), 
        .dac_bclk(dac_bclk_pin), .dac_lrck(dac_lrck_pin), .dac_din(dac_din_pin)
    );

endmodule