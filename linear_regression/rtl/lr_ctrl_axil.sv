`timescale 1ns / 1ps

// AXI4-Lite control and status register interface for the accelerator.
module lr_ctrl_axil #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 5
) (
    // AXI4-Lite clock and active-low reset.
    input  wire                                      S_AXI_ACLK,
    input  wire                                      S_AXI_ARESETN,

    // Write address channel.
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]             S_AXI_AWADDR,
    input  wire                                      S_AXI_AWVALID,
    output wire                                      S_AXI_AWREADY,

    // Write data channel.
    input  wire [C_S_AXI_DATA_WIDTH-1:0]             S_AXI_WDATA,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0]         S_AXI_WSTRB,
    input  wire                                      S_AXI_WVALID,
    output wire                                      S_AXI_WREADY,

    // Write response channel.
    output wire [1:0]                                S_AXI_BRESP,
    output wire                                      S_AXI_BVALID,
    input  wire                                      S_AXI_BREADY,

    // Read address channel.
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]             S_AXI_ARADDR,
    input  wire                                      S_AXI_ARVALID,
    output wire                                      S_AXI_ARREADY,

    // Read data channel.
    output wire [C_S_AXI_DATA_WIDTH-1:0]             S_AXI_RDATA,
    output wire [1:0]                                S_AXI_RRESP,
    output wire                                      S_AXI_RVALID,
    input  wire                                      S_AXI_RREADY,

    output logic                                     o_start,
    output logic                                     o_clear,
    output logic [31:0]                              o_num_samples,

    input  wire                                      i_busy,
    input  wire                                      i_done,
    input  wire [31:0]                               i_cycle_count,
    input  wire [31:0]                               i_sample_count
);

    // Register offsets.
    localparam logic [C_S_AXI_ADDR_WIDTH-1:0] ADDR_CTRL         = 5'h00;
    localparam logic [C_S_AXI_ADDR_WIDTH-1:0] ADDR_STAT         = 5'h04;
    localparam logic [C_S_AXI_ADDR_WIDTH-1:0] ADDR_NUM_SAMPLES  = 5'h08;
    localparam logic [C_S_AXI_ADDR_WIDTH-1:0] ADDR_CYCLE_COUNT  = 5'h0C;
    localparam logic [C_S_AXI_ADDR_WIDTH-1:0] ADDR_SAMPLE_COUNT = 5'h10;

    // AXI handshake state.
    logic aw_en;
    logic axi_awready;
    logic axi_wready;
    logic axi_bvalid;
    logic axi_arready;
    logic axi_rvalid;
    logic [C_S_AXI_DATA_WIDTH-1:0] axi_rdata;
    logic [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
    logic [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;

    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = 2'b00;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA   = axi_rdata;
    assign S_AXI_RRESP   = 2'b00;
    assign S_AXI_RVALID  = axi_rvalid;

    // Write handling.
    always_ff @(posedge S_AXI_ACLK) begin
        if (~S_AXI_ARESETN) begin
            axi_awready   <= 1'b0;
            axi_wready    <= 1'b0;
            axi_bvalid    <= 1'b0;
            aw_en         <= 1'b1;
            axi_awaddr    <= '0;
            o_num_samples <= '0;
            o_start       <= 1'b0;
            o_clear       <= 1'b0;
        end else begin
            o_start <= 1'b0;
            o_clear <= 1'b0;

            if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en) begin
                axi_awready <= 1'b1;
                aw_en       <= 1'b0;
                axi_awaddr  <= S_AXI_AWADDR;
            end else if (S_AXI_BREADY && axi_bvalid) begin
                aw_en       <= 1'b1;
                axi_awready <= 1'b0;
            end else begin
                axi_awready <= 1'b0;
            end

            if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en) begin
                axi_wready <= 1'b1;
            end else begin
                axi_wready <= 1'b0;
            end

            if (axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID) begin
                axi_bvalid <= 1'b1;

                case (axi_awaddr)
                    ADDR_CTRL: begin
                        if (S_AXI_WSTRB[0]) begin
                            o_start <= S_AXI_WDATA[0];
                            o_clear <= S_AXI_WDATA[1];
                        end
                    end
                    ADDR_NUM_SAMPLES: begin
                        for (int byte_idx = 0; byte_idx <= (C_S_AXI_DATA_WIDTH/8)-1; byte_idx++) begin
                            if (S_AXI_WSTRB[byte_idx]) begin
                                o_num_samples[(byte_idx*8) +: 8] <= S_AXI_WDATA[(byte_idx*8) +: 8];
                            end
                        end
                    end
                    default: ;
                endcase
            end else begin
                if (S_AXI_BREADY && axi_bvalid) begin
                    axi_bvalid <= 1'b0;
                end
            end
        end
    end

    // Read handling.
    always_ff @(posedge S_AXI_ACLK) begin
        if (~S_AXI_ARESETN) begin
            axi_arready <= 1'b0;
            axi_rvalid  <= 1'b0;
            axi_rdata   <= '0;
            axi_araddr  <= '0;
        end else begin
            if (~axi_arready && S_AXI_ARVALID) begin
                axi_arready <= 1'b1;
                axi_araddr  <= S_AXI_ARADDR;
            end else begin
                axi_arready <= 1'b0;
            end

            if (axi_arready && S_AXI_ARVALID && ~axi_rvalid) begin
                axi_rvalid <= 1'b1;
                axi_rdata  <= '0;

                case (axi_araddr)
                    ADDR_CTRL:         axi_rdata[1:0] <= {o_clear, o_start};
                    ADDR_STAT:         axi_rdata[1:0] <= {i_busy, i_done};
                    ADDR_NUM_SAMPLES:  axi_rdata      <= o_num_samples;
                    ADDR_CYCLE_COUNT:  axi_rdata      <= i_cycle_count;
                    ADDR_SAMPLE_COUNT: axi_rdata      <= i_sample_count;
                    default:           axi_rdata      <= '0;
                endcase
            end else if (axi_rvalid && S_AXI_RREADY) begin
                axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
