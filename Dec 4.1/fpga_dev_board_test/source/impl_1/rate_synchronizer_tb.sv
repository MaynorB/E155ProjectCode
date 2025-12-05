`timescale 1ns / 1ps

module rate_synchronizer_tb;

    // Signals
    logic clk_12mhz;
    logic mcu_48k_clk;
    logic signed [15:0] fifo_data;
    logic fifo_empty;
    
    // Outputs
    logic fifo_read_en;
    logic signed [15:0] audio_out;
    logic sample_valid;

    // FIFO Simulation Queue
    logic [15:0] fifo_queue[$];
    logic [15:0] sample_counter = 1;

    // Instantiate DUT
    rate_synchronizer dut (
        .clk_12mhz(clk_12mhz),
        .mcu_48k_clk(mcu_48k_clk),
        .fifo_data(fifo_data),
        .fifo_empty(fifo_empty),
        .fifo_read_en(fifo_read_en),
        .audio_out(audio_out),
        .sample_valid(sample_valid)
    );

    // ==========================================
    // 1. CLOCK GENERATION
    // ==========================================
    
    // Fast System Clock (12MHz)
    initial begin
        clk_12mhz = 0;
        forever #41.66 clk_12mhz = ~clk_12mhz;
    end

    // Output Rate Trigger (62.5kHz)
    // Period = 1/62500 = 16us -> Toggle every 8000ns
    initial begin
        mcu_48k_clk = 0;
        #100; // Offset start slightly
        forever #8000 mcu_48k_clk = ~mcu_48k_clk;
    end

    // ==========================================
    // 2. FIFO PRODUCER (Input Rate 48kHz)
    // ==========================================
    // Period = 1/48000 = 20.833us -> 20833ns
    initial begin
        // Wait for reset/start
        #200;
        
        // Loop to generate 20 samples
        repeat(20) begin
            fifo_queue.push_back(sample_counter);
            $display("[%0t] FIFO WRITE: Pushed Sample %0d", $time, sample_counter);
            sample_counter++;
            #20833; // Wait 20.833us before next write
        end
    end

    // ==========================================
    // 3. FIFO BEHAVIOR LOGIC (MOCK)
    // ==========================================
    always_comb begin
        fifo_empty = (fifo_queue.size() == 0);
        
        // IF QUEUE HAS DATA -> Show it
        if (fifo_queue.size() > 0) 
            fifo_data = fifo_queue[0];
            
        // IF QUEUE IS EMPTY -> Show 0 (This is the gap you see!)
        else 
            fifo_data = 16'h0000;
    end

    // Handle Read Logic (Pop from Queue)
    always @(posedge fifo_read_en) begin
        void'(fifo_queue.pop_front());
        // Note: In a real async FIFO, empty flag takes time to update, 
        // but for this behavioral test, instant update is fine.
    end

    // ==========================================
    // 4. OUTPUT MONITOR & INTERNAL SPY
    // ==========================================
    
    // SPY on the Internal Trigger Signal to prove edges are detected
    // Note: This accesses the signal inside the DUT instance
    always @(posedge dut.mcu_clk_rising) begin
        if (fifo_empty)
            $display("[%0t] INTERNAL: Edge Detected -> [SKIPPING READ] (FIFO Empty)", $time);
        else
            $display("[%0t] INTERNAL: Edge Detected -> [READING SAMPLE]", $time);
    end

    always @(posedge sample_valid) begin
        $display("[%0t] OUTPUT: %0d %s", $time, audio_out, (fifo_empty ? "(Repeated/Held)" : "(Fresh)"));
    end

    // ==========================================
    // 5. MAIN SIMULATION CONTROL
    // ==========================================
    initial begin
        $display("--- Starting Rate Mismatch Test ---");
        $display("Input Rate:  48.0 kHz (Writes every ~20.8us)");
        $display("Output Rate: 62.5 kHz (Reads every 16.0us)");
        $display("Expectation: Since Output > Input, reads will occasionally skip (Underrun).");
        
        // Run long enough to process ~16 samples
        // 16 samples * 20us = ~320us. Let's run 400us.
        #400000; 
        
        $display("--- Test Complete ---");
        $finish;
    end

endmodule