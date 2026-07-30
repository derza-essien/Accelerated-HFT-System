module atb_bank #(
    parameter int D         = 17,
    parameter int X_WIDTH   = 16,
    parameter int Y_WIDTH   = 16,
    parameter int ACC_WIDTH = 64
)(
    input  logic                               clk,
    input  logic                               rst,
    input  logic                               sample_valid,
    input  logic signed [X_WIDTH-1:0]          x_reg [0:D-1],
    input  logic signed [Y_WIDTH-1:0]          y_reg,
    output logic                               valid_out,
    output logic signed [ACC_WIDTH-1:0]        atb_acc [0:D-1]
);

genvar i;
generate
    // Build exactly D dedicated multipliers for the Atb vector
    for (i = 0; i < D; i = i + 1) begin : atb_gen
        
        always_ff @(posedge clk) begin
            if (rst) begin
                atb_acc[i] <= 0;
            end else if (sample_valid) begin
                // 16-bit x 16-bit infers 1 DSP slice
                // Multiplies the i-th x parameter by the single y parameter
                atb_acc[i] <= atb_acc[i] + (x_reg[i] * y_reg);
            end
        end
        
    end
endgenerate

always_ff@(posedge clk) begin
    if(rst) begin
        valid_out <= 0;
        end
    else begin
        valid_out <= sample_valid;
        end
end
    
endmodule