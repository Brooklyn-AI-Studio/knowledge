`timescale 1ns / 1ps

module xadc_temp_reader (
    input  wire        clk,
    input  wire        rst_n,

    output reg  [15:0] temp_raw,
    output reg         temp_valid
);

    wire [15:0] do_out;
    wire        drdy_out;
    wire        eoc_out;
    wire        eos_out;
    wire        busy_out;
    wire [4:0]  channel_out;
    wire [7:0]  alarm_out;

    /*
        XADC 溫度 register：
        daddr_in = 7'h00

        XADC Wizard 設定：
        Interface：DRP
        Mode：Continuous Mode
        Startup Channel：Single Channel
        Channel：Temperature
        DCLK Frequency：50 MHz
    */

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            temp_raw   <= 16'd0;
            temp_valid <= 1'b0;
        end else begin
            temp_valid <= 1'b0;

            if (drdy_out) begin
                temp_raw   <= do_out;
                temp_valid <= 1'b1;
            end
        end
    end

    xadc_wiz_1 u_xadc_wiz_1 (
        .dclk_in     (clk),
        .reset_in    (~rst_n),

        .di_in       (16'h0000),
        .daddr_in    (7'h00),      // 0x00 = FPGA internal temperature
        .den_in      (eoc_out),    // 每次轉換結束後讀一次
        .dwe_in      (1'b0),

        .do_out      (do_out),
        .drdy_out    (drdy_out),

        .busy_out    (busy_out),
        .channel_out (channel_out),
        .eoc_out     (eoc_out),
        .eos_out     (eos_out),
        .alarm_out   (alarm_out),

        .vp_in       (1'b0),
        .vn_in       (1'b0)
    );

endmodule