#!/bin/bash

# Raspberry Pi Pico デプロイスクリプト
# 使用方法:
#   ./deploy.sh 101                    # USBモデム番号指定
#   ./deploy.sh /dev/tty.usbmodem101   # フルパス指定

set -e  # エラー時に終了

# 色付きメッセージ用
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Raspberry Pi Pico デプロイスクリプト${NC}"
echo "=========================================="

# 引数チェック
if [ $# -eq 0 ]; then
    echo -e "${RED}❌ エラー: USBモデム番号またはデバイスパスを指定してください${NC}"
    echo ""
    echo "使用方法:"
    echo "  $0 101                    # USBモデム番号指定"
    echo "  $0 /dev/tty.usbmodem101   # フルパス指定"
    echo ""
    echo "利用可能なUSBモデム:"
    ls /dev/tty.usbmodem* 2>/dev/null || echo "  なし"
    exit 1
fi

# デバイスパス決定
DEVICE_PATH="$1"
if [[ ! "$DEVICE_PATH" =~ ^/dev/ ]]; then
    # 番号のみが指定された場合はフルパスを構築
    DEVICE_PATH="/dev/tty.usbmodem$1"
fi

echo -e "${YELLOW}📱 ターゲットデバイス: ${DEVICE_PATH}${NC}"

# デバイス存在確認
if [ ! -e "$DEVICE_PATH" ]; then
    echo -e "${RED}❌ エラー: デバイス $DEVICE_PATH が見つかりません${NC}"
    echo ""
    echo "利用可能なUSBモデム:"
    ls /dev/tty.usbmodem* 2>/dev/null || echo "  なし"
    exit 1
fi

# 必要ファイル確認
if [ ! -f "main.py" ]; then
    echo -e "${RED}❌ エラー: main.py が見つかりません${NC}"
    echo "このスクリプトは assets/pico/ ディレクトリで実行してください"
    exit 1
fi

# rshell存在確認
if ! command -v rshell &> /dev/null; then
    echo -e "${RED}❌ エラー: rshell がインストールされていません${NC}"
    echo "インストール方法: pip install rshell"
    exit 1
fi

echo -e "${YELLOW}🔧 デプロイ開始...${NC}"

# 一時スクリプトファイル作成
TEMP_SCRIPT=$(mktemp)
cat > "$TEMP_SCRIPT" << 'EOF'
import sys
import time

print("📁 Picoファイルシステム確認...")
try:
    ls /pyboard
except:
    print("⚠️ Picoファイルシステムにアクセスできません")

print("📄 main.py を Pico にコピー中...")
cp main.py /pyboard/main.py

print("✅ ファイルコピー完了")
print("📁 Picoファイル一覧:")
ls /pyboard

print("\n🔄 Pico を再起動してプログラム実行...")
print("  ※ main.py が自動的に実行されます")
print("  ※ BLEアドバタイジングが開始されます")

repl
EOF

echo -e "${BLUE}🔗 rshell で Pico に接続中...${NC}"
echo -e "${YELLOW}注意: rshell内でCtrl+Dを押してPicoを再起動してください${NC}"

# rshell実行
rshell -p "$DEVICE_PATH" -f "$TEMP_SCRIPT"

# 一時ファイル削除
rm "$TEMP_SCRIPT"

echo ""
echo -e "${GREEN}🎉 デプロイ完了！${NC}"
echo ""
echo "次のステップ:"
echo -e "${BLUE}1.${NC} Picoで main.py が実行され、BLEアドバタイジングが開始されます"
echo -e "${BLUE}2.${NC} データ受信テスト: ${YELLOW}python central.py${NC}"
echo ""
echo "期待されるBLEデバイス名: ${YELLOW}PICO-BLE-TEMP-HS${NC}"
echo "サンプリングレート: ${YELLOW}1000Hz${NC}"

