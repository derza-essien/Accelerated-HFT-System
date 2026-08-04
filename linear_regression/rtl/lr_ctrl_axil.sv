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

    // One-entry storage for the independent write address and data channels.
    logic aw_pending;
    logic w_pending;
    logic axi_bvalid;
    logic [C_S_AXI_ADDR_WIDTH-1:0]         axi_awaddr;
    logic [C_S_AXI_DATA_WIDTH-1:0]         axi_wdata;
    logic [(C_S_AXI_DATA_WIDTH/8)-1:0]     axi_wstrb;

    logic aw_accept;
    logic w_accept;
    logic write_commit;
    logic [C_S_AXI_ADDR_WIDTH-1:0]         write_addr;
    logic [C_S_AXI_DATA_WIDTH-1:0]         write_data;
    logic [(C_S_AXI_DATA_WIDTH/8)-1:0]     write_strb;

    // Only one write transaction is outstanding at a time.
    assign S_AXI_AWREADY = !aw_pending && !axi_bvalid;
    assign S_AXI_WREADY  = !w_pending && !axi_bvalid;
    assign S_AXI_BRESP   = 2'b00;
    assign S_AXI_BVALID  = axi_bvalid;

    assign aw_accept = S_AXI_AWVALID && S_AXI_AWREADY;
    assign w_accept  = S_AXI_WVALID && S_AXI_WREADY;

    // Select either a previously buffered channel or the channel accepted this cycle.
    assign write_addr = aw_pending ? axi_awaddr : S_AXI_AWADDR;
    assign write_data = w_pending  ? axi_wdata  : S_AXI_WDATA;
    assign write_strb = w_pending  ? axi_wstrb  : S_AXI_WSTRB;

    assign write_commit = !axi_bvalid &&
                          (aw_pending || aw_accept) &&
                          (w_pending || w_accept);

    // One-entry read response channel.
    logic axi_rvalid;
    logic [C_S_AXI_DATA_WIDTH-1:0] axi_rdata;

    assign S_AXI_ARREADY = !axi_rvalid;
    assign S_AXI_RDATA   = axi_rdata;
    assign S_AXI_RRESP   = 2'b00;
    assign S_AXI_RVALID  = axi_rvalid;

    // Write handling. AW and W may arrive in either order or in the same cycle.
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            aw_pending   <= 1'b0;
            w_pending    <= 1'b0;
            axi_bvalid   <= 1'b0;
            axi_awaddr   <= '0;
            axi_wdata    <= '0;
            axi_wstrb    <= '0;
            o_num_samples <= '0;
            o_start      <= 1'b0;
            o_clear      <= 1'b0;
        end else begin
            o_start <= 1'b0;
            o_clear <= 1'b0;

            if (aw_accept) begin
                axi_awaddr <= S_AXI_AWADDR;
                aw_pending <= 1'b1;
            end

            if (w_accept) begin
                axi_wdata <= S_AXI_WDATA;
                axi_wstrb <= S_AXI_WSTRB;
                w_pending <= 1'b1;
            end

            if (write_commit) begin
                aw_pending <= 1'b0;
                w_pending  <= 1'b0;
                axi_bvalid <= 1'b1;

                case (write_addr)
                    ADDR_CTRL: begin
                        if (write_strb[0]) begin
                            // Ignore a second start request while an operation is active.
                            o_start <= write_data[0] && !i_busy;
                            o_clear <= write_data[1];
                        end
                    end
                    ADDR_NUM_SAMPLES: begin
                        for (int byte_idx = 0; byte_idx < C_S_AXI_DATA_WIDTH/8; byte_idx++) begin
                            if (write_strb[byte_idx]) begin
                                o_num_samples[(byte_idx*8) +: 8] <= write_data[(byte_idx*8) +: 8];
                            end
                        end
                    end
                    default: ;
                endcase
            end else if (axi_bvalid && S_AXI_BREADY) begin
                axi_bvalid <= 1'b0;
            end
        end
    end

    // Read handling. Do not accept a second address while a response is pending.
    always_ff @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axi_rvalid <= 1'b0;
            axi_rdata  <= '0;
        end else begin
            if (S_AXI_ARVALID && S_AXI_ARREADY) begin
                axi_rvalid <= 1'b1;
                axi_rdata  <= '0;

                case (S_AXI_ARADDR)
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

    // Formal properties are kept separate from the synthesizable interface.
    `ifdef FORMAL
        `include "lr_ctrl_axil_test.svh"
    `endif

endmodule
