# Raspberry Pi Pico 2 W　のペリフェラルデバイス化設定

## 概要
Raspberry Pi Pico W を使用して、**1kHz高速サンプリング**でADCデータをBLE (Bluetooth Low Energy) で送信するプロジェクトです。

## ファイル構成
```
pico/
├── main.py      # Pico 2 W 用 BLE Peripheral 実装（テスト動作として温度をNotify）
├── central.py   # PC 用 BLE Central 実装（温度を受信）
└── README.md    
```
 `pico/` 配下でRaspberry Pi Pico 2 W を Peripheral（周辺機器）としてBLE通知を行うプログラムとテスト、開発環境用プログラムを管理。
- `main.py`: (Peliferal) Pico W 側のメインプログラム
- `central.py`: PC 側の受信プログラム テスト用
- `deploy.sh`: Picoへのデプロイ用シェルスクリプト
- `README.md`: このファイル

---

## 依存環境

### Pico W 側
- Raspberry Pi Pico W
- MicroPython (BLE 対応版)
- USB接続（rshell用）

### PC 側
- Python 3.7+
- bleak ライブラリ
- rshell（Picoファイル管理用）

## セットアップ

### 1. PC 側の準備
```bash
pip install bleak rshell
```

### 2. USBポート確認
```bash
ls /dev/tty.usbmodem*
# 例: /dev/tty.usbmodem101
```

### 3. 簡単デプロイ（推奨）
```bash
# USBモデム番号を指定してワンコマンドデプロイ
./deploy.sh 101

# または手動でポート指定
./deploy.sh /dev/tty.usbmodem101
```

### 4. 手動デプロイ（上級者向け）
```bash
# rshellで接続
rshell -p /dev/tty.usbmodem101

# rshell内でファイル転送
cp main.py /pyboard/main.py

# REPL起動
repl

# Picoでソフトリブート（main.py自動実行）
# Ctrl+D

# REPLから抜ける
# Ctrl+X
```

## 実行方法

### 1. Pico側でサンプリング開始
デプロイ後、Picoが自動的に以下を開始：
- 1kHzでADCサンプリング
- BLEアドバタイジング（デバイス名：`PICO-BLE-TEMP-HS`）
- 9サンプルずつパケット送信

### 2. PC側でデータ受信
```bash
python central.py
```


## 設定

### BLE 設定
- **Service UUID**: `12345678-1234-5678-1234-56789ABCDEF0`
- **Characteristic UUID**: `12345678-1234-5678-1234-56789ABCDEF1`
- **デバイス名**: `PICO-BLE-TEMP-HS`

### サンプリング設定
- **サンプリング周波数**: 1000Hz
- **パケットサイズ**: 20バイト（seq 2B + 9サンプル × 2B）
- **パケット送信レート**: ~111Hz（1000Hz ÷ 9サンプル）

### データフォーマット
各パケット（20バイト）の構成：
```
[0:2]   seq (uint16)        : シーケンス番号
[2:4]   sample1 (uint16)    : ADC生値 0-65535
[4:6]   sample2 (uint16)    : ADC生値 0-65535
...
[18:20] sample9 (uint16)    : ADC生値 0-65535
```

### アナログピン変更
```python
# 内蔵温度センサー（デフォルト）
adc = ADC(4)

# 外部アナログピン（例：GPIO26/ADC0）
adc = ADC(Pin(26))
```

### rshell接続エラー
```bash
# ポート権限エラー
sudo chmod 666 /dev/tty.usbmodem101

# ポートビジーエラー（他のプロセスが使用中）
sudo lsof /dev/tty.usbmodem101
# 該当プロセスを終了後に再試行
```
