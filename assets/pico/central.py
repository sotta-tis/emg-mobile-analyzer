import asyncio
from bleak import BleakScanner, BleakClient

SERVICE_UUID = "12345678-1234-5678-1234-56789abcdef0"
CHAR_UUID = "12345678-1234-5678-1234-56789abcdef1"

async def run():
    print("🔍 BLEスキャン中...")
    devices = await BleakScanner.discover()

    target = None
    for d in devices:
        name = d.name or "(No name)"
        print(f"見つけたデバイス: {name} ({d.address})")
        if "Pico" in (d.name or ""):
            target = d
            break

    if not target:
        print("❌ 'Pico' という名前のデバイスが見つかりません")
        return

    print(f"✅ 接続中: {target.name} ({target.address})")
    async with BleakClient(target.address) as client:
        def handle_notify(sender, data):
            temp_raw = int.from_bytes(data, byteorder="little")
            temp_c = temp_raw / 100.0
            print(f"🌡️ 温度: {temp_c:.2f} °C")

        await client.start_notify(CHAR_UUID, handle_notify)
        print("📡 Notify受信中...（Ctrl+Cで終了）")

        try:
            while True:
                await asyncio.sleep(1)
        except KeyboardInterrupt:
            print("\n🛑 終了します")
            await client.stop_notify(CHAR_UUID)

asyncio.run(run())
