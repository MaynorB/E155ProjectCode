/*
 * Module: sine_rom
 * Description:
 * A 64-entry, 16-bit signed Read-Only Memory (ROM).
 * Amplitude: 32000 (Fits safely in 16-bit signed max of 32767).
 * Phase: Corrected to start at 0 and end at 2*PI.
 */
module sine_rom (
    input  logic [5:0] addr,
    output logic signed [15:0] data
);
    always_comb begin
        case (addr)
            // Quadrant 1 (Positive Rising)
            6'd0:  data = 16'sd0;
            6'd1:  data = 16'sd3138;
            6'd2:  data = 16'sd6244;
            6'd3:  data = 16'sd9289;
            6'd4:  data = 16'sd12244;
            6'd5:  data = 16'sd15081;
            6'd6:  data = 16'sd17773;
            6'd7:  data = 16'sd20296;
            6'd8:  data = 16'sd22626;
            6'd9:  data = 16'sd24742;
            6'd10: data = 16'sd26626;
            6'd11: data = 16'sd28262;
            6'd12: data = 16'sd29636;
            6'd13: data = 16'sd30735;
            6'd14: data = 16'sd31548;
            6'd15: data = 16'sd32062;

            // Quadrant 2 (Positive Falling)
            6'd16: data = 16'sd32269; // Peak (~1.0)
            6'd17: data = 16'sd32162;
            6'd18: data = 16'sd31742;
            6'd19: data = 16'sd31014;
            6'd20: data = 16'sd29985;
            6'd21: data = 16'sd28664;
            6'd22: data = 16'sd27068;
            6'd23: data = 16'sd25210;
            6'd24: data = 16'sd23109;
            6'd25: data = 16'sd20784;
            6'd26: data = 16'sd18256;
            6'd27: data = 16'sd15551;
            6'd28: data = 16'sd12693;
            6'd29: data = 16'sd9709;
            6'd30: data = 16'sd6628;
            6'd31: data = 16'sd3481;

            // Quadrant 3 (Negative Falling)
            6'd32: data = 16'sd299;   // Zero Crossing
            6'd33: data = -16'sd2884;
            6'd34: data = -16'sd6033;
            6'd35: data = -16'sd9114;
            6'd36: data = -16'sd12101;
            6'd37: data = -16'sd14968;
            6'd38: data = -16'sd17689;
            6'd39: data = -16'sd20238;
            6'd40: data = -16'sd22592;
            6'd41: data = -16'sd24729;
            6'd42: data = -16'sd26632;
            6'd43: data = -16'sd28286;
            6'd44: data = -16'sd29677;
            6'd45: data = -16'sd30792;
            6'd46: data = -16'sd31620;
            6'd47: data = -16'sd32148;

            // Quadrant 4 (Negative Rising)
            6'd48: data = -16'sd32367; // Negative Peak
            6'd49: data = -16'sd32270;
            6'd50: data = -16'sd31860;
            6'd51: data = -16'sd31141;
            6'd52: data = -16'sd30120;
            6'd53: data = -16'sd28807;
            6'd54: data = -16'sd27218;
            6'd55: data = -16'sd25367;
            6'd56: data = -16'sd23272;
            6'd57: data = -16'sd20953;
            6'd58: data = -16'sd18430;
            6'd59: data = -16'sd15729;
            6'd60: data = -16'sd12875;
            6'd61: data = -16'sd9894;
            6'd62: data = -16'sd6815;
            6'd63: data = -16'sd3669;

            default: data = 16'sd0;
        endcase
    end
endmodule