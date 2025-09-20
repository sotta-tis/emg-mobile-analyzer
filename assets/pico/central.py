import asyncio
import struct
import time
import numpy as np
from bleak import BleakScanner, BleakClient

SERVICE_UUID = "12345678-1234-5678-1234-56789abcdef0"
CHAR_UUID = "12345678-1234-5678-1234-56789abcdef1"
TARGET_NAME = "Pico"  # 実際のデバイス名

# main.pyの設定に合わせる
SAMPLING_HZ = 1000
SAMPLES_PER_PACKET = 10
NORMALIZE_DATA = True            # main.pyのNORMALIZE_DATAと合わせる

async def run():
    print("🔍 BLEスキャン中...")
    devices = await BleakScanner.discover()

    target = None
    for d in devices:
        name = d.name or "(No name)"
        print(f"見つけたデバイス: {name} ({d.address})")
        if TARGET_NAME in (d.name or ""):
            target = d
            break

    if not target:
        print(f"❌ '{TARGET_NAME}' という名前のデバイスが見つかりません")
        print("利用可能なデバイス:")
        for d in devices:
            print(f"  - {d.name or '(No name)'} ({d.address})")
        return

    print(f"✅ 接続中: {target.name} ({target.address})")
    
    # 統計情報
    packet_count = 0
    sample_count = 0
    last_seq = None
    start_time = time.time()
    
    # データ収集用バッファ
    all_samples = []
    
    async with BleakClient(target.address) as client:
        # サービス確認
        print("🔍 利用可能なサービス:")
        for service in client.services:
            print(f"  📋 Service: {service.uuid}")
            for char in service.characteristics:
                props = ", ".join(char.properties)
                print(f"    📝 Char: {char.uuid} ({props})")
        
        # 目的のサービス/キャラクタリスティックの存在確認
        target_service = None
        target_char = None
        for service in client.services:
            if service.uuid.lower() == SERVICE_UUID.lower():
                target_service = service
                for char in service.characteristics:
                    if char.uuid.lower() == CHAR_UUID.lower():
                        target_char = char
                        break
                break
        
        if not target_service:
            print(f"❌ 目的のサービス {SERVICE_UUID} が見つかりません")
            return
        if not target_char:
            print(f"❌ 目的のキャラクタリスティック {CHAR_UUID} が見つかりません")
            return
        
        print(f"✅ 目的のサービス/キャラクタリスティックを確認")
        def handle_notify(sender, data):
            nonlocal packet_count, sample_count, last_seq, start_time, all_samples
            
            if NORMALIZE_DATA:
                expected_size = 2 + (SAMPLES_PER_PACKET * 4)  # seq(2B) + 9floats(4B each) = 38B
                if len(data) != expected_size:
                    print(f"⚠️ 予期しないデータサイズ: {len(data)} bytes (期待値: {expected_size})")
                    return
                
                # データをアンパック: seq(uint16) + 9個のsamples(float32)
                seq = struct.unpack("<H", data[:2])[0]
                samples = struct.unpack("<" + "f" * SAMPLES_PER_PACKET, data[2:])
            else:
                expected_size = 2 + (SAMPLES_PER_PACKET * 2)  # seq(2B) + 9samples(2B each) = 20B
                if len(data) != expected_size:
                    print(f"⚠️ 予期しないデータサイズ: {len(data)} bytes (期待値: {expected_size})")
                    return
                
                # データをアンパック: seq(uint16) + 9個のsamples(uint16)
                values = struct.unpack("<" + "H" * (1 + SAMPLES_PER_PACKET), data)
                seq = values[0]
                samples = values[1:]
            
            # 統計更新
            packet_count += 1
            sample_count += len(samples)
            elapsed = time.time() - start_time
            packet_rate = packet_count / elapsed if elapsed > 0 else 0
            sample_rate = sample_count / elapsed if elapsed > 0 else 0
            
            # サンプルをバッファに追加
            all_samples.extend(samples)
            
            # シーケンス番号の連続性チェック
            seq_info = ""
            if last_seq is not None:
                expected = (last_seq + 1) & 0xFFFF
                if seq != expected:
                    seq_info = f" (⚠️ 欠損: {last_seq} → {seq})"
            last_seq = seq
            
            # サンプル値の統計
            min_val, max_val, avg_val = min(samples), max(samples), sum(samples) / len(samples)
            
            if NORMALIZE_DATA:
                print(f"📊 Seq:{seq:5d} | Samples: {len(samples)} | "
                      f"Min:{min_val:.4f} Max:{max_val:.4f} Avg:{avg_val:.4f} | "
                      f"PKT:{packet_rate:5.1f}Hz SPL:{sample_rate:7.0f}Hz{seq_info}")
            else:
                print(f"📊 Seq:{seq:5d} | Samples: {len(samples)} | "
                      f"Min:{min_val:5d} Max:{max_val:5d} Avg:{avg_val:7.1f} | "
                      f"PKT:{packet_rate:5.1f}Hz SPL:{sample_rate:7.0f}Hz{seq_info}")

        await client.start_notify(CHAR_UUID, handle_notify)
        print("📡 高速ADCデータ受信中...（Ctrl+Cで終了）")
        data_type = "正規化データ(0.0-1.0)" if NORMALIZE_DATA else "生データ(0-65535)"
        print(f"⚙️  設定: {SAMPLING_HZ}Hz サンプリング, {SAMPLES_PER_PACKET}サンプル/パケット, {data_type}")
        print("=" * 100)

        try:
            while True:
                await asyncio.sleep(1)
        except KeyboardInterrupt:
            print("\n🛑 終了します")
            elapsed = time.time() - start_time
            print(f"📈 統計:")
            print(f"   パケット: {packet_count} 個, 平均レート: {packet_count/elapsed:.1f}Hz")
            print(f"   サンプル: {sample_count} 個, 平均レート: {sample_count/elapsed:.0f}Hz")
            if all_samples:
                if NORMALIZE_DATA:
                    print(f"   正規化値: Min={min(all_samples):.4f}, Max={max(all_samples):.4f}, Avg={sum(all_samples)/len(all_samples):.4f}")
                else:
                    print(f"   ADC値: Min={min(all_samples)}, Max={max(all_samples)}, Avg={sum(all_samples)/len(all_samples):.1f}")
            await client.stop_notify(CHAR_UUID)

if __name__ == "__main__":
    asyncio.run(run())
