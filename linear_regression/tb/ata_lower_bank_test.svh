// formal tb for lower bank 
// included in ata_lower_bank.sv when FORMAL is defined


// protection for 0th cycle
logic formal_past_valid = 1'b0;
always_ff @(posedge clk) begin
    formal_past_valid <= 1'b1; 
end

// so that all later assertions are only checked after the first cycle
initial begin
    assume(rst);
end

// function to compute the formal product
function automatic logic signed [ACC_WIDTH-1:0] formal_product(
    input logic signed [15:0] a, 
    input logic signed [15:0] b
    );
    logic signed [31:0] product;
    begin
        product = a * b;
        formal_product = product;
    end
endfunction

// formal property to check that the accumulator is updated correctly
always_ff @(posedge clk) begin
    if(formal_past_valid) begin
        if($past(rst)) begin
            reset_clears_valid: assert(valid_out == 0);
        end else begin
            valid_assignment: assert(valid_out == $past(sample_valid));
        end
    end
end

// generate for all formal numbers 
genvar formal_i, formal_j;
generate
    for(formal_i = 0; formal_i < NUM_PARAMS; formal_i = formal_i + 1) begin: formal_row_gen
        for(formal_j = 0; formal_j <= formal_i; formal_j = formal_j + 1) begin: formal_col_gen
            localparam int FORMAL_IDX = (formal_i * (formal_i + 1)) / 2 + formal_j;
            always_ff @(posedge clk) begin
                if (formal_past_valid) begin
                    if ($past(rst)) begin
                        reset_clears_accumulator: assert(acc[FORMAL_IDX] == '0);
                    end else if ($past(sample_valid)) begin
                        accepted_sample_updates_once: assert(acc[FORMAL_IDX] == $past(acc[FORMAL_IDX]) + formal_product($past(x[formal_i]), $past(x[formal_j])));
                    end else begin
                        invalid_cycle_loads_accumulator: assert(acc[FORMAL_IDX] == $past(acc[FORMAL_IDX]));
                    end
                end
            end
        end
    end
endgenerate



logic [1:0] formal_cover_state = 2'd0;
// cover property to check that the accumulator is updated at least once
always_ff @(posedge clk) begin
    if (rst) begin
        formal_cover_state <= 2'd1;
    end else if ((formal_cover_state == 2'd1) && sample_valid) begin 
        formal_cover_state <= 2'd2;
    end else if ((formal_cover_state == 2'd2) && (acc[0] != '0)) begin
        formal_cover_state <= 2'd3;
    end

    nonzero_update_reachable: cover(formal_cover_state == 2'd3);
end