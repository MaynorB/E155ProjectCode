/*
 * Module: rate_synchronizer
 * Description:
 * - Trigger for Variable Sample Rates.
 * - DEBOUNCE: ~2us (100 cycles) lockout.
 */
module rate_synchronizer (
    input  logic          clk_12mhz,
    input  logic          mcu_48k_clk,
    input  logic signed [15:0] fifo_data,
    input  logic          fifo_empty,
    output logic          fifo_read_en,
    output logic signed [15:0] audio_out,
    output logic          sample_valid
);
    logic [2:0] mcu_clk_sync;
    always_ff @(posedge clk_12mhz) mcu_clk_sync <= {mcu_clk_sync[1:0], mcu_48k_clk};

    logic mcu_clk_rising;
    assign mcu_clk_rising = (mcu_clk_sync[1] == 1'b1 && mcu_clk_sync[2] == 1'b0);

    logic signed [15:0] current_sample = 0;
    logic valid_strobe = 0;
    logic [7:0] debounce_timer = 0;

    always_ff @(posedge clk_12mhz) begin
        fifo_read_en <= 0; valid_strobe <= 0;
        if (debounce_timer > 0) debounce_timer <= debounce_timer - 1;

        if (mcu_clk_rising && debounce_timer == 0) begin
            if (!fifo_empty) begin
                fifo_read_en <= 1;           
                current_sample <= fifo_data; 
                valid_strobe <= 1;           
                debounce_timer <= 100;
            end
        end
    end
    assign audio_out = current_sample;
    assign sample_valid = valid_strobe;
endmodule