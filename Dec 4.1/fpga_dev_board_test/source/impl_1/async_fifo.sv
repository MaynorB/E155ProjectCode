/*
 * Module: async_fifo
 * Description: 
 * - Generic 256x16 FIFO using Gray Code pointers.
 * - Safely handles SPI bursts vs Constant Read rates.
 */
module async_fifo #(
    parameter DWIDTH = 16,
    parameter AWIDTH = 8   // 256 words depth
)(
    input  logic              clk_write, 
    input  logic              write_en,
    input  logic [DWIDTH-1:0] write_data,
    output logic              full,
    
    input  logic              clk_read, 
    input  logic              read_en,
    output logic [DWIDTH-1:0] read_data,
    output logic              empty,
    
    input  logic              rst
);

    logic [DWIDTH-1:0] mem [0:(1<<AWIDTH)-1];

    logic [AWIDTH:0] w_ptr_bin = 0, w_ptr_gray = 0;
    logic [AWIDTH:0] r_ptr_bin = 0, r_ptr_gray = 0;
    
    logic [AWIDTH:0] w_ptr_gray_sync1 = 0, w_ptr_gray_sync2 = 0;
    logic [AWIDTH:0] r_ptr_gray_sync1 = 0, r_ptr_gray_sync2 = 0;

    // Sync Write Pointer -> Read Domain
    always_ff @(posedge clk_read) begin
        if (rst) begin
            w_ptr_gray_sync1 <= 0; w_ptr_gray_sync2 <= 0;
        end else begin
            w_ptr_gray_sync1 <= w_ptr_gray;
            w_ptr_gray_sync2 <= w_ptr_gray_sync1;
        end
    end

    // Sync Read Pointer -> Write Domain
    always_ff @(posedge clk_write) begin
        if (rst) begin
            r_ptr_gray_sync1 <= 0; r_ptr_gray_sync2 <= 0;
        end else begin
            r_ptr_gray_sync1 <= r_ptr_gray;
            r_ptr_gray_sync2 <= r_ptr_gray_sync1;
        end
    end

    // Write Logic
    wire [AWIDTH:0] w_ptr_gray_next = (w_ptr_bin + 1) ^ ((w_ptr_bin + 1) >> 1);
    assign full = (w_ptr_gray == {~r_ptr_gray_sync2[AWIDTH:AWIDTH-1], r_ptr_gray_sync2[AWIDTH-2:0]});

    always_ff @(posedge clk_write) begin
        if (rst) begin
            w_ptr_bin <= 0; w_ptr_gray <= 0;
        end else if (write_en && !full) begin
            mem[w_ptr_bin[AWIDTH-1:0]] <= write_data;
            w_ptr_bin <= w_ptr_bin + 1;
            w_ptr_gray <= w_ptr_gray_next;
        end
    end

    // Read Logic
    wire [AWIDTH:0] r_ptr_gray_next = (r_ptr_bin + 1) ^ ((r_ptr_bin + 1) >> 1);
    assign empty = (r_ptr_gray == w_ptr_gray_sync2);

    always_ff @(posedge clk_read) begin
        if (rst) begin
            r_ptr_bin <= 0; r_ptr_gray <= 0; read_data <= 0;
        end else if (read_en && !empty) begin
            read_data <= mem[r_ptr_bin[AWIDTH-1:0]];
            r_ptr_bin <= r_ptr_bin + 1;
            r_ptr_gray <= r_ptr_gray_next;
        end
    end

endmodule