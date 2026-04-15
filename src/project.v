/*
 * Copyright (c) 2024 Adithyan
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_present (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high)
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    assign uio_oe  = 8'b11111111;

    wire load_key_en     = (uio_in == 8'd1);
    wire load_data_en    = (uio_in == 8'd2);
    wire start_encrypt   = (uio_in == 8'd4);
    wire unload_data_en  = (uio_in == 8'd8);

    reg [63:0] state_reg;
    reg [79:0] key_reg;
    reg [4:0]  round;
    reg [3:0]  sub_cycle; // Range 0 to 9 for the byte-serial loop
    reg        busy;
    reg        done_reg;

    wire [7:0]  sbox_byte_out;
    wire [63:0] p_layer_out;
    wire [79:0] next_key;

    // ----- Byte-Serial Core -----
    present_core core (
        .sbox_byte_in (state_reg[63:56]), // Feed top 8 bits into the 2 S-Boxes
        .sbox_byte_out(sbox_byte_out),    // Receive substituted byte
        .p_layer_in   (state_reg),
        .p_layer_out  (p_layer_out),
        .key_in       (key_reg),
        .round        (round),
        .key_out      (next_key)
    );

    // Outputs
    assign uo_out = state_reg[63:56];
    assign uio_out = {7'd0, done_reg};

    // ----- Multiplexer Minimization -----
    // By merging all left-shifts into a single logical wire, 
    // Yosys deletes dozens of redundant Multiplexer gates.
    wire is_shift_state = load_data_en || unload_data_en || (busy && sub_cycle >= 4'd1 && sub_cycle <= 4'd8);
    wire [7:0] shift_in_val = load_data_en ? ui_in : (unload_data_en ? 8'd0 : sbox_byte_out);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg <= 64'd0;
            key_reg   <= 80'd0;
            round     <= 5'd1;
            sub_cycle <= 4'd0;
            busy      <= 1'b0;
            done_reg  <= 1'b0;
        end else begin
            if (load_key_en) begin
                key_reg  <= {key_reg[71:0], ui_in};
                done_reg <= 1'b0;
            end else if (start_encrypt && !busy) begin
                round     <= 5'd1;
                sub_cycle <= 4'd0;
                busy      <= 1'b1;
                done_reg  <= 1'b0;
            end else if (busy) begin
                
                // State 0: AddRoundKey (XOR exactly 64 bits simultaneously)
                if (sub_cycle == 4'd0) begin
                    state_reg <= state_reg ^ key_reg[79:16];
                    sub_cycle <= 4'd1;
                end 
                
                // States 1-8: Shift bytes through the 2 S-Boxes like a carousel
                else if (sub_cycle >= 4'd1 && sub_cycle <= 4'd8) begin
                    state_reg <= {state_reg[55:0], shift_in_val};
                    sub_cycle <= sub_cycle + 1;
                end 
                
                // State 9: Apply the Wire P-Layer and cycle the Key Schedule
                else if (sub_cycle == 4'd9) begin
                    key_reg <= next_key;
                    if (round == 5'd31) begin
                        // Post-Whitening with the freshly updated key
                        state_reg <= p_layer_out ^ next_key[79:16];
                        busy      <= 1'b0;
                        done_reg  <= 1'b1; // Flag complete
                    end else begin
                        state_reg <= p_layer_out;
                        round     <= round + 1;
                        sub_cycle <= 4'd0;
                    end
                end
                
            end else if (is_shift_state) begin
                // Captures user IO loads and unloads independently
                state_reg <= {state_reg[55:0], shift_in_val};
                done_reg  <= 1'b0;
            end else begin
                // Idle
                done_reg <= 1'b0;
            end
        end
    end

endmodule
