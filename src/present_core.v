`default_nettype none

module present_core (
    input  wire [63:0] state_in,
    input  wire [79:0] key_in,
    input  wire [4:0]  round,
    output wire [63:0] state_out,
    output wire [79:0] key_out
);

    // ----- Datapath Combinational Logic -----
    wire [63:0] add_round_key = state_in ^ key_in[79:16];
    
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
    assign key_rotated = {key_in[18:0], key_in[79:19]}; 

    wire [3:0] key_sbox_out;
    sbox key_sbox (
        .in (key_rotated[79:76]),
        .out(key_sbox_out)
    );

    wire [79:0] next_key;
    assign next_key = {key_sbox_out, key_rotated[75:20], key_rotated[19:15] ^ round, key_rotated[14:0]};

    // ----- Final Assignment -----
    // Apply post-whitening if it is the 31st round
    assign state_out = (round == 5'd31) ? (player_out ^ next_key[79:16]) : player_out;
    assign key_out   = next_key;

endmodule
