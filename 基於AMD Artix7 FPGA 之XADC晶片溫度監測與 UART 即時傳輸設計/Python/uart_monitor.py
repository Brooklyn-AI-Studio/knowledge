import serial
import time
import re
from datetime import datetime

#  選擇你的 UART COM port
PORT = "COM5"

# Baud與FPGA一致
BAUD = 115200

# UART 讀取 timeout，單位:秒
TIMEOUT = 1


# ============================================================
# XADC 溫度換算函式
# ============================================================

def xadc_raw_to_celsius(raw16: int) -> float:
    """
    將 XADC raw 16-bit 溫度資料轉成攝氏溫度。

    XADC 溫度資料格式：
        do_out[15:4] 是有效 12-bit ADC code
        do_out[3:0] 通常為 0

    官方換算公式：
        Temperature = (ADC_Code * 503.975 / 4096) - 273.15

    例如：
        raw16 = 0x97A0
        adc_code = 0x97A = 2426
        temp ≈ 25.x °C
    """

    # 取出高 12-bit
    adc_code = raw16 >> 4

    # XADC 溫度轉換公式
    temp_c = (adc_code * 503.975 / 4096.0) - 273.15

    return temp_c


# ============================================================
# UART 封包解析函式
# ============================================================

def parse_fpga_line(line: str):
    """
    解析 FPGA 傳來的一行文字。

    預期格式：
        FPGA CNT=0x00000012 KEY=0 LED=1 TEMP=0x97A0

    回傳 dict：
        {
            "cnt": 18,
            "key": 0,
            "led": 1,
            "temp_raw": 0x97A0,
            "temp_c": 25.4
        }

    如果格式不符合，回傳 None。
    """

    # 用正規表示式抓取 CNT、KEY、LED、TEMP
    pattern = r"CNT=0x([0-9A-Fa-f]{8})\s+KEY=([01])\s+LED=([01])\s+TEMP=0x([0-9A-Fa-f]{4})"

    match = re.search(pattern, line)

    if not match:
        return None

    # 轉換資料型態
    cnt = int(match.group(1), 16)
    key = int(match.group(2))
    led = int(match.group(3))
    temp_raw = int(match.group(4), 16)

    # XADC raw data 轉攝氏溫度
    temp_c = xadc_raw_to_celsius(temp_raw)

    return {
        "cnt": cnt,
        "key": key,
        "led": led,
        "temp_raw": temp_raw,
        "temp_c": temp_c
    }


# ============================================================
# 主程式
# ============================================================

def main():
    print("==============================================")
    print(" UART FPGA Temperature Monitor")
    print("==============================================")
    print(f"Port : {PORT}")
    print(f"Baud : {BAUD}")
    print("Press Ctrl + C to stop.")
    print("==============================================")

    try:
        # 開啟 UART
        with serial.Serial(PORT, BAUD, timeout=TIMEOUT) as ser:

            # 等待 UART 穩定
            time.sleep(0.5)

            # 清空舊資料，避免一開始讀到殘留資料
            ser.reset_input_buffer()

            print("UART connected.")
            print()

            while True:
                # 從 UART 讀取一行資料
                # FPGA 端有送 \r\n，所以 readline() 可以讀一整行
                raw_line = ser.readline()

                # 如果 timeout 沒讀到資料，會回傳空 bytes
                if not raw_line:
                    continue

                # 將 bytes 轉成字串
                # errors="ignore" 可以避免偶發亂碼讓程式中斷
                line = raw_line.decode("utf-8", errors="ignore").strip()

                # 空行略過
                if not line:
                    continue

                # 解析 FPGA 資料
                data = parse_fpga_line(line)

                # 取得目前電腦時間
                now = datetime.now().strftime("%H:%M:%S")

                if data is None:
                    # 如果格式不符合，原樣印出，方便 debug
                    print(f"[{now}] RAW: {line}")
                else:
                    # 格式化顯示結果
                    print(
                        f"[{now}] "
                        f"CNT={data['cnt']:08d} | "
                        f"KEY={data['key']} | "
                        f"LED={data['led']} | "
                        f"TEMP_RAW=0x{data['temp_raw']:04X} | "
                        f"TEMP={data['temp_c']:.2f} °C"
                    )

    except serial.SerialException as e:
        print()
        print("UART 開啟失敗。")
        print("請檢查：")
        print("1. COM port 是否正確")
        print("2. 是否已安裝 CH340 驅動")
        print("3. 是否有其他程式正在佔用 UART")
        print("4. FPGA 是否已經燒錄完成")
        print()
        print(f"錯誤訊息：{e}")

    except KeyboardInterrupt:
        print()
        print("Monitor stopped.")


if __name__ == "__main__":
    main()