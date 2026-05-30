`timescale 1ns / 1ps

module tb_top_uart_temp_monitor;

    reg CLK_50M;
    reg rst_n;
    reg key_in;

    wire rs232_tx;
    wire led;

    // 50MHz clock，週期 20ns
    always #10 CLK_50M = ~CLK_50M;

    top_uart_temp_monitor #(
        .CLK_FREQ    (50_000_000),

        // 模擬加速，避免 UART 115200 等太久
        .BAUD        (1_000_000),

        // 模擬加速，每 1000 個 clock 送一包
        .SEND_PERIOD (1000)
    ) dut (
        .CLK_50M  (CLK_50M),
        .rst_n    (rst_n),
        .key_in   (key_in),
        .rs232_tx (rs232_tx),
        .led      (led)
    );

    initial begin
        CLK_50M = 1'b0;
        rst_n   = 1'b0;
        key_in  = 1'b1;   // 未按下

        #200;
        rst_n = 1'b1;

        // 模擬按鍵按下
        #20000;
        key_in = 1'b0;
        #50000;
        key_in = 1'b1;

        // 再按一次
        #100000;
        key_in = 1'b0;
        #30000;
        key_in = 1'b1;

        // 繼續跑
        #2000000;

        $stop;
    end

endmodule