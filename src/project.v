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
    reg        busy;
    reg        done_reg;

    wire [63:0] next_state;
    wire [79:0] next_key;

    // Combinational Datapath Instance
    present_core core (
        .state_in(state_reg),
        .key_in(key_reg),
        .round(round),
        .state_out(next_state),
        .key_out(next_key)
    );

    // Continuous assignment from highest byte of state register
    assign uo_out = state_reg[63:56];

    // uio_out[0] serves as the done flag, others 0
    assign uio_out = {7'd0, done_reg};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg <= 64'd0;
            key_reg   <= 80'd0;
            round     <= 5'd1;
            busy      <= 1'b0;
            done_reg  <= 1'b0;
        end else begin
            // Non-overlapping priority shift-register logic
            if (load_key_en) begin
                key_reg  <= {key_reg[71:0], ui_in};
                done_reg <= 1'b0;
            end else if (load_data_en) begin
                state_reg <= {state_reg[55:0], ui_in};
                done_reg  <= 1'b0;
            end else if (start_encrypt && !busy) begin
                round    <= 5'd1;
                busy     <= 1'b1;
                done_reg <= 1'b0;
            end else if (busy) begin
                // Encrypting Phase: Loop combinational module back onto itself
                if (round == 5'd31) begin
                    state_reg <= next_state; // Includes post-whitening
                    key_reg   <= next_key; 
                    busy      <= 1'b0;
                    done_reg  <= 1'b1;       // Pulse done flag
                end else begin
                    state_reg <= next_state;
                    key_reg   <= next_key;
                    round     <= round + 1;
                    done_reg  <= 1'b0;
                end
            end else if (unload_data_en) begin
                state_reg <= {state_reg[55:0], 8'd0}; // Shift data out towards uo_out
                done_reg  <= 1'b0;
            end else begin
                // Idle state, clear done flag to create the 1-cycle pulse
                done_reg <= 1'b0;
            end
        end
    end

endmodule
