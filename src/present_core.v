`default_nettype none

module present_core (
    input  wire [63:0] state_in,
    input  wire [79:0] key_in,
    input  wire [4:0]  round,
    output wire [63:0] state_out,
    output wire [79:0] key_out
);

    // 1. AddRoundKey
    wire [63:0] post_xor = state_in ^ key_in[79:16];

    // 2. S-Box Layer (16 Parallel instances)
    wire [63:0] post_sbox;
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : sboxes
            sbox s (
                .in (post_xor[(i*4)+3 : i*4]),
                .out(post_sbox[(i*4)+3 : i*4])
            );
        end
    endgenerate

    // 3. pLayer
    generate
        for (i = 0; i < 63; i = i + 1) begin : player
            assign state_out[(i*16) % 63] = post_sbox[i];
        end
    endgenerate
    assign state_out[63] = post_sbox[63];

    // 4. Update Key
    wire [79:0] key_rotated = {key_in[18:0], key_in[79:19]};
    wire [3:0] ksbox_out;
    sbox ks (
        .in (key_rotated[79:76]),
        .out(ksbox_out)
    );
    assign key_out = {ksbox_out, key_rotated[75:20], key_rotated[19:15] ^ round, key_rotated[14:0]};

endmodule
