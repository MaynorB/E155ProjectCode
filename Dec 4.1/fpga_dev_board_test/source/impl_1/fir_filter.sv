/*
 * Module: fir_filter
 * Description:
 * - Moving Average Filter (Low Pass).
 * - FIXED: Added wait state for RAM read latency.
 */
module fir_filter #(
    parameter DATA_WIDTH = 16,
    parameter TAPS_LOG2  = 7,      // 128 Taps
    parameter DELAY_SAMPLES = 64   // Default Delay
)(
    input  logic clk,
    input  logic rst,
    input  logic sample_valid,
    input  logic signed [DATA_WIDTH-1:0] data_in,
    
    output logic signed [DATA_WIDTH-1:0] data_out,        
    output logic signed [DATA_WIDTH-1:0] high_pass_out,   
    output logic signed [DATA_WIDTH-1:0] delayed_ref_out  
);

    localparam TAPS = 1 << TAPS_LOG2;

    // RAM
    logic signed [DATA_WIDTH-1:0] ram [0:TAPS-1];
    logic [TAPS_LOG2-1:0] ram_addr;
    logic signed [DATA_WIDTH-1:0] ram_rdata;
    logic ram_wen;
    logic signed [DATA_WIDTH-1:0] ram_wdata;

    always_ff @(posedge clk) begin
        if (ram_wen) ram[ram_addr] <= ram_wdata;
        ram_rdata <= ram[ram_addr]; 
    end

    // Logic
    logic [TAPS_LOG2-1:0] write_ptr = 0;
    logic signed [DATA_WIDTH + TAPS_LOG2 : 0] accumulator = 0;
    
    logic signed [DATA_WIDTH-1:0] oldest_sample_latched;
    logic signed [DATA_WIDTH-1:0] delayed_sample_latched;
    logic signed [DATA_WIDTH-1:0] new_sample_held;

    logic signed [23:0] acc_scaled;
    logic signed [16:0] hp_calc;

    // ADDED STATE: WAIT_CENTER
    typedef enum logic [2:0] {IDLE, WAIT_OLD, LATCH_OLD, WAIT_CENTER, LATCH_CENTER, DONE} state_t;
    state_t state = IDLE;

    always_ff @(posedge clk) begin
        if (rst) begin
            write_ptr <= 0; accumulator <= 0; state <= IDLE; ram_wen <= 0;
            data_out <= 0; high_pass_out <= 0; delayed_ref_out <= 0;
            // Initialize signals to avoid latches
            new_sample_held <= 0; ram_addr <= 0; ram_wdata <= 0;
            oldest_sample_latched <= 0; delayed_sample_latched <= 0;
        end else begin
            ram_wen <= 0; 
            case (state)
                IDLE: begin
                    if (sample_valid) begin
                        new_sample_held <= data_in;
                        ram_addr <= write_ptr; 
                        state <= WAIT_OLD;
                    end
                end
                
                // 1. Fetch Oldest Sample
                WAIT_OLD: state <= LATCH_OLD;
                
                LATCH_OLD: begin
                    oldest_sample_latched <= ram_rdata;
                    
                    // Setup Address for Delayed Sample
                    // Note: explicit casting helps clarity
                    ram_addr <= write_ptr - TAPS_LOG2'(DELAY_SAMPLES); 
                    
                    state <= WAIT_CENTER; // <--- Go to Wait State
                end
                
                // 2. Wait for RAM to fetch Delayed Sample
                WAIT_CENTER: state <= LATCH_CENTER; 

                LATCH_CENTER: begin
                    delayed_sample_latched <= ram_rdata; // Now valid!
                    
                    // Setup Address for Write (Current Sample)
                    ram_addr <= write_ptr;
                    ram_wdata <= new_sample_held;
                    ram_wen <= 1;
                    
                    state <= DONE;
                end
                
                DONE: begin
                    accumulator <= accumulator - oldest_sample_latched + new_sample_held;
                    write_ptr <= write_ptr + 1;

                    // Unity Gain (Div 128)
                    acc_scaled = accumulator >>> TAPS_LOG2; 
                    if (acc_scaled > 32767) data_out <= 32767;
                    else if (acc_scaled < -32768) data_out <= -32768;
                    else data_out <= acc_scaled[15:0];

                    delayed_ref_out <= delayed_sample_latched;

                    // Debug High Pass
                    hp_calc = delayed_sample_latched - acc_scaled[15:0];
                    if (hp_calc > 32767) high_pass_out <= 32767;
                    else if (hp_calc < -32768) high_pass_out <= -32768;
                    else high_pass_out <= hp_calc[15:0];

                    state <= IDLE;
                end
            endcase
        end
    end
endmodule