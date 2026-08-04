// Test for sample unpack

always_comb begin
    y_is_lsb: assert(y == num_samples[15:0]);

    y_read: cover(y != 16'd0);
end

genvar i;
generate
    for(i = 0; i < NUM_PARAMS; i++) begin : gen_sva_1
        always_comb begin
            assert(x[i] == num_samples[(i+1)*16 + 15 : (i+1) * 16]);
            cover(x[i] != 16'd0);
        end
    end
endgenerate