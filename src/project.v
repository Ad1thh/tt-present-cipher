/*
 * Copyright (c) 2024 Adithyan
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_present (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    assign uio_oe = 8'b11111111;

    // --- Command decode (one-hot from uio_in) ---
    wire cmd_load_key  = (uio_in == 8'd1);
    wire cmd_load_data = (uio_in == 8'd2);
    wire cmd_start     = (uio_in == 8'd4);
    wire cmd_unload    = (uio_in == 8'd8);

    // --- Registers ---
    reg [63:0] state_reg;
    reg [79:0] key_reg;
    reg [4:0]  round_ctr;
    reg [4:0]  nibble_ctr;  // 0..15 for sbox layer, 16 = do pLayer+keysched
    reg        busy;
    reg        done_reg;

    // --- Single shared S-Box ---
    reg  [3:0] sbox_in;
    wire [3:0] sbox_out;
    sbox s0 (.in(sbox_in), .out(sbox_out));

    // --- P-Layer (pure wiring, zero gates) ---
    wire [63:0] p_out;
    genvar gi;
    generate
        for (gi = 0; gi < 63; gi = gi + 1) begin : pl
            assign p_out[(gi * 16) % 63] = state_reg[gi];
        end
    endgenerate
    assign p_out[63] = state_reg[63];

    // --- Key schedule wires ---
    wire [79:0] key_rotated = {key_reg[18:0], key_reg[79:19]};

    // --- Outputs ---
    assign uo_out  = state_reg[63:56];
    assign uio_out = {7'd0, done_reg};

    // --- S-Box input mux (only 4 bits wide — tiny) ---
    always @(*) begin
        if (busy && nibble_ctr < 5'd16)
            sbox_in = state_reg[{nibble_ctr[3:0], 2'b00} +: 4];
        else
            sbox_in = key_rotated[79:76];
    end

    // --- Main FSM ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg  <= 64'd0;
            key_reg    <= 80'd0;
            round_ctr  <= 5'd1;
            nibble_ctr <= 5'd0;
            busy       <= 1'b0;
            done_reg   <= 1'b0;
        end else begin

            // Clear done when not starting a new encryption
            if (done_reg && !cmd_start)
                done_reg <= 1'b0;

            if (busy) begin
                if (nibble_ctr < 5'd16) begin
                    // Substitute one nibble per cycle
                    state_reg[{nibble_ctr[3:0], 2'b00} +: 4] <= sbox_out;
                    nibble_ctr <= nibble_ctr + 1;
                end else begin
                    // nibble_ctr == 16: Apply pLayer, key schedule, advance round
                    state_reg <= p_out;
                    key_reg   <= {sbox_out, key_rotated[75:20],
                                  key_rotated[19:15] ^ round_ctr, key_rotated[14:0]};

                    if (round_ctr == 5'd31) begin
                        // Final AddRoundKey (post-whitening)
                        state_reg <= p_out ^ {sbox_out, key_rotated[75:20],
                                    key_rotated[19:15] ^ round_ctr, key_rotated[14:0]}[79:16];
                        busy     <= 1'b0;
                        done_reg <= 1'b1;
                    end else begin
                        round_ctr  <= round_ctr + 1;
                    end
                    nibble_ctr <= 5'd0;
                end

            end else if (cmd_load_key) begin
                key_reg <= {key_reg[71:0], ui_in};

            end else if (cmd_load_data) begin
                state_reg <= {state_reg[55:0], ui_in};

            end else if (cmd_unload) begin
                state_reg <= {state_reg[55:0], 8'd0};

            end else if (cmd_start) begin
                // AddRoundKey for first round happens here
                state_reg  <= state_reg ^ key_reg[79:16];
                round_ctr  <= 5'd1;
                nibble_ctr <= 5'd0;
                busy       <= 1'b1;
                done_reg   <= 1'b0;
            end
        end
    end

endmodule
