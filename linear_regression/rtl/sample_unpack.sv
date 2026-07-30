`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 19.03.2026 11:56:14
// Design Name: 
// Module Name: sample_unpack
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sample_unpack#(
    parameter DATA_WIDTH = 512,
    parameter NUM_PARAMS = 17
    )(
    input [DATA_WIDTH-1:0] num_samples,
    output logic signed [15:0] x [0:NUM_PARAMS-1],
    output logic signed [15:0] y
    );

assign y = num_samples[15:0];

genvar k;

generate;
    for(k = 0; k < NUM_PARAMS; k++) begin
        assign x[k] = num_samples[(k+1) * 16 + 15 : (k+1) * 16];
    end
endgenerate

endmodule
