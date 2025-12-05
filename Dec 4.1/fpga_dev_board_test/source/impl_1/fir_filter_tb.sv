`timescale 1ns / 1ps

module fir_filter_tb;

    // ==========================================
    // 1. PARAMETERS & SIGNALS
    // ==========================================
    parameter DATA_WIDTH = 16;
    parameter SAMPLE_RATE = 48000;
    
    logic clk;
    logic rst;
    logic sample_valid;
    logic signed [15:0] data_in;
    
    logic signed [15:0] data_out;        // Low Pass Output
    logic signed [15:0] high_pass_out;   // (Clean - LowPass)
    logic signed [15:0] delayed_ref_out; // Delayed Clean Input

    // Internal Variables for Sine Generation
    real PI;
    real amplitude;

    // DUT Instantiation
    fir_filter #(
        .DATA_WIDTH(16),
        .TAPS_LOG2(7)
    ) dut (
        .clk(clk),
        .rst(rst),
        .sample_valid(sample_valid),
        .data_in(data_in),
        .data_out(data_out),
        .high_pass_out(high_pass_out),
        .delayed_ref_out(delayed_ref_out)
    );

    // ==========================================
    // 2. CLOCK GENERATION
    // ==========================================
    // 48MHz System Clock (Period = ~20.8ns)
    initial clk = 0;
    always #10.416 clk = ~clk;

    // ==========================================
    // 3. SAMPLE TASK
    // ==========================================
    // Simulates the Rate Synchronizer triggering every 48kHz (~20.8us)
    task send_sample(input logic signed [15:0] val);
        begin
            // 1. Setup Data
            sample_valid = 1;
            data_in = val;
            
            // 2. Pulse Width (1 Clock Cycle is enough for logic to catch it)
            @(posedge clk); 
            #1; // Hold slightly past edge
            sample_valid = 0;
            
            // 3. Wait for the rest of the audio sample period (48kHz)
            // 20.83us = 20830ns
            // We subtract the small time we already spent
            #20800; 
        end
    endtask

    // ==========================================
    // 4. MAIN STIMULUS
    // ==========================================
    initial begin
        // --- Initialize Constants ---
        PI = 3.1415926535;
        amplitude = 4000.0;

        // --- FIX FOR X PROPAGATION (Initialize RAM) ---
        // In simulation, RAM starts as X. 
        // Logic: Acc = Acc - RAM_Out + New.
        // If RAM_Out is X, Accumulator becomes X forever.
        // We force the internal DUT memory to 0 here.
        for (int k = 0; k < 128; k++) begin
            dut.ram[k] = 0;
        end

        // --- Initialize Signals ---
        rst = 1;
        sample_valid = 0;
        data_in = 0;
        
        #200;
        rst = 0;
        #200;

        $display("--- Starting FIR Filter Sine Wave Test ---");
        
        // ------------------------------------------------------------
        // FREQUENCY SWEEP (SINE)
        // Frequencies: 50, 150, 350, 700, 1500 Hz
        // ------------------------------------------------------------
        
        generate_sine_burst(50);   // Very Deep Bass
        generate_sine_burst(150);  // Bass
        generate_sine_burst(350);  // Low Mid
        generate_sine_burst(700);  // Mid
        generate_sine_burst(1500); // High

        $display("--- Test Complete. Inspect Waveform for 'data_in' sinusoids. ---");
        $finish;
    end


    // ==========================================
    // HELPER: SINE WAVE GENERATOR
    // ==========================================
    task generate_sine_burst(input int freq);
        int samples_per_cycle;
        int total_samples;
        real angle_step;
        real current_angle;
        int i;
        logic signed [15:0] sine_val;
        begin
            $display("[Time %0t] Generating %0d Hz Sine Wave...", $time, freq);
            
            // Calculate parameters
            samples_per_cycle = SAMPLE_RATE / freq;
            total_samples = samples_per_cycle * 5; // 5 Cycles
            
            // 2*PI / samples_per_cycle
            angle_step = (2.0 * PI) / samples_per_cycle;
            current_angle = 0;

            // Generate Loop
            for (i = 0; i < total_samples; i++) begin
                // Calculate Sine
                sine_val = $rtoi(amplitude * $sin(current_angle));
                
                // Send to DUT
                send_sample(sine_val);
                
                // Advance Angle
                current_angle = current_angle + angle_step;
            end
            
            // Gap between frequencies for visual clarity
            repeat(10) send_sample(0);
        end
    endtask

endmodule