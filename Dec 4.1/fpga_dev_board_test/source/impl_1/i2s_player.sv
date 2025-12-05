/*
 * Module: i2s_player
 * Description:
 * - Simple Parallel-to-I2S Serializer.
 * - Input: Continuous Audio Value (from Mixer).
 * - Output: Standard I2S (BCLK, LRCK, DIN).
 * - Format: 16-bit Mono (Duplicated to L/R channels).
 */
module i2s_player (
    input  logic clk_12mhz,        // 48MHz System Clock
    input  logic signed [15:0] audio_in, // Continuous Input
    
    output logic dac_bclk,
    output logic dac_lrck,
    output logic dac_din
);

    // 1. Clock Generation
    // We need BCLK = 12MHz / 8 = 1.5MHz (approx) or /4?
    // Standard I2S: 48kHz * 32 bits * 2 channels = 3.072 MHz.
    // Your code used clk_div[2] (divide by 8) -> 1.5MHz BCLK.
    // 1.5MHz / 64 bits = 23.4kHz Sample Rate. 
    // This seems slow, but I will preserve your existing timing logic.
    reg [2:0] clk_div = 0;
    always @(posedge clk_12mhz) clk_div <= clk_div + 1;
    
    assign dac_bclk = clk_div[2]; 

    // 2. Frame Logic
    reg [5:0] bit_cnt = 0;
    reg [15:0] shift_reg = 0;
    reg [15:0] latched_sample = 0; 
    
    // LRCK: Low for Left (0-31), High for Right (32-63)
    assign dac_lrck = bit_cnt[5]; 

    always @(negedge dac_bclk) begin
        bit_cnt <= bit_cnt + 1;
        
        // Start of Left Frame (Bit 0)
        if (bit_cnt == 0) begin 
            latched_sample <= audio_in; // Capture sample for stable L/R playback
            shift_reg <= audio_in;      // Load into shifter
        end
        // Start of Right Frame (Bit 32)
        else if (bit_cnt == 32) begin
            shift_reg <= latched_sample; // Repeat the same sample (Mono)
        end
        // Shift Bits
        else begin
            shift_reg <= {shift_reg[14:0], 1'b0};
        end
    end

    // MSB First
    assign dac_din = shift_reg[15];

endmodule