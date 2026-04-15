`default_nettype none

module present_core (
    // S-box byte interface
    input  wire [7:0] sbox_byte_in,
    output wire [7:0] sbox_byte_out,
    
    // P-layer interface
    input  wire [63:0] p_layer_in,
    output wire [63:0] p_layer_out,
    
    // Key schedule interface
    input  wire [79:0] key_in,
    input  wire [4:0]  round,
    output wire [79:0] key_out
);

    // ----- Byte-Serial S-Box Datapath -----
    // Uses exactly 2 physical S-Boxes instead of 16
    sbox s1 (
        .in (sbox_byte_in[7:4]),
        .out(sbox_byte_out[7:4])
    );
    sbox s0 (
        .in (sbox_byte_in[3:0]),
        .out(sbox_byte_out[3:0])
    );

    // ----- Full-Block P-Layer (Zero Gates, Pure Wiring) -----
    genvar i;
    generate
        for (i = 0; i < 63; i = i + 1) begin : p_layer
            // Standard PRESENT bit permutation
            assign p_layer_out[(i*16) % 63] = p_layer_in[i];
        end
    endgenerate
    assign p_layer_out[63] = p_layer_in[63];

    // ----- Key Schedule Combinational Logic -----
    wire [79:0] key_rotated;
    // Rotate left by 61 is equivalent to rotate right by 19
    assign key_rotated = {key_in[18:0], key_in[79:19]}; 

    wire [3:0] ksbox_out;
    sbox ks (
        .in (key_rotated[79:76]),
        .out(ksbox_out)
    );

    // Insert S-box back into key and XOR with round counter
    assign key_out = {ksbox_out, key_rotated[75:20], key_rotated[19:15] ^ round, key_rotated[14:0]};

endmodule
