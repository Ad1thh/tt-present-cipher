`default_nettype none

module present_core (
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    input  wire [63:0] plaintext,
    input  wire [79:0] key,
    output reg  [63:0] ciphertext,
    output reg  done
);

    reg [63:0] state;
    reg [79:0] key_reg;
    reg [4:0]  round; // 1 to 31
    reg        busy;

    // ----- Datapath Combinational Logic -----
    wire [63:0] add_round_key = state ^ key_reg[79:16];
    
    wire [63:0] sbox_out;
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : sbox_layer
            sbox sb (
                .in (add_round_key[i*4 +: 4]),
                .out(sbox_out[i*4 +: 4])
            );
        end
    endgenerate

    wire [63:0] player_out;
    generate
        for (i = 0; i < 63; i = i + 1) begin : p_layer
            assign player_out[(i*16) % 63] = sbox_out[i];
        end
    endgenerate
    assign player_out[63] = sbox_out[63];

    // ----- Key Schedule Combinational Logic -----
    wire [79:0] key_rotated;
    // Rotate left by 61 is equivalent to rotate right by 19
    assign key_rotated = {key_reg[18:0], key_reg[79:19]}; 

    wire [3:0] key_sbox_out;
    sbox key_sbox (
        .in (key_rotated[79:76]),
        .out(key_sbox_out)
    );

    wire [79:0] next_key;
    assign next_key = {key_sbox_out, key_rotated[75:20], key_rotated[19:15] ^ round, key_rotated[14:0]};

    // ----- Sequential Logic -----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= 64'd0;
            key_reg    <= 80'd0;
            round      <= 5'd1;
            busy       <= 1'b0;
            done       <= 1'b0;
            ciphertext <= 64'd0;
        end else begin
            if (start && !busy) begin
                state   <= plaintext;
                key_reg <= key;
                round   <= 5'd1;
                busy    <= 1'b1;
                done    <= 1'b0;
            end else if (busy) begin
                if (round == 5'd31) begin
                    // Final post-whitening
                    ciphertext <= player_out ^ next_key[79:16];
                    done       <= 1'b1;
                    busy       <= 1'b0;
                end else begin
                    state   <= player_out;
                    key_reg <= next_key;
                    round   <= round + 1;
                    done    <= 1'b0;
                end
            end else begin
                // Turn off done pulse after 1 cycle of being high (or handle externally)
                // Assuming client detects high edge or we just clear it on reset/next start
            end
        end
    end

endmodule
