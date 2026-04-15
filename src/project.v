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
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // --- Control Signals from uio_in ---
    wire load_key_en    = uio_in[0];
    wire load_data_en   = uio_in[1];
    wire start_encrypt  = uio_in[2];
    wire unload_data_en = uio_in[3];

    reg [79:0] key_reg;
    reg [63:0] plaintext_reg;
    reg [63:0] ciphertext_shift_reg;

    wire [63:0] core_ciphertext;
    wire        core_done;

    // --- Output Assignments ---
    assign uo_out = ciphertext_shift_reg[63:56]; // Output MSB byte of ciphertext
    assign uio_out[0] = core_done;               // Done flag on bidirectional pin 0
    assign uio_out[7:1] = 7'd0;
    assign uio_oe = 8'h01;                       // uio[0] is output, uio[7:1] are inputs

    // --- Core Instance ---
    present_core core (
        .clk(clk),
        .rst_n(rst_n),
        .start(start_encrypt),
        .plaintext(plaintext_reg),
        .key(key_reg),
        .ciphertext(core_ciphertext),
        .done(core_done)
    );

    // --- FSM / Shift Register Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_reg <= 80'd0;
            plaintext_reg <= 64'd0;
            ciphertext_shift_reg <= 64'd0;
        end else begin
            // 80-bit Key Load (Shift Left by 8)
            if (load_key_en) begin
                key_reg <= {key_reg[71:0], ui_in};
            end
            
            // 64-bit Plaintext Load (Shift Left by 8)
            if (load_data_en) begin
                plaintext_reg <= {plaintext_reg[55:0], ui_in};
            end

            // Result Capture & Unload
            if (core_done) begin
                ciphertext_shift_reg <= core_ciphertext; // Capture instantly when done
            end else if (unload_data_en) begin
                // Shift output data left so next byte becomes MSB
                ciphertext_shift_reg <= {ciphertext_shift_reg[55:0], 8'd0};
            end
        end
    end

endmodule
