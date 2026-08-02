`timescale 1ns / 1ps

// Simple dual-clock result memory: write-only port A and read-only port B.
module result_store #(
    parameter int DATA_WIDTH = 64,
    parameter int ADDR_WIDTH = 8
) (
    input  logic                  clka,
    input  logic                  ena,
    input  logic                  wea,
    input  logic [ADDR_WIDTH-1:0] addra,
    input  logic [DATA_WIDTH-1:0] dina,

    // BRAM-controller read port.
    input  logic                  clkb,
    input  logic                  enb,
    input  logic [ADDR_WIDTH-1:0] addrb,
    output logic [DATA_WIDTH-1:0] doutb
);

    (* ram_style = "block" *) logic [DATA_WIDTH-1:0] ram [0:(2**ADDR_WIDTH)-1];

    initial begin
        for (int i = 0; i < 2**ADDR_WIDTH; i++) begin
            ram[i] = '0;
        end
    end

    // Write-only port A.
    always_ff @(posedge clka) begin
        if (ena) begin
            if (wea) begin
                ram[addra] <= dina;
            end
        end
    end

    // Read-only port B.
    always_ff @(posedge clkb) begin
        if (enb) begin
            doutb <= ram[addrb];
        end
    end

endmodule
