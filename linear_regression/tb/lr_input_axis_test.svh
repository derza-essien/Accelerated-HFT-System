// Initialisation (rst and clear signals)
logic intialised = 1'b0;

always_ff @(posedge clk) intialised <=  1'b1;

always_comb begin
    if(!intialised) begin
        assume(rst == 1'b1);
        assume(clear == 1'b1);
    end
end

// Assetion tests for combinational signals


always_comb begin
    take_input_assert:   assert(take_input == (s_axis_tvalid && s_axis_tready));
    send_output_assert:  assert(send_output == (buffer_valid && out_ready));
    take_last_i_assert:  assert(taking_last_input == (take_input &&
                                                    (accepted_counts + 1'b1 == expected_samples)));
    axis_tready_assert:  assert(s_axis_tready == (running &&
                                                accepted_counts < expected_samples &&
                                                (!buffer_valid || out_ready)));
    out_valid_assert:    assert(out_valid == buffer_valid);
    out_data_assert:     assert(out_data == buffer_data);
    out_last_assert:     assert(out_last == buffer_last);
end

// Cover tests for combinational signals

always_comb begin
    take_input_cover:   cover(take_input == 1'b1);
    send_output_cover:  cover(send_output == 1'b1);
    take_last_i_cover:  cover(taking_last_input == 1'b1);
    axis_tready_cover:  cover(s_axis_tready == 1'b1);
    out_valid_cover:    cover(out_valid == 1'b1);
    out_data_cover:     cover(out_data == 1'b1);
    out_last_cover:     cover(out_last == 1'b1);
end

// Assertion tests for sequential signals

always_ff @(posedge clk) begin
    if(intialised) begin

        if($past(rst) || $past(clear)) begin
            assert(running == 1'b0);
            assert(expected_samples == '0);
            assert(done == 1'b0);
            assert(busy == 1'b0);
            assert(accepted_counts == '0);
            assert(buffer_valid == 1'b0);
            assert(buffer_data == '0);
            assert(buffer_last == 1'b0);
        end
        else begin
            if($past(start) && !$past(busy)) begin
                assert(expected_samples == $past(num_samples));
                assert(accepted_counts == '0);
                assert(buffer_valid == 1'b0);
                assert(buffer_data == '0);
                assert(buffer_last == 1'b0);

                if($past(num_samples) == 0) begin
                    assert(running == 1'b0);
                    assert(busy == 1'b0);
                    assert(done == 1'b1);
                end
                else begin
                    assert(running == 1'b1);
                    assert(busy == 1'b1);
                end
            end
            
            else begin
                if($past(send_output) && !$past(take_input)) begin
                    assert(buffer_valid == 1'b0);
                    if(!$past(running) && ($past(accepted_counts) == $past(expected_samples))) begin
                        assert(busy == 1'b0);
                        assert(done == 1'b1);
                    end
                end

                if($past(take_input)) begin
                    assert(buffer_data == $past(s_axis_tdata));
                    assert(buffer_valid == 1'b1);
                    assert(buffer_last == $past(taking_last_input));
                    assert(accepted_counts == $past(accepted_counts) + 1'b1);

                    if($past(taking_last_input)) assert(running == 1'b0);
                end
            end
        end
    end
end

// Cover tests for some signals in sequntial logic

always_comb begin
    if(intialised && !rst && !clear) begin
        cover_axis_data:    cover(s_axis_tdata == 256'd500);
        cover_num_samples:  cover(num_samples == 32'd10);
        cover_acc_cnts:     cover(accepted_counts == 32'd5);
        cover_out_data:     cover(out_data == 256'd3000000);
    end
end
