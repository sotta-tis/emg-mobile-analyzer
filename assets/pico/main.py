import bluetooth
from machine import ADC, Pin
from utime import sleep_us

# LEDとBLE初期化
led = Pin("LED", Pin.OUT)
led.on()

ble = bluetooth.BLE()
ble.active(True)

SERVICE_UUID = bluetooth.UUID("12345678-1234-5678-1234-56789abcdef0")
CHAR_UUID = bluetooth.UUID("12345678-1234-5678-1234-56789abcdef1")

adc = ADC(Pin(26))  # EMGセンサ

# BLEサービス登録
((char_handle,),) = ble.gatts_register_services((
    (SERVICE_UUID, ((CHAR_UUID, bluetooth.FLAG_NOTIFY),)),
))

# アドバタイズ名
name = b'PicoEMG'
adv_data = bytearray(b'\x02\x01\x06') + bytearray((len(name) + 1, 0x09)) + name

conn_handle = None

# 接続/切断イベント
def on_bt_irq(event, data):
    global conn_handle
    if event == 1:
        conn_handle = data[0]
        print("🔗 connected:", conn_handle)
        led.on()
    elif event == 2:
        print("❌ disconnected")
        conn_handle = None
        led.off()

ble.irq(on_bt_irq)
ble.gap_advertise(100_000, adv_data)

# メインループ：10サンプルをまとめて送信（20バイト）
while True:
    if conn_handle is not None:
        buf = bytearray(20)  # 2バイト×10サンプル
        for i in range(10):
            emg = adc.read_u16()
            buf[i * 2]     = emg & 0xFF
            buf[i * 2 + 1] = emg >> 8
            # ADCは高速なのでsleep不要（必要なら sleep_us(100)）
        ble.gatts_notify(conn_handle, char_handle, buf)
    sleep_us(20000)  # ≒ 50Hz送信、10サンプル/回 → 実効500Hz相当
