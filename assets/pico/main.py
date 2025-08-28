# Pico W: 内蔵温度センサー(ADC4)を 1kHz でサンプルし、9サンプルずつ BLE Notify
# ★ 将来は analog pin (例: GPIO26/ADC0) に切り替える想定のコメントあり

import struct, time
from machine import ADC, Pin
import ubluetooth as bt

# ====== 設定 ======
NAME = "PICO-BLE-TEMP-HS"
SERVICE_UUID = bt.UUID("12345678-1234-5678-1234-56789ABCDEF0")
CHAR_UUID    = bt.UUID("12345678-1234-5678-1234-56789ABCDEF1")

SAMPLING_HZ = 1000               # サンプリング周波数（1kHz）
SAMPLES_PER_PACKET = 9           # 1通知あたりのサンプル数（seq2B + 9*2B = 20B）
period_us = int(1_000_000 / SAMPLING_HZ)

# ====== ADC ======
adc = ADC(4)                     # 内蔵温度センサー
# ★ 将来: 外部アナログに切り替える場合
# adc = ADC(Pin(26))             # 例: GPIO26 = ADC0

# ====== BLE ======
ble = bt.BLE(); ble.active(True)
CHAR = (CHAR_UUID, bt.FLAG_NOTIFY)
SERVICE = (SERVICE_UUID, (CHAR,))
((CHAR_HANDLE,),) = ble.gatts_register_services((SERVICE,))

_CONN = None
_IRQ_CENTRAL_CONNECT, _IRQ_CENTRAL_DISCONNECT = 1, 2

def _irq(event, data):
    global _CONN
    if event == _IRQ_CENTRAL_CONNECT:
        _CONN, _, _ = data
    elif event == _IRQ_CENTRAL_DISCONNECT:
        _CONN = None
        advertise()

ble.irq(_irq)

def adv_payload(name, services=None):
    p = bytearray()
    nb = name.encode(); p += bytearray([len(nb)+1, 0x09]) + nb
    if services:
        for s in services:
            u = bytes(s); p += bytearray([len(u)+1, 0x07]) + u
    return p

def advertise():
    ble.gap_advertise(None)
    ble.gap_advertise(100_000, adv_payload(NAME, [SERVICE_UUID]))

advertise()

# ====== 高速サンプリング & 送信 ======
seq = 0
buf = []                         # uint16 の配列（ADC生値 0..65535）
next_t = time.ticks_us()

while True:
    # 1) サンプル取得（1kHz）
    raw = adc.read_u16()         # 0..65535（12bit相当が上位に格納）
    buf.append(raw)

    # 2) パケット満了でNotify（seq + 9サンプル = 20B）
    if _CONN is not None and len(buf) >= SAMPLES_PER_PACKET:
        payload = struct.pack("<H", seq) + struct.pack("<" + "H"*SAMPLES_PER_PACKET, *buf[:SAMPLES_PER_PACKET])
        ble.gatts_notify(_CONN, CHAR_HANDLE, payload)
        seq = (seq + 1) & 0xFFFF
        del buf[:SAMPLES_PER_PACKET]

    # 3) 1kHzタイミング維持
    next_t = time.ticks_add(next_t, period_us)
    while time.ticks_diff(next_t, time.ticks_us()) > 0:
        pass
