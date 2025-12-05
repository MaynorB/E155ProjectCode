/*
 * Module: mixer
 * Description:
 * - Inputs: 'clean_in' (Delayed) and 'filtered_in' (Bass).
 * - MATH: High Pass = Clean - Bass.
 * - OUTPUT: Mixes High Pass (0) <-> Bass (255).
 * - FEATURE: Dynamic Bass Boost (1x to 4x) based on knob position.
 */
module mixer (
    input  logic clk,
    input  logic signed [15:0] clean_in,
    input  logic signed [15:0] filtered_in,
    input  logic [7:0]         mix_ratio,
    output logic signed [15:0] mixed_out
);

    // 1. Calculate High Pass (Treble)
    // Formula: Treble = Clean - Bass
    logic signed [16:0] hp_calc;
    logic signed [15:0] high_pass_saturated;

    always_comb begin
        hp_calc = clean_in - filtered_in;
        
        // Saturate High Pass calculation
        if (hp_calc > 32767) high_pass_saturated = 32767;
        else if (hp_calc < -32768) high_pass_saturated = -32768;
        else high_pass_saturated = hp_calc[15:0];
    end

    // 2. Mix with Dynamic Bass Boost
    // We need wider accumulators because we are applying gain > 1.
    // Max Bass = 16b (Data) * 8b (Ratio) * 3b (Gain 4x) = 27 bits.
    // Using 28 bits to be safe.
    logic signed [29:0] term_bass;
    logic signed [29:0] term_treble;
    logic signed [29:0] mixed_sum;
    logic signed [29:0] final_scaled;
    
    // Calculate Dynamic Gain Factor based on Knob Position
    // mix_ratio[7:6] is 0, 1, 2, or 3.
    // Gain = 1 + mix_ratio[7:6] -> 1x, 2x, 3x, 4x.
    logic [4:0] bass_gain_factor;//check size of this
    assign bass_gain_factor = 4+mix_ratio[7:5]; //adjust

    always_ff @(posedge clk) begin
        // Treble Term: Standard linear fade out
        // (No boost needed for treble)
        term_treble <= high_pass_saturated * $signed({1'b0, ~mix_ratio});//adjust originally just not mix ratio
        
        // Bass Term: Linear fade in * Dynamic Gain
        // As you turn the knob past 50%, gain ramps up to 3x, then 4x.
        term_bass   <= filtered_in * $signed({1'b0, mix_ratio}) * $signed({1'b0, bass_gain_factor});
        
        // Sum the terms
        mixed_sum <= term_bass + term_treble;
        
        // Normalize: Divide by 256 (Arithmetic Shift Right 8)
        final_scaled = mixed_sum >>> 10; //adjust
        
        // 3. Output Saturation (Crucial for Boost)
        // Since we boosted bass up to 4x, it can easily exceed 16 bits.
        // We clip it instead of wrapping around.
        if (final_scaled > 32767) mixed_out <= 32767;
        else if (final_scaled < -32768) mixed_out <= -32768;
        else mixed_out <= final_scaled[15:0];
    end

endmodule