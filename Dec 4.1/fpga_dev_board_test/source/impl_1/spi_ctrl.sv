module spi_ctrl (
    input  logic clk,
    input  logic rst,
    input  logic spi_sck,
    input  logic spi_mosi,
    input  logic spi_cs,
    output logic [7:0] control_value
);
    logic [1:0] sck_sync, cs_sync, mosi_sync;
    always_ff @(posedge clk) begin
        sck_sync  <= {sck_sync[0],  spi_sck};
        cs_sync   <= {cs_sync[0],   spi_cs};
        mosi_sync <= {mosi_sync[0], spi_mosi};
    end

    wire sck_rising = (sck_sync[1] == 0 && sck_sync[0] == 1);
    wire cs_active  = (cs_sync[1] == 0);

    logic [7:0] shift_reg;
    logic [2:0] bit_cnt;

    always_ff @(posedge clk) begin
        if (rst) begin
            control_value <= 8'd0; bit_cnt <= 0;
        end else if (!cs_active) begin
            bit_cnt <= 0;
        end else if (sck_rising) begin
            shift_reg <= {shift_reg[6:0], mosi_sync[1]};
            bit_cnt <= bit_cnt + 1;
            if (bit_cnt == 7) control_value <= {shift_reg[6:0], mosi_sync[1]};
        end
    end
endmodule