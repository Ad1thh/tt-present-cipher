/*
 * Copyright (c) 2024 Adithyan
 * SPDX-License-Identifier: Apache-2.0
 */
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

    // --- Command decode ---
    wire cmd_load_key  = (uio_in == 8'd1);
    wire cmd_load_data = (uio_in == 8'd2);
    wire cmd_start     = (uio_in == 8'd4);
    wire cmd_unload    = (uio_in == 8'd8);

    // --- Registers ---
    reg [63:0] state_reg;
    reg [79:0] key_reg;
    reg [4:0]  round_ctr;
    reg [3:0]  nibble_ctr;  // 0..15 for sbox substitution
    reg [1:0]  phase;       // 0=idle, 1=addkey, 2=sbox, 3=player+keysched
    reg        done_reg;

    // --- Single shared S-Box ---
    wire [3:0] sbox_in = state_reg[63:60]; // always feed top nibble
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
    wire [3:0]  ksbox_in    = key_rotated[79:76];
    wire [3:0]  ksbox_out;
    sbox ks (.in(ksbox_in), .out(ksbox_out));
    wire [79:0] next_key = {ksbox_out, key_rotated[75:20],
                            key_rotated[19:15] ^ round_ctr, key_rotated[14:0]};

    // --- Outputs ---
    assign uo_out  = state_reg[63:56];
    assign uio_out = {7'd0, done_reg};

    // --- Main FSM ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg  <= 64'd0;
            key_reg    <= 80'd0;
            round_ctr  <= 5'd1;
            nibble_ctr <= 4'd0;
            phase      <= 2'd0;
            done_reg   <= 1'b0;
        end else begin

            case (phase)

            2'd0: begin // IDLE
                done_reg <= 1'b0;
                if (cmd_load_key)
                    key_reg <= {key_reg[71:0], ui_in};
                else if (cmd_load_data)
                    state_reg <= {state_reg[55:0], ui_in};
                else if (cmd_unload)
                    state_reg <= {state_reg[55:0], 8'd0};
                else if (cmd_start) begin
                    round_ctr  <= 5'd1;
                    nibble_ctr <= 4'd0;
                    phase      <= 2'd1;
                end
            end

            2'd1: begin // ADD ROUND KEY
                state_reg <= state_reg ^ key_reg[79:16];
                phase     <= 2'd2;
                nibble_ctr <= 4'd0;
            end

            2'd2: begin // SBOX LAYER — rotate top nibble through S-box
                // Shift state left by 4, place sbox_out at bottom
                state_reg <= {state_reg[59:0], sbox_out};
                nibble_ctr <= nibble_ctr + 1;
                if (nibble_ctr == 4'd15)
                    phase <= 2'd3;
            end

            2'd3: begin // PLAYER + KEY SCHEDULE
                state_reg <= p_out;
                key_reg   <= next_key;
                if (round_ctr == 5'd31) begin
                    // Final add round key (post-whitening)
                    state_reg <= p_out ^ next_key[79:16];
                    phase    <= 2'd0;
                    done_reg <= 1'b1;
                end else begin
                    round_ctr <= round_ctr + 1;
                    phase     <= 2'd1;
                end
            end

            endcase
        end
    end
    
    // Suppress unused signal warning for Tiny Tapeout mandatory pins
    wire _unused = ena
endmodule
