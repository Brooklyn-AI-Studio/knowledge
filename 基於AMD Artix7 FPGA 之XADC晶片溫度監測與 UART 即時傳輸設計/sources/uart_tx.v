`timescale 1ns / 1ps

module uart_tx #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD     = 115200
)(
    input  wire       clk,
    input  wire       rst_n,

    input  wire [7:0] tx_data,
    input  wire       tx_start,

    output reg        txd,
    output reg        tx_busy,
    output reg        tx_done
);

    localparam integer BIT_CNT_MAX = CLK_FREQ / BAUD;

    reg [15:0] baud_cnt;
    reg [3:0]  bit_idx;
    reg [9:0]  tx_frame;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            txd      <= 1'b1;
            tx_busy  <= 1'b0;
            tx_done  <= 1'b0;
            baud_cnt <= 16'd0;
            bit_idx  <= 4'd0;
            tx_frame <= 10'b11_1111_1111;
        end else begin
            tx_done <= 1'b0;

            if (!tx_busy) begin
                baud_cnt <= 16'd0;
                bit_idx  <= 4'd0;

                if (tx_start) begin
                    tx_busy  <= 1'b1;
                    tx_frame <= {1'b1, tx_data, 1'b0};  // stop + data + start
                    txd      <= 1'b0;                   // start bit
                end else begin
                    txd <= 1'b1;                        // UART idle = high
                end

            end else begin
                if (baud_cnt == BIT_CNT_MAX - 1) begin
                    baud_cnt <= 16'd0;

                    if (bit_idx == 4'd9) begin
                        tx_busy <= 1'b0;
                        tx_done <= 1'b1;
                        txd     <= 1'b1;
                    end else begin
                        bit_idx <= bit_idx + 1'b1;
                        txd     <= tx_frame[bit_idx + 1'b1];
                    end

                end else begin
                    baud_cnt <= baud_cnt + 1'b1;
                end
            end
        end
    end

endmodule