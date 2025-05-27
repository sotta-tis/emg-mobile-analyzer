# Raspberry Pi Pico 2 W　のペリフェラルデバイス化設定

このディレクトリ `pico/` には、Raspberry Pi Pico 2 W を Peripheral（周辺機器）としてBLE通知を行う `main.py` と、それをPC上で受信・確認する `central.py` を含みます。

##  構成

```
pico/
├── main.py      # Pico 2 W 用 BLE Peripheral 実装（テスト動作として温度をNotify）
├── central.py   # PC 用 BLE Central 実装（温度を受信）
└── README.md    
```

---

## 🛠️ 必要環境

* Raspberry Pi Pico 2 W
* MicroPython（BLE対応版）
* rshell（Picoへファイル送信用）
* Python 3.x（PC側のcentral用）
* bleak パッケージ（pipでインストール）

---

## ⚙️ Pico 2 W のセットアップ手順

テスト動作のためMicroPythonを選定。必要になればC++への変更も検討。

### 1. MicroPythonファームウェア（BLE対応）を Pico に書き込む

1. [公式MicroPythonダウンロードページ](https://micropython.org/download/RPI_PICO2_W/) から `v1.25.0 (2025-04-15) .uf2 ` をダウンロード
2. Pico 2 W の BOOTSEL ボタンを押しながら USB 接続し、`RPI-RP2` ドライブを表示
3. ダウンロードした `.uf2` ファイルを `RPI-RP2` にドラッグ＆ドロップ
4. 自動的に再起動して MicroPython が起動すれば完了。下記で認証確認できればok。
```bash
ls /dev/tty.usbmodem*
```


---

### 2. rshell による接続とデプロイ

#### rshell インストール

```bash
pip install rshell
```

#### Pico のデバイスパス確認（macOSの例）

```bash
ls /dev/tty.usbmodem*
```

（例：`/dev/tty.usbmodem1101`）

#### rshell 接続

```bash

rshell -p /dev/tty.usbmodem1101 #環境に合わせてtty.usbmodem**以降は要変更
```

#### main.py を Pico にコピー

```bash
cp main.py /pyboard/
```

#### Pico 再起動

Pico を USB 抜き差しすると、 `/pyboard/main.py` が自動的に実行され、BLEアドバタイズが開始されます。

---

## 📝 BLE通信の動作確認（PC側）

### Python側に必要なライブラリのインストール

```bash
pip install bleak
```

### `central.py` 実行

```bash
python central.py
```

BLEスキャン → `PicoTemp` 接続 → Notify受信 → 温度をCLIに表示 という流れになります。

---