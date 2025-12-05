`timescale 1ns / 1ps

module async_fifo_tb;

    // Parameters
    parameter DWIDTH = 16;
    parameter AWIDTH = 8; // 256 Words Depth

    // Signals
    logic clk_write;
    logic write_en;
    logic [DWIDTH-1:0] write_data;
    logic full;

    logic clk_read;
    logic read_en;
    logic [DWIDTH-1:0] read_data;
    logic empty;

    logic rst;

    // Instantiate the FIFO
    async_fifo #(
        .DWIDTH(DWIDTH),
        .AWIDTH(AWIDTH)
    ) dut (
        .clk_write(clk_write),
        .write_en(write_en),
        .write_data(write_data),
        .full(full),
        .clk_read(clk_read),
        .read_en(read_en),
        .read_data(read_data),
        .empty(empty),
        .rst(rst)
    );

    // ==========================================
    // 1. CLOCK GENERATION (Different Speeds!)
    // ==========================================
    
    // Write Clock: Fast (e.g., 48MHz -> ~21ns period)
    initial begin
        clk_write = 0;
        forever #10.5 clk_write = ~clk_write;
    end

    // Read Clock: Slower (e.g., 12MHz -> ~42ns period)
    // This ensures we test the cross-domain synchronization logic.
    initial begin
        clk_read = 0;
        forever #21 clk_read = ~clk_read; 
    end

    // ==========================================
    // 2. HELPER TASKS
    // ==========================================
    task fifo_write(input logic [15:0] data);
        begin
            @(negedge clk_write);
            if (!full) begin
                write_en = 1;
                write_data = data;
                @(negedge clk_write);
                write_en = 0;
                $display("Write: 0x%h", data);
            end else begin
                $display("Write Skipped: FIFO Full!");
            end
        end
    endtask

    task fifo_read();
        begin
            // Check data BEFORE acknowledging read (Show-Ahead behavior)
            // or Check after? Standard FIFOs show data, then you 'pop' it.
            @(negedge clk_read);
            if (!empty) begin
                read_en = 1;
                $display("Read:  0x%h", read_data); 
                @(negedge clk_read);
                read_en = 0;
            end else begin
                $display("Read Skipped: FIFO Empty!");
            end
        end
    endtask

    // ==========================================
    // 3. MAIN TEST SEQUENCE
    // ==========================================
    initial begin
        // Initialize
        rst = 1; write_en = 0; read_en = 0; write_data = 0;
        
        $display("--- Starting Async FIFO Test ---");

        // Reset
        #100;
        rst = 0;
        #100;

        // CHECK 1: Initial State
        if (empty !== 1) $error("FAIL: Should be Empty on start");
        if (full !== 0)  $error("FAIL: Should not be Full on start");

        // CHECK 2: Write Small Burst (3 items)
        $display("--- Step 1: Write 3 Words ---");
        fifo_write(16'h1111);
        fifo_write(16'h2222);
        fifo_write(16'h3333);

        // Wait for flags to update (Gray codes take ~2-3 read clocks to sync)
        #200; 

        if (empty === 1) $error("FAIL: Empty flag is stuck HIGH after writes!");

        // CHECK 3: Read Verify
        $display("--- Step 2: Read & Verify ---");
        
        // Word 1
        if (read_data !== 16'h1111) $error("FAIL: Wanted 1111, Got %h", read_data);
        fifo_read(); // Pop 1111
        #50; // Wait for update

        // Word 2
        if (read_data !== 16'h2222) $error("FAIL: Wanted 2222, Got %h", read_data);
        fifo_read(); // Pop 2222
        #50;

        // Word 3
        if (read_data !== 16'h3333) $error("FAIL: Wanted 3333, Got %h", read_data);
        fifo_read(); // Pop 3333
        #200;

        if (empty !== 1) $error("FAIL: Should be Empty after reading all");
        else $display("PASS: Data Integrity Good.");

        // CHECK 4: Fill Capacity (Stress Test)
        $display("--- Step 3: Fill Capacity (256 Words) ---");
        repeat(260) begin // Try to write more than 256
            fifo_write(16'hFFFF);
        end

        #200;
        if (full !== 1) $error("FAIL: Full flag never asserted!");
        else $display("PASS: Full flag works.");

        $finish;
    end

endmodule