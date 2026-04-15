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

    wire load_key_en    = (uio_in == 8'd1);
    wire load_data_en   = (uio_in == 8'd2);
    wire start_encrypt  = (uio_in == 8'd4);
    wire unload_data_en = (uio_in == 8'd8);

    reg [63:0] state_reg;
    reg [79:0] key_reg;
    reg [4:0]  round;
    reg        busy;
    reg        done_reg;

    wire [63:0] next_state;
    wire [79:0] next_key;

    // The Parallel Core mathematically guarantees zero multiplexer bloat
    present_core core (
        .state_in(state_reg),
        .key_in(key_reg),
        .round(round),
        .state_out(next_state),
        .key_out(next_key)
    );

    wire [63:0] post_whitened_state = next_state ^ next_key[79:16];

    assign uo_out = state_reg[63:56];
    assign uio_out = {7'd0, done_reg};

    // The absolute minimum MUX logic achievable:
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg <= 64'd0;
            key_reg   <= 80'd0;
            round     <= 5'd1;
            busy      <= 1'b0;
            done_reg  <= 1'b0;
        end else begin
            
            // Default step flags
            if (done_reg && !start_encrypt) done_reg <= 1'b0;
            
            if (load_key_en) begin
                key_reg <= {key_reg[71:0], ui_in};
            end else if (load_data_en) begin
                state_reg <= {state_reg[55:0], ui_in};
            end else if (unload_data_en) begin
                state_reg <= {state_reg[55:0], 8'd0};
            end else if (start_encrypt && !busy) begin
                round <= 5'd1;
                busy  <= 1'b1;
            end else if (busy) begin
                key_reg <= next_key;
                if (round == 5'd31) begin
                    state_reg <= post_whitened_state;
                    busy <= 1'b0;
                    done_reg <= 1'b1;
                end else begin
                    state_reg <= next_state;
                    round <= round + 1;
                end
            end
            
        end
    end

endmodule
