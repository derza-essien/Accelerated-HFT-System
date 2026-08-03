
    // Force synchronous clocks to eliminate multi-clock translation glitches
    //always_comb assume(clka == clkb);

    logic first_valid_a = 1'b0;
    logic first_valid_b = 1'b0;

    always_ff @(posedge clka) first_valid_a <= 1'b1;
    always_ff @(posedge clkb) first_valid_b <= 1'b1;

    // Port A test - writing into ram
    always_ff @(posedge clka) begin
        if (first_valid_a && $past(ena) && $past(wea)) begin
            writing_into_ram: assert(ram[$past(addra)] == $past(dina));
        end
    end

    // Port B test - reading the output RAM
    always_ff @(posedge clkb) begin
        if (first_valid_b && $past(enb)) begin
            reading_from_ram: assert(doutb == ram[$past(addrb)]);
            data_read: cover(doutb != '0);
        end
    end
