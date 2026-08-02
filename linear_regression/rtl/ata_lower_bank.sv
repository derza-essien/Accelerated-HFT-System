// Lower-triangular A^T A accumulator bank.
module ata_lower_bank #(
    parameter NUM_PARAMS = 17,
    parameter NUM_ACC    = (NUM_PARAMS * (NUM_PARAMS + 1)) / 2,
    parameter ACC_WIDTH  = 64
) (
    input  logic                              clk,
    input  logic                              rst,
    input  logic                              sample_valid,
    input  logic signed [15:0]                x [0:NUM_PARAMS-1],
    output logic                              valid_out,
    output logic signed [ACC_WIDTH-1:0]       acc [0:NUM_ACC-1]
);

    genvar i, j;
    generate
        // Build one dedicated multiplier-accumulator for each lower-triangular term.
        for (i = 0; i < NUM_PARAMS; i = i + 1) begin : row_gen
            for (j = 0; j <= i; j = j + 1) begin : col_gen
                localparam int idx = (i * (i + 1)) / 2 + j;

                always_ff @(posedge clk) begin
                    if (rst) begin
                        acc[idx] <= 0;
                    end else if (sample_valid) begin
                        // A 16-bit by 16-bit multiplication is intended to infer one DSP.
                        acc[idx] <= acc[idx] + (x[i] * x[j]);
                    end
                end
            end
        end
    endgenerate

    always_ff @(posedge clk) begin
        if (rst) begin
            valid_out <= 0;
        end else begin
            valid_out <= sample_valid;
        end
    end

endmodule
