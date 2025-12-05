`timescale 1ns / 1ps

module tb_i2s_player_sva;

    // ==========================================
    // 1. SIGNALS
    // ==========================================
    logic clk_12mhz = 0;
    logic signed [15:0] audio_in = 0;
    
    // Outputs
    logic dac_bclk;
    logic dac_lrck;
    logic dac_din;

    // DUT Instantiation
    i2s_player dut (
        .clk_12mhz(clk_12mhz),
        .audio_in(audio_in),
        .dac_bclk(dac_bclk),
        .dac_lrck(dac_lrck),
        .dac_din(dac_din)
    );

    // ==========================================
    // 2. CLOCK GENERATION (12MHz)
    // ==========================================
    always #41.66 clk_12mhz = ~clk_12mhz;

    // ==========================================
    // 3. PROPERTIES (ASSERTIONS)
    // ==========================================

    // --- Property 1: BCLK Generation ---
    property p_bclk_period;
        @(posedge clk_12mhz)
        $rose(dac_bclk) |-> ##4 $fell(dac_bclk);
    endproperty

    assert property (p_bclk_period) else $error("BCLK Period Invalid");

    // --- Property 2: LRCK Alignment ---
    // LRCK must hold for 32 BCLK cycles.
    property p_lrck_stability;
        @(negedge dac_bclk) disable iff (dut.bit_cnt < 2)
        ($changed(dac_lrck)) |=> $stable(dac_lrck)[*15];
    endproperty

    assert property (p_lrck_stability) else $error("LRCK timing invalid.");

    // --- Property 4: MSB Check (Shifted) ---
    // The MSB should appear at bit_cnt == 1 (Left) or bit_cnt == 33 (Right)
    property p_msb_check;
        @(negedge dac_bclk)
        ((dut.bit_cnt == 1 || dut.bit_cnt == 33) && dut.latched_sample == 16'h8000) |-> (dac_din == 1);
    endproperty
    
    assert property (p_msb_check) else $error("Data Mismatch: MSB not present at Bit 1 (Standard I2S).");

    // ==========================================
    // 4. STIMULUS
    // ==========================================
    initial begin
        // Variables must be declared at the top of the block in static contexts
        logic expected_msb;

        $display("--- Starting Standard I2S Test (Multiple Frames) ---");
        
        // 1. Initialize
        audio_in = 16'h0000;
        #200;

        // Wait for startup stability
        repeat(50) @(posedge clk_12mhz);

        // 2. Loop for Multiple Frames
        for (int i = 0; i < 4; i++) begin
            
            // A. Set Input Data (Alternating Patterns)
            //    Frame 0 & 2: 0x8000 (Min Negative) -> MSB is 1
            //    Frame 1 & 3: 0x7FFF (Max Positive) -> MSB is 0
            wait(dut.bit_cnt == 60); // Set up well before next frame
            
            if (i % 2 == 0) begin
                audio_in = 16'h8000;
                $display("[Frame %0d] Input: 0x8000 (Expect MSB=1)", i);
            end else begin
                audio_in = 16'h7FFF;
                $display("[Frame %0d] Input: 0x7FFF (Expect MSB=0)", i);
            end

            // B. Wait for Start of Frame (bit_cnt == 0)
            wait(dut.bit_cnt == 0);
            
            // C. Verify Delay Bit (Should be 0)
            #100; // Allow prop delay
            if (dac_din !== 0) $error("FAIL Frame %0d: Delay bit was not 0!", i);
            
            // D. Wait for MSB (bit_cnt == 1)
            @(negedge dac_bclk);
            #100;
            
            // E. Verify MSB
            expected_msb = (i % 2 == 0) ? 1'b1 : 1'b0;
            
            if (dac_din !== expected_msb) 
                $error("FAIL Frame %0d: Expected MSB %b, Got %b", i, expected_msb, dac_din);
            else
                $display("PASS Frame %0d: MSB %b detected correctly.", i, dac_din);

        end

        #2000;
        $display("--- Test Complete ---");
        $finish;
    end

endmodule