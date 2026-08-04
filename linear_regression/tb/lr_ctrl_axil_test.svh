// Formal testbench for the AXI4-Lite control/status interface.
// Included in lr_ctrl_axil.sv when FORMAL is defined.
//
// This checker targets the module's default 32-bit AXI data interface.


// Protection for the 0th cycle.
logic formal_past_valid = 1'b0;
always_ff @(posedge S_AXI_ACLK) begin
    // Require active-low reset on the first sampled clock edge.
    // Slang does not support reading an input net from an initial block.
    if (!formal_past_valid) begin
        assume(!S_AXI_ARESETN);
    end

    formal_past_valid <= 1'b1;
end

// Expected value captured for an accepted read address.
function automatic logic [C_S_AXI_DATA_WIDTH-1:0] formal_read_data(
    input logic [C_S_AXI_ADDR_WIDTH-1:0] addr,
    input logic                          start_value,
    input logic                          clear_value,
    input logic                          busy_value,
    input logic                          done_value,
    input logic [31:0]                   num_samples_value,
    input logic [31:0]                   cycle_count_value,
    input logic [31:0]                   sample_count_value
);
    logic [C_S_AXI_DATA_WIDTH-1:0] value;
    begin
        value = '0;

        case (addr)
            ADDR_CTRL:         value[1:0] = {clear_value, start_value};
            ADDR_STAT:         value[1:0] = {busy_value, done_value};
            ADDR_NUM_SAMPLES:  value      = num_samples_value;
            ADDR_CYCLE_COUNT:  value      = cycle_count_value;
            ADDR_SAMPLE_COUNT: value      = sample_count_value;
            default:           value      = '0;
        endcase

        formal_read_data = value;
    end
endfunction


// Check independent AW/W buffering and one-response-at-a-time sequencing.
always_ff @(posedge S_AXI_ACLK) begin
    if (formal_past_valid) begin
        if (!$past(S_AXI_ARESETN)) begin
            reset_clears_aw_pending: assert(!aw_pending);
            reset_clears_w_pending: assert(!w_pending);
            reset_clears_bvalid: assert(!axi_bvalid);
            reset_clears_awaddr: assert(axi_awaddr == '0);
            reset_clears_wdata: assert(axi_wdata == '0);
            reset_clears_wstrb: assert(axi_wstrb == '0);
        end else begin
            // A write may commit only after both channel halves exist.
            if (write_commit) begin
                commit_has_address: assert(aw_pending || aw_accept);
                commit_has_data: assert(w_pending || w_accept);
            end

            // A stored channel half cannot be accepted again or overwritten.
            if (aw_pending) begin
                pending_address_blocks_second_address: assert(!aw_accept);
            end
            if (w_pending) begin
                pending_data_blocks_second_data: assert(!w_accept);
            end
            if (axi_bvalid) begin
                outstanding_response_blocks_address: assert(!aw_accept);
                outstanding_response_blocks_data: assert(!w_accept);
            end

            // A commit consumes both channel halves.
            if ($past(write_commit)) begin
                committed_address_is_consumed: assert(!aw_pending);
                committed_data_is_consumed: assert(!w_pending);
            end else begin
                if ($past(aw_accept)) begin
                    accepted_address_becomes_pending: assert(aw_pending);
                end else begin
                    address_pending_state_holds: assert(
                        aw_pending == $past(aw_pending)
                    );
                end

                if ($past(w_accept)) begin
                    accepted_data_becomes_pending: assert(w_pending);
                end else begin
                    data_pending_state_holds: assert(
                        w_pending == $past(w_pending)
                    );
                end
            end

            // Accepted payloads are captured exactly once.
            if ($past(aw_accept)) begin
                accepted_address_is_captured: assert(
                    axi_awaddr == $past(S_AXI_AWADDR)
                );
            end else begin
                address_buffer_holds: assert(
                    axi_awaddr == $past(axi_awaddr)
                );
            end

            if ($past(w_accept)) begin
                accepted_data_is_captured: assert(
                    axi_wdata == $past(S_AXI_WDATA)
                );
                accepted_strobes_are_captured: assert(
                    axi_wstrb == $past(S_AXI_WSTRB)
                );
            end else begin
                data_buffer_holds: assert(
                    axi_wdata == $past(axi_wdata)
                );
                strobe_buffer_holds: assert(
                    axi_wstrb == $past(axi_wstrb)
                );
            end

            // Each commit creates one response which remains until accepted.
            if ($past(write_commit)) begin
                commit_creates_response: assert(S_AXI_BVALID);
            end else if ($past(S_AXI_BVALID && S_AXI_BREADY)) begin
                accepted_response_clears_bvalid: assert(!S_AXI_BVALID);
            end else begin
                bvalid_holds_without_event: assert(
                    S_AXI_BVALID == $past(S_AXI_BVALID)
                );
            end

            if ($past(S_AXI_BVALID && !S_AXI_BREADY)) begin
                stalled_write_response_remains_valid: assert(S_AXI_BVALID);
                stalled_write_response_remains_stable: assert(
                    S_AXI_BRESP == $past(S_AXI_BRESP)
                );
            end
        end
    end
end


// Check the pulse-style control outputs.
always_ff @(posedge S_AXI_ACLK) begin
    if (formal_past_valid) begin
        if (!$past(S_AXI_ARESETN)) begin
            reset_clears_start: assert(!o_start);
            reset_clears_clear: assert(!o_clear);
        end else begin
            start_pulse_matches_control_write: assert(
                o_start
                == (
                    $past(write_commit)
                    && ($past(write_addr) == ADDR_CTRL)
                    && $past(write_strb[0])
                    && $past(write_data[0])
                    && !$past(i_busy)
                )
            );

            clear_pulse_matches_control_write: assert(
                o_clear
                == (
                    $past(write_commit)
                    && ($past(write_addr) == ADDR_CTRL)
                    && $past(write_strb[0])
                    && $past(write_data[1])
                )
            );
        end
    end
end

// Check all four byte lanes of the 32-bit sample-count register.
genvar formal_byte;
generate
    for (formal_byte = 0; formal_byte < 4; formal_byte = formal_byte + 1) begin : formal_num_samples_byte
        always_ff @(posedge S_AXI_ACLK) begin
            if (formal_past_valid) begin
                if (!$past(S_AXI_ARESETN)) begin
                    reset_clears_byte: assert(
                        o_num_samples[(formal_byte*8) +: 8] == 8'h00
                    );
                end else if (
                    $past(write_commit)
                    && ($past(write_addr) == ADDR_NUM_SAMPLES)
                    && $past(write_strb[formal_byte])
                ) begin
                    enabled_byte_is_written: assert(
                        o_num_samples[(formal_byte*8) +: 8]
                        == $past(write_data[(formal_byte*8) +: 8])
                    );
                end else begin
                    disabled_byte_holds_value: assert(
                        o_num_samples[(formal_byte*8) +: 8]
                        == $past(o_num_samples[(formal_byte*8) +: 8])
                    );
                end
            end
        end
    end
endgenerate


// Check read decoding and response backpressure.
always_ff @(posedge S_AXI_ACLK) begin
    if (formal_past_valid) begin
        if (!$past(S_AXI_ARESETN)) begin
            reset_clears_rvalid: assert(!S_AXI_RVALID);
            reset_clears_rdata: assert(S_AXI_RDATA == '0);
        end else begin
            if ($past(S_AXI_ARVALID && S_AXI_ARREADY)) begin
                accepted_read_creates_response: assert(S_AXI_RVALID);
                accepted_read_returns_expected_data: assert(
                    S_AXI_RDATA
                    == formal_read_data(
                        $past(S_AXI_ARADDR),
                        $past(o_start),
                        $past(o_clear),
                        $past(i_busy),
                        $past(i_done),
                        $past(o_num_samples),
                        $past(i_cycle_count),
                        $past(i_sample_count)
                    )
                );
            end else begin
                read_data_holds_without_new_address: assert(
                    S_AXI_RDATA == $past(S_AXI_RDATA)
                );

                if ($past(S_AXI_RVALID && S_AXI_RREADY)) begin
                    accepted_read_response_clears_rvalid: assert(!S_AXI_RVALID);
                end else begin
                    rvalid_holds_without_event: assert(
                        S_AXI_RVALID == $past(S_AXI_RVALID)
                    );
                end
            end

            if ($past(S_AXI_RVALID && !S_AXI_RREADY)) begin
                stalled_read_response_remains_valid: assert(S_AXI_RVALID);
                stalled_read_data_remains_stable: assert(
                    S_AXI_RDATA == $past(S_AXI_RDATA)
                );
                stalled_read_response_remains_stable: assert(
                    S_AXI_RRESP == $past(S_AXI_RRESP)
                );
            end
        end
    end
end


// Cover the important legal orderings and backpressure cases.
logic [1:0] formal_aw_first_state = 2'd0;
logic [1:0] formal_w_first_state  = 2'd0;

always_ff @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
        formal_aw_first_state <= 2'd0;
        formal_w_first_state  <= 2'd0;
    end else begin
        if (
            (formal_aw_first_state == 2'd0)
            && aw_accept
            && !w_accept
        ) begin
            formal_aw_first_state <= 2'd1;
        end else if (
            (formal_aw_first_state == 2'd1)
            && write_commit
            && w_accept
        ) begin
            formal_aw_first_state <= 2'd2;
        end

        if (
            (formal_w_first_state == 2'd0)
            && w_accept
            && !aw_accept
        ) begin
            formal_w_first_state <= 2'd1;
        end else if (
            (formal_w_first_state == 2'd1)
            && write_commit
            && aw_accept
        ) begin
            formal_w_first_state <= 2'd2;
        end
    end

    address_before_data_reachable: cover(formal_aw_first_state == 2'd2);
    data_before_address_reachable: cover(formal_w_first_state == 2'd2);

    simultaneous_write_reachable: cover(
        S_AXI_ARESETN
        && aw_accept
        && w_accept
        && write_commit
    );

    stalled_write_response_reachable: cover(
        S_AXI_ARESETN
        && S_AXI_BVALID
        && !S_AXI_BREADY
    );

    stalled_read_response_reachable: cover(
        S_AXI_ARESETN
        && S_AXI_RVALID
        && !S_AXI_RREADY
    );

    start_pulse_reachable: cover(S_AXI_ARESETN && o_start);
    clear_pulse_reachable: cover(S_AXI_ARESETN && o_clear);

    busy_start_request_reachable: cover(
        S_AXI_ARESETN
        && write_commit
        && (write_addr == ADDR_CTRL)
        && write_strb[0]
        && write_data[0]
        && i_busy
    );

    partial_num_samples_write_reachable: cover(
        S_AXI_ARESETN
        && write_commit
        && (write_addr == ADDR_NUM_SAMPLES)
        && (write_strb != '0)
        && (write_strb != '1)
    );

    status_read_reachable: cover(
        S_AXI_ARESETN
        && S_AXI_ARVALID
        && S_AXI_ARREADY
        && (S_AXI_ARADDR == ADDR_STAT)
    );

    invalid_read_reachable: cover(
        S_AXI_ARESETN
        && S_AXI_ARVALID
        && S_AXI_ARREADY
        && (S_AXI_ARADDR == 5'h1C)
    );
end
