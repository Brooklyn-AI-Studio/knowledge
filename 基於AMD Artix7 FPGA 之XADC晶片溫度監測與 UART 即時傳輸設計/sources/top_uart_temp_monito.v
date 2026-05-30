`timescale 1ns / 1ps

module top_uart_temp_monitor #(
    parameter CLK_FREQ    = 50_000_000,
    parameter BAUD        = 115200,
    parameter SEND_PERIOD = 5_000_000      // 50MHz 下約 0.1 秒送一次
)(
    input  wire CLK_50M,
    input  wire rst_n,
    input  wire key_in,

    output wire rs232_tx,
    output wire led
);

    // ============================================================
    // Key sync
    // ============================================================

    reg key_ff1;
    reg key_ff2;

    always @(posedge CLK_50M or negedge rst_n) begin
        if (!rst_n) begin
            key_ff1 <= 1'b1;
            key_ff2 <= 1'b1;
        end else begin
            key_ff1 <= key_in;
            key_ff2 <= key_ff1;
        end
    end

    // 假設按鍵按下為低電平
    wire key_pressed = ~key_ff2;

    // ============================================================
    // LED heartbeat
    // A7-LITE LED 通常低電平亮，所以 led = ~led_state
    // ============================================================

    reg led_state;
    assign led = ~led_state;

    // ============================================================
    // XADC temperature reader
    // ============================================================

    wire [15:0] temp_raw;
    wire        temp_valid;

    xadc_temp_reader u_xadc_temp_reader (
        .clk        (CLK_50M),
        .rst_n      (rst_n),
        .temp_raw   (temp_raw),
        .temp_valid (temp_valid)
    );

    // ============================================================
    // UART TX
    // ============================================================

    reg  [7:0] tx_data;
    reg        tx_start;
    wire       tx_busy;
    wire       tx_done;

    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD    (BAUD)
    ) u_uart_tx (
        .clk      (CLK_50M),
        .rst_n    (rst_n),
        .tx_data  (tx_data),
        .tx_start (tx_start),
        .txd      (rs232_tx),
        .tx_busy  (tx_busy),
        .tx_done  (tx_done)
    );

    // ============================================================
    // Monitor packet
    //
    // Format:
    // FPGA CNT=0x00000000 KEY=0 LED=0 TEMP=0x0000
    //
    // ============================================================

    localparam integer PACKET_LEN = 45;

    reg [31:0] timer_cnt;
    reg [31:0] packet_cnt;

    reg [31:0] snap_cnt;
    reg        snap_key;
    reg        snap_led;
    reg [15:0] snap_temp;

    reg        sending;
    reg [5:0]  byte_idx;

    function [7:0] hex_ascii;
        input [3:0] value;
        begin
            if (value < 4'd10)
                hex_ascii = 8'h30 + value;              // 0~9
            else
                hex_ascii = 8'h41 + (value - 4'd10);    // A~F
        end
    endfunction

    function [7:0] packet_byte;
        input [5:0] idx;
        begin
            case (idx)
                6'd0:  packet_byte = "F";
                6'd1:  packet_byte = "P";
                6'd2:  packet_byte = "G";
                6'd3:  packet_byte = "A";
                6'd4:  packet_byte = " ";
                6'd5:  packet_byte = "C";
                6'd6:  packet_byte = "N";
                6'd7:  packet_byte = "T";
                6'd8:  packet_byte = "=";
                6'd9:  packet_byte = "0";
                6'd10: packet_byte = "x";

                6'd11: packet_byte = hex_ascii(snap_cnt[31:28]);
                6'd12: packet_byte = hex_ascii(snap_cnt[27:24]);
                6'd13: packet_byte = hex_ascii(snap_cnt[23:20]);
                6'd14: packet_byte = hex_ascii(snap_cnt[19:16]);
                6'd15: packet_byte = hex_ascii(snap_cnt[15:12]);
                6'd16: packet_byte = hex_ascii(snap_cnt[11:8]);
                6'd17: packet_byte = hex_ascii(snap_cnt[7:4]);
                6'd18: packet_byte = hex_ascii(snap_cnt[3:0]);

                6'd19: packet_byte = " ";
                6'd20: packet_byte = "K";
                6'd21: packet_byte = "E";
                6'd22: packet_byte = "Y";
                6'd23: packet_byte = "=";
                6'd24: packet_byte = snap_key ? "1" : "0";

                6'd25: packet_byte = " ";
                6'd26: packet_byte = "L";
                6'd27: packet_byte = "E";
                6'd28: packet_byte = "D";
                6'd29: packet_byte = "=";
                6'd30: packet_byte = snap_led ? "1" : "0";

                6'd31: packet_byte = " ";
                6'd32: packet_byte = "T";
                6'd33: packet_byte = "E";
                6'd34: packet_byte = "M";
                6'd35: packet_byte = "P";
                6'd36: packet_byte = "=";
                6'd37: packet_byte = "0";
                6'd38: packet_byte = "x";

                6'd39: packet_byte = hex_ascii(snap_temp[15:12]);
                6'd40: packet_byte = hex_ascii(snap_temp[11:8]);
                6'd41: packet_byte = hex_ascii(snap_temp[7:4]);
                6'd42: packet_byte = hex_ascii(snap_temp[3:0]);

                6'd43: packet_byte = 8'h0D;    // \r
                6'd44: packet_byte = 8'h0A;    // \n

                default: packet_byte = 8'h20;
            endcase
        end
    endfunction

    always @(posedge CLK_50M or negedge rst_n) begin
        if (!rst_n) begin
            timer_cnt  <= 32'd0;
            packet_cnt <= 32'd0;

            led_state  <= 1'b0;

            snap_cnt   <= 32'd0;
            snap_key   <= 1'b0;
            snap_led   <= 1'b0;
            snap_temp  <= 16'd0;

            sending    <= 1'b0;
            byte_idx   <= 6'd0;

            tx_data    <= 8'd0;
            tx_start   <= 1'b0;
        end else begin
            tx_start <= 1'b0;

            if (!sending) begin
                if (timer_cnt == SEND_PERIOD - 1) begin
                    timer_cnt <= 32'd0;

                    snap_cnt  <= packet_cnt;
                    snap_key  <= key_pressed;
                    snap_led  <= led_state;
                    snap_temp <= temp_raw;

                    packet_cnt <= packet_cnt + 1'b1;
                    led_state  <= ~led_state;

                    sending  <= 1'b1;
                    byte_idx <= 6'd0;
                end else begin
                    timer_cnt <= timer_cnt + 1'b1;
                end
            end else begin
                if (!tx_busy && !tx_start) begin
                    tx_data  <= packet_byte(byte_idx);
                    tx_start <= 1'b1;

                    if (byte_idx == PACKET_LEN - 1) begin
                        sending <= 1'b0;
                    end else begin
                        byte_idx <= byte_idx + 1'b1;
                    end
                end
            end
        end
    end

endmodule