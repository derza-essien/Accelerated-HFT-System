// Formal testbench for the A^T b accumulator bank.
// Included in atb_bank.sv when FORMAL is defined.


// Protection for the 0th cycle.
logic formal_past_valid = 1'b0;
always_ff @(posedge clk) begin
    // Require reset on the first sampled clock edge.
    // Slang does not support reading an input net from an initial block.
    if (!formal_past_valid) begin
        assume(rst);
    end

    formal_past_valid <= 1'b1;
end

// Compute the full signed product before converting it to accumulator width.
function automatic logic signed [ACC_WIDTH-1:0] formal_product(
    input logic signed [X_WIDTH-1:0] a,
    input logic signed [Y_WIDTH-1:0] b
);
    logic signed [(X_WIDTH + Y_WIDTH)-1:0] product;
    begin
        product = a * b;
        formal_product = product;
    end
endfunction

// Check the one-cycle valid pipeline.
always_ff @(posedge clk) begin
    if (formal_past_valid) begin
        if ($past(rst)) begin
            reset_clears_valid: assert(valid_out == 1'b0);
        end else begin
            valid_assignment: assert(valid_out == $past(sample_valid));
        end
    end
end

// Check every A^T b lane independently.
genvar formal_i;
generate
    for (formal_i = 0; formal_i < D; formal_i = formal_i + 1) begin : formal_atb_gen
        always_ff @(posedge clk) begin
            if (formal_past_valid) begin
                if ($past(rst)) begin
                    reset_clears_accumulator: assert(atb_acc[formal_i] == '0);
                end else if ($past(sample_valid)) begin
                    accepted_sample_updates_once: assert(
                        atb_acc[formal_i]
                        == $past(atb_acc[formal_i])
                         + formal_product(
                               $past(x_reg[formal_i]),
                               $past(y_reg)
                           )
                    );
                end else begin
                    invalid_cycle_holds_accumulator: assert(
                        atb_acc[formal_i] == $past(atb_acc[formal_i])
                    );
                end
            end
        end
    end
endgenerate


// Confirm that reset followed by a non-zero accepted sample can update a lane.
logic [1:0] formal_cover_state = 2'd0;
always_ff @(posedge clk) begin
    if (rst) begin
        formal_cover_state <= 2'd1;
    end else if (
        (formal_cover_state == 2'd1)
        && sample_valid
        && (x_reg[0] != '0)
        && (y_reg != '0)
    ) begin
        formal_cover_state <= 2'd2;
    end else if (
        (formal_cover_state == 2'd2)
        && (atb_acc[0] != '0)
    ) begin
        formal_cover_state <= 2'd3;
    end

    nonzero_update_reachable: cover(formal_cover_state == 2'd3);
end
