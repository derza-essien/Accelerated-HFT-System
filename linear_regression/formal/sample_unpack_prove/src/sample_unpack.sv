`timescale 1ns / 1ps

// Combinational unpacking of one packed regression sample.
module sample_unpack #(
    parameter DATA_WIDTH = 512,
    parameter NUM_PARAMS = 17
) (
    input  [DATA_WIDTH-1:0]      num_samples,
    output logic signed [NUM_PARAMS-1:0][15:0]   x,
    output logic signed [15:0]   y
);

    // The target occupies the least-significant 16 bits.
    assign y = num_samples[15:0];

    genvar k;
    generate;
        // Features follow the target in consecutive 16-bit fields.
        for (k = 0; k < NUM_PARAMS; k++) begin
            assign x[k] = num_samples[(k+1) * 16 + 15 : (k+1) * 16];
        end
    endgenerate

    `ifdef FORMAL
    `include "sample_unpack_test.svh"
    `endif 

endmodule