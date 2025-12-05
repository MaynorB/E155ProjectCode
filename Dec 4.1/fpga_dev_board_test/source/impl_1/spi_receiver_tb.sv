`timescale 1ns / 1ps

module spi_receiver_tb;

    // ==========================================
    // 1. PARAMETERS & SIGNALS
    // ==========================================
    parameter BYTE_SWAP = 1; // Testing the Endianness fix

    logic clk_12mhz;
    logic rst;
    logic spi_sck;
    logic spi_mosi;
    logic spi_cs;
    
    // Outputs from DUT
    logic fifo_full;
    logic [15:0] fifo_data_out;
    logic fifo_write_en;

    // ==========================================
    // 2. DUT INSTANTIATION
    // ==========================================
    spi_receiver #(
        .BYTE_SWAP(BYTE_SWAP)
    ) dut (
        .clk_12mhz(clk_12mhz),
        .rst(rst),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_cs(spi_cs),
        .fifo_full(fifo_full),
        .fifo_data_out(fifo_data_out),
        .fifo_write_en(fifo_write_en)
    );

    // ==========================================
    // 3. CLOCK GENERATION (12MHz)
    // ==========================================
    initial begin
        clk_12mhz = 0;
        forever begin
            #41.66 clk_12mhz = 1;
            #41.66 clk_12mhz = 0;
        end
    end

    // ==========================================
    // 4. SPI TASKS
    // ==========================================
    // Sends 16 bits. Mode 0: Idle Low, Sample Rising Edge.
    task send_spi_word(input logic [15:0] data);
        integer i;
        begin
            spi_cs = 0; // Select
            #500;       // Setup time
            
            for (i = 15; i >= 0; i = i - 1) begin
                // 1. Setup Data
                spi_mosi = data[i];
                #250; // Hold before clock rises
                
                // 2. Clock High (Rising Edge - Sample)
                spi_sck = 1; 
                #500; 
                
                // 3. Clock Low
                spi_sck = 0;
                #250; 
            end
            
            #500; 
            spi_cs = 1; // Deselect
            #1000;      // Gap
        end
    endtask

    // ==========================================
    // 5. MAIN TEST SEQUENCE
    // ==========================================
    initial begin
        // Initialize
        rst = 1;
        spi_sck = 0;
        spi_mosi = 0;
        spi_cs = 1; // Inactive High
        fifo_full = 0; // Simulate empty FIFO downstream

        // Apply Reset
        #200;
        rst = 0;
        #200;

        $display("--- Starting SPI Receiver Test ---");
        $display("Configuration: BYTE_SWAP = %0d", BYTE_SWAP);

        // TEST 1: Send 0xAABB (43707)
        // If Byte Swap is ON, we expect 0xBBAA out.
        // If Byte Swap is OFF, we expect 0xAABB out.
        $display("Sending 0xAABB...");
        send_spi_word(16'hAABB);

        // Wait for the receiver to push data
        wait(fifo_write_en == 1);
        #10; // Wait for data to be stable
        
        if (fifo_data_out === 16'hBBAA) begin
            $display("PASS: Input 0xAABB -> Output 0xBBAA (Correctly Swapped)");
        end else if (fifo_data_out === 16'hAABB) begin
            $display("FAIL: Input 0xAABB -> Output 0xAABB (Not Swapped - Check Parameter)");
        end else begin
            $display("FAIL: Input 0xAABB -> Output %h (Garbage?)", fifo_data_out);
        end

        #2000;
        $finish;
    end

endmodule