// Testbench for result_store.sv

// specific address to test (anyconst ensures one random value is chosen)
(* anyconst *) logic [ADDR_WIDTH-1:0]   chosen_addr;

logic target_written = 1'b0;
logic [DATA_WIDTH-1:0]  target_data;

logic past_available = 1'b0;
logic check_read     = 1'b0;
logic first_cycle    = 1'b1;


always_comb begin
    // default values for the first cycle
    if(first_cycle) begin
        assume(doutb == '0);
        assume(dina == '0);
        assume(ena == '0);
        assume(wea == '0);
        assume(enb == '0);
    end

    if (target_written) begin
        assume(!(ena && wea && (addra == chosen_addr)));
    end
end

// Port A test - writing into ram
always_ff @(posedge clka) begin
    if (ena && wea && (addra == chosen_addr)) begin
        target_written  <=  1'b1;
        target_data     <=  dina;
    end
    if(target_written) begin
        // check that the target data is the same as that written into the RAM
        ram_state_match: assume(ram[chosen_addr] == target_data);
    end
end

// Port B test - reading the output RAM
always_ff @(posedge clkb) begin
    first_cycle <=  1'b0;
    // Only checks output data the cycle after it is written into (ensures there isnt a race condition/ correct timing)
    check_read  <=  enb && (addrb == chosen_addr) && target_written;
    if (check_read) begin
        // Check that the output data is equal to that written into the ram
        reading_from_ram: assert(doutb == target_data);
        data_read: cover(doutb != '0);
    end
end
