# BLE通信、温度センサ、LED制御に必要なモジュールをインポート
import bluetooth
from machine import ADC, Pin
from utime import sleep_ms

# Pico Wの内蔵LEDを初期化してONに（動作確認用）
led = Pin("LED", Pin.OUT)
led.on()

# BLEインスタンスを作成して有効化
ble = bluetooth.BLE()
ble.active(True)

# BLEのサービスUUID（温度サービス）とキャラクタUUID（温度値）を定義
TEMP_SERVICE_UUID = bluetooth.UUID("12345678-1234-5678-1234-56789abcdef0")
TEMP_CHAR_UUID = bluetooth.UUID("12345678-1234-5678-1234-56789abcdef1")

# 内部温度センサの初期化
temp_adc = ADC(4)           # ADCチャンネル4はRP2040内部温度センサ
conv = 3.3 / 65535          # ADC値を電圧に変換する係数

# 温度を0.01℃単位の整数で返す関数（例：25.34℃ → 2534）
def read_temp():
    volts = temp_adc.read_u16() * conv
    return int((27 - (volts - 0.706) / 0.001721) * 100)

# GATTサービス・キャラクタリスティックを登録し、ハンドルを取得
((temp_handle,),) = ble.gatts_register_services((
    (TEMP_SERVICE_UUID, ((TEMP_CHAR_UUID, bluetooth.FLAG_NOTIFY),)),
))

# アドバタイズデータ（スキャン時に見えるデバイス名）を作成
name = b'PicoTemp'
adv_data = bytearray(b'\x02\x01\x06')                   # 一般発見可能 + BLEのみサポート
adv_data += bytearray((len(name) + 1, 0x09))            # 完全なローカルネーム
adv_data += name                                        # デバイス名 "PicoTemp"

# BLE接続ハンドル（接続先Centralを識別する番号）を格納する変数
conn_handle = None

# BLEイベント（接続・切断）に応じてコネクションハンドルを設定
def on_bt_irq(event, data):
    global conn_handle
    if event == 1:  # Central（スマホ/PC）から接続された
        conn_handle = data[0]     # 接続相手のハンドルを記録
        print("🔗 connected:", conn_handle)
        led.on()                  # LED ON（接続中表示）
    elif event == 2:  # 切断された
        print("❌ disconnected")
        conn_handle = None        # ハンドルをリセット
        led.off()                 # LED OFF（切断表示）

# BLEのIRQハンドラを登録
ble.irq(on_bt_irq)

# アドバタイズ（広告）開始：デバイス名 "PicoTemp" を周囲に通知
ble.gap_advertise(100_000, adv_data)  # 広告間隔は100ms

# メインループ：接続中のみ温度を1秒ごとにNotifyで送信
while True:
    if conn_handle is not None:
        temp = read_temp().to_bytes(2, "little")             # 温度を2バイトリトルエンディアンでエンコード
        ble.gatts_notify(conn_handle, temp_handle, temp)     # 通知送信
    sleep_ms(1000)
