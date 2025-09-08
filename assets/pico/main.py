import struct, time
from machine import ADC, Pin
import ubluetooth as bt

# ====== settings ======
NAME = "Pico"
SERVICE_UUID = bt.UUID("12345678-1234-5678-1234-56789ABCDEF0")
CHAR_UUID    = bt.UUID("12345678-1234-5678-1234-56789ABCDEF1")

SAMPLING_HZ = 1000    
SAMPLES_PER_PACKET = 10         
period_us = int(1_000_000 / SAMPLING_HZ)
NORMALIZE_DATA = True           

adc = ADC(Pin(26))       

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

# ====== main loop ======
seq = 0
buf = []                      
next_t = time.ticks_us()

while True:
    # 1) サンプル取得（1kHz）
    raw = adc.read_u16()       
    
    if NORMALIZE_DATA:
        normalized = raw / 65535.0
        buf.append(normalized)
    else:
        buf.append(raw)

    # 2) パケット満了でNotify
    if _CONN is not None and len(buf) >= SAMPLES_PER_PACKET:
        if NORMALIZE_DATA:
            payload = struct.pack("<H", seq) + struct.pack("<" + "f"*SAMPLES_PER_PACKET, *buf[:SAMPLES_PER_PACKET])
        else:
            payload = struct.pack("<H", seq) + struct.pack("<" + "H"*SAMPLES_PER_PACKET, *buf[:SAMPLES_PER_PACKET])
        
        ble.gatts_notify(_CONN, CHAR_HANDLE, payload)
        seq = (seq + 1) & 0xFFFF
        del buf[:SAMPLES_PER_PACKET]

    next_t = time.ticks_add(next_t, period_us)
    while time.ticks_diff(next_t, time.ticks_us()) > 0:
        pass
