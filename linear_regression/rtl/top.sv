`timescale 1ns / 1ps

module matrix_mult_top #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 5,
    parameter integer DATA_WIDTH = 512,
    parameter integer D = 17,
    parameter integer ACC_WIDTH = 64,
    parameter integer NUM_ACC = (D*(D+1))/2 // 91
)(  
    input  logic clk,
    input  logic resetn,

    // AXI4-Lite Control Slave Port
    input  logic [C_S_AXI_ADDR_WIDTH-1:0]       s_axi_awaddr,
    input  logic                               s_axi_awvalid,
    output logic                                s_axi_awready,
    input  logic [C_S_AXI_DATA_WIDTH-1:0]       s_axi_wdata,
    input  logic [(C_S_AXI_DATA_WIDTH/8)-1:0]   s_axi_wstrb,
    input  logic                                s_axi_wvalid,
    output logic                                s_axi_wready,
    output logic [1:0]                          s_axi_bresp,
    output logic                                s_axi_bvalid,
    input  logic                                s_axi_bready,
    input  logic [C_S_AXI_ADDR_WIDTH-1:0]       s_axi_araddr,
    input  logic                                s_axi_arvalid,
    output logic                                s_axi_arready,
    output logic [C_S_AXI_DATA_WIDTH-1:0]       s_axi_rdata,
    output logic [1:0]                          s_axi_rresp,
    output logic                                s_axi_rvalid,
    input  logic                                s_axi_rready,

    // AXI4 stream input ports for DMA
    input  logic [DATA_WIDTH-1:0] s_axis_tdata,
    input  logic s_axis_tvalid,
    output logic s_axis_tready,
    input  logic s_axis_tlast,

    // BRAM controller ports
    input  logic bram_clk,
    input  logic bram_en,
    input  logic [12:0] bram_addr,
    output logic [63:0] bram_dout
);
    logic rst;
    assign rst = ~resetn;

    // Control Signals
    logic        w_start;
    logic        w_clear;
    logic [31:0] w_num_samples;
    logic        w_ctrl_busy;
    logic        w_ctrl_done;
    logic [31:0] w_cycle_count;
    logic [31:0] w_sample_count;

    // Axis Input Signals
    logic                  w_axis_busy;
    logic                  w_axis_done;
    logic [DATA_WIDTH-1:0] w_axis_out_data;
    logic                  w_axis_out_valid;
    logic                  w_axis_out_last;
    logic                  w_axis_out_ready;

    // Unpack & Pipeline Signals
    logic signed [15:0] w_x_unpacked [0:D-1];
    logic signed [15:0] w_y_unpacked;

    // Math Core / Sequencer Signals
    logic                 w_start_sample;

    // Accumulator Outputs
    logic signed [ACC_WIDTH -1:0] w_atb_acc [0:D-1];
    logic signed [ACC_WIDTH -1:0] w_ata_acc [0:NUM_ACC-1];

    // handshake+pipeline logic
    logic is_dumping;
    assign w_axis_out_ready = !is_dumping;
    assign w_start_sample   = w_axis_out_valid && w_axis_out_ready;
    assign w_ctrl_busy = w_axis_busy || is_dumping;
    
    
    // count cycles
    always_ff @(posedge clk) begin
        if (rst || w_clear) begin
            w_cycle_count <= 0;
        end else if (w_ctrl_busy) begin
            w_cycle_count <= w_cycle_count + 1;
        end
    end    
    
    lr_ctrl_axil #(
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
    ) ctrl_inst (
        .S_AXI_ACLK    (clk),
        .S_AXI_ARESETN (resetn),
        .S_AXI_AWADDR  (s_axi_awaddr),
        .S_AXI_AWVALID (s_axi_awvalid),
        .S_AXI_AWREADY (s_axi_awready),
        .S_AXI_WDATA   (s_axi_wdata),
        .S_AXI_WSTRB   (s_axi_wstrb),
        .S_AXI_WVALID  (s_axi_wvalid),
        .S_AXI_WREADY  (s_axi_wready),
        .S_AXI_BRESP   (s_axi_bresp),
        .S_AXI_BVALID  (s_axi_bvalid),
        .S_AXI_BREADY  (s_axi_bready),
        .S_AXI_ARADDR  (s_axi_araddr),
        .S_AXI_ARVALID (s_axi_arvalid),
        .S_AXI_ARREADY (s_axi_arready),
        .S_AXI_RDATA   (s_axi_rdata),
        .S_AXI_RRESP   (s_axi_rresp),
        .S_AXI_RVALID  (s_axi_rvalid),
        .S_AXI_RREADY  (s_axi_rready),
        .o_start       (w_start),
        .o_clear       (w_clear),
        .o_num_samples (w_num_samples),
        .i_busy        (w_ctrl_busy),
        .i_done        (w_ctrl_done),
        .i_cycle_count (w_cycle_count),
        .i_sample_count(w_sample_count)
    );

    lr_input_axis #(
        .DATA_WIDTH(DATA_WIDTH),
        .COUNT_WIDTH(32)
    ) axis_inst (
        .clk             (clk),
        .rst             (rst),
        .start           (w_start),
        .clear           (w_clear),
        .num_samples     (w_num_samples),
        .busy            (w_axis_busy),
        .done            (w_axis_done),
        .accepted_counts (w_sample_count),
        .s_axis_tdata    (s_axis_tdata),
        .s_axis_tvalid   (s_axis_tvalid),
        .s_axis_tready   (s_axis_tready),
        .s_axis_tlast    (s_axis_tlast),
        .out_data        (w_axis_out_data),
        .out_valid       (w_axis_out_valid),
        .out_last        (w_axis_out_last),
        .out_ready       (w_axis_out_ready)
    );

    sample_unpack #(
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_PARAMS(D)
    ) unpack_inst (
        .num_samples (w_axis_out_data),
        .x           (w_x_unpacked),
        .y           (w_y_unpacked)
    );

    atb_bank #(
        .D(D),
        .X_WIDTH(16), 
        .Y_WIDTH(16),
        .ACC_WIDTH(ACC_WIDTH)
    ) atb_inst (
        .clk      (clk),
        .rst      (rst || w_clear),
        .sample_valid (w_start_sample),
        .x_reg    (w_x_unpacked),
        .y_reg    (w_y_unpacked), 
        .valid_out (),
        .atb_acc  (w_atb_acc)
    );

    ata_lower_bank #(
        .NUM_PARAMS(D),
        .NUM_ACC(NUM_ACC),
        .ACC_WIDTH(ACC_WIDTH)
    ) ata_inst(
        .clk      (clk),
        .rst      (rst || w_clear),
        .x        (w_x_unpacked),
        .acc      (w_ata_acc),
        .sample_valid (w_start_sample),
        .valid_out ()
    );

    // write to BRAM
    logic [7:0]  dump_addr;
    logic [63:0] dump_data;
    logic        dump_we;
    logic [7:0] dump_addr_ram;
    
    // Safe read multiplexing to prevent Vivado from optimizing arrays away
    logic [7:0] safe_ata_idx;
    logic [7:0] safe_atb_idx;

    // If out of bounds, force the index to 0 so Vivado doesn't panic
    assign safe_atb_idx = (dump_addr < D) ? dump_addr : 8'd0;
    assign safe_ata_idx = (dump_addr >= D) ? (dump_addr - D) : 8'd0;
    
    always_ff @(posedge clk) begin
    if (rst || w_clear) begin
        dump_addr_ram <= '0;
    end else begin
        dump_addr_ram <= dump_addr; // Delays the address by 1 cycle
    end
end

    typedef enum logic [1:0] {IDLE, DUMPING, DONE} state_t;
    state_t state, next_state;

    // trigger dump when input is completely done, and row controller finishes last sample
    
    logic axis_done_sticky;
    always_ff @(posedge clk) begin
        if (rst || w_clear || w_start) begin
            axis_done_sticky <= 1'b0;
        end else if (w_axis_done) begin
            axis_done_sticky <= 1'b1;
        end
    end

    logic trigger_dump;
    assign trigger_dump = axis_done_sticky;

    always_ff @(posedge clk) begin
        if (rst || w_clear || w_start) begin
            state       <= IDLE;
            dump_addr   <= '0;
            dump_we     <= 1'b0;
            dump_data   <= '0;
            is_dumping  <= 1'b0;
            w_ctrl_done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (trigger_dump) begin
                        state      <= DUMPING;
                        is_dumping <= 1'b1;
                        dump_addr  <= '0;
                    end
                end
                
                DUMPING: begin
                    dump_we <= 1'b1;
                    
                    if (dump_addr < D) begin
                        dump_data <= w_atb_acc[safe_atb_idx];
                    end else begin
                        // sign extend the 32-bit ata accumulator to 64-bit for BRAM storage
                        dump_data <= w_ata_acc[safe_ata_idx];
                    end
                    
                    if (dump_addr == (D + NUM_ACC - 1)) begin
                        state <= DONE;
                    end else begin
                        dump_addr <= dump_addr + 1;
                    end
                end


                DONE: begin
                    dump_we     <= 1'b0;
                    is_dumping  <= 1'b0;
                    w_ctrl_done <= 1'b1;
                end
            endcase
        end
    end

    result_store #(
        .DATA_WIDTH(64),
        .ADDR_WIDTH(9)
    ) bram_inst(
        .clka  (clk),
        .ena   (is_dumping),
        .wea   (dump_we),
        .addra (dump_addr_ram),
        .dina  (dump_data),
        
        .clkb  (bram_clk),
        .enb   (bram_en),
        .addrb (bram_addr[7:0]),
        .doutb (bram_dout)
    );

endmodule