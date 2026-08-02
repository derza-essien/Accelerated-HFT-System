`timescale 1ns / 1ps

// One-entry AXI4-Stream input buffer and accepted-sample counter.
module lr_input_axis #(
    parameter int DATA_WIDTH  = 256,
    parameter int COUNT_WIDTH = 32
) (
    input  logic                   clk,
    input  logic                   rst,

    input  logic                   start,
    input  logic                   clear,
    input  logic [COUNT_WIDTH-1:0] num_samples,
    output logic                   busy,
    output logic                   done,
    output logic [COUNT_WIDTH-1:0] accepted_counts,

    input  logic [DATA_WIDTH-1:0]  s_axis_tdata,
    input  logic                   s_axis_tvalid,
    output logic                   s_axis_tready,
    input  logic                   s_axis_tlast,

    output logic [DATA_WIDTH-1:0]  out_data,
    output logic                   out_valid,
    output logic                   out_last,
    input  logic                   out_ready
);

    logic running;

    logic [DATA_WIDTH-1:0] buffer_data;
    logic                  buffer_valid;
    logic                  buffer_last;

    logic take_input;
    logic send_output;
    logic taking_last_input;

    assign take_input        = s_axis_tvalid && s_axis_tready;
    assign send_output       = buffer_valid && out_ready;
    assign taking_last_input = take_input && (accepted_counts + 1'b1 == num_samples);

    assign s_axis_tready = running &&
                           (accepted_counts < num_samples) &&
                           (!buffer_valid || out_ready);

    assign out_valid = buffer_valid;
    assign out_data  = buffer_data;
    assign out_last  = buffer_last;

    always_ff @(posedge clk) begin
        if (rst || clear) begin
            running         <= 1'b0;
            done            <= 1'b0;
            busy            <= 1'b0;
            accepted_counts <= '0;
            buffer_valid    <= 1'b0;
            buffer_data     <= '0;
            buffer_last     <= 1'b0;
        end else begin
            done <= 1'b0;

            if (start && !busy) begin
                accepted_counts <= '0;
                buffer_valid    <= 1'b0;
                buffer_data     <= '0;
                buffer_last     <= 1'b0;

                if (num_samples == 0) begin
                    running <= 1'b0;
                    busy    <= 1'b0;
                    done    <= 1'b1;
                end else begin
                    running <= 1'b1;
                    busy    <= 1'b1;
                end
            end else begin
                if (send_output && !take_input) begin
                    buffer_valid <= 1'b0;

                    if (!running && (accepted_counts == num_samples)) begin
                        busy <= 1'b0;
                        done <= 1'b1;
                    end
                end

                if (take_input) begin
                    buffer_data     <= s_axis_tdata;
                    buffer_valid    <= 1'b1;
                    buffer_last     <= taking_last_input;
                    accepted_counts <= accepted_counts + 1'b1;

                    if (taking_last_input) begin
                        running <= 1'b0;
                    end
                end
            end
        end
    end

endmodule
