#!/usr/bin/env python3
"""
EMGデータセッションのCSVファイル表示スクリプト
manifest.jsonを読み込み、指定されたCSVファイルを表示する
"""

import json
import pandas as pd
import os
import sys
from pathlib import Path
import matplotlib.pyplot as plt
import argparse


def load_manifest(manifest_path):
    """manifest.jsonを読み込む"""
    try:
        with open(manifest_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"エラー: manifest.jsonが見つかりません: {manifest_path}")
        return None
    except json.JSONDecodeError:
        print(f"エラー: manifest.jsonの形式が正しくありません: {manifest_path}")
        return None


def list_csv_files(session_dir):
    """samplesディレクトリ内のCSVファイル一覧を表示"""
    samples_dir = os.path.join(session_dir, 'samples')
    if not os.path.exists(samples_dir):
        print(f"エラー: samplesディレクトリが見つかりません: {samples_dir}")
        return []
    
    csv_files = [f for f in os.listdir(samples_dir) if f.endswith('.csv')]
    csv_files.sort()
    
    print("\n利用可能なCSVファイル:")
    for i, filename in enumerate(csv_files, 1):
        # ファイル名からラベルを抽出
        parts = filename.split('_')
        if len(parts) >= 3:
            label = parts[1]
            sample_num = parts[2].split('.')[0]
            print(f"  {i}: {filename} (ラベル: {label}, サンプル番号: {sample_num})")
        else:
            print(f"  {i}: {filename}")
    
    return csv_files


def display_csv_info(csv_path, manifest_data):
    """CSVファイルの基本情報を表示"""
    if not os.path.exists(csv_path):
        print(f"エラー: CSVファイルが見つかりません: {csv_path}")
        return None
    
    try:
        df = pd.read_csv(csv_path)
        filename = os.path.basename(csv_path)
        
        # ファイル名からラベルとサンプル番号を抽出
        parts = filename.split('_')
        label = parts[1] if len(parts) >= 3 else "不明"
        sample_num = parts[2].split('.')[0] if len(parts) >= 3 else "不明"
        
        print(f"\n=== CSVファイル情報: {filename} ===")
        print(f"ラベル: {label}")
        print(f"サンプル番号: {sample_num}")
        print(f"ファイルサイズ: {os.path.getsize(csv_path):,} bytes")
        print(f"データ行数: {len(df):,}")
        print(f"カラム: {list(df.columns)}")
        
        if manifest_data:
            print(f"サンプリングレート: {manifest_data['sampling']['sample_rate_hz']} Hz")
            print(f"パケットあたりサンプル数: {manifest_data['sampling']['samples_per_packet']}")
            print(f"サンプル持続時間: {manifest_data['sample_duration_ms']} ms")
            expected_samples = manifest_data['sample_duration_ms'] * manifest_data['sampling']['sample_rate_hz'] / 1000
            print(f"期待データポイント数: {expected_samples:,.0f}")
        
        # 統計情報
        print(f"\n=== 統計情報 ===")
        print(f"時間範囲: {df['t_ms_packet'].min()} - {df['t_ms_packet'].max()}")
        duration_ms = df['t_ms_packet'].max() - df['t_ms_packet'].min()
        print(f"記録時間: {duration_ms:,} ms ({duration_ms/1000:.3f} 秒)")
        print(f"パケットシーケンス範囲: {df['seq_packet'].min()} - {df['seq_packet'].max()}")
        print(f"サンプルインデックス範囲: {df['sample_idx'].min()} - {df['sample_idx'].max()}")
        print(f"正規化値範囲: {df['value_norm'].min():.6f} - {df['value_norm'].max():.6f}")
        print(f"正規化値平均: {df['value_norm'].mean():.6f}")
        print(f"正規化値標準偏差: {df['value_norm'].std():.6f}")
        print(f"正規化値中央値: {df['value_norm'].median():.6f}")
        
        # パケット解析
        unique_packets = df['seq_packet'].nunique()
        samples_per_unique_packet = len(df) / unique_packets if unique_packets > 0 else 0
        print(f"\n=== パケット解析 ===")
        print(f"ユニークパケット数: {unique_packets}")
        print(f"パケットあたり平均サンプル数: {samples_per_unique_packet:.1f}")
        
        return df
        
    except Exception as e:
        print(f"エラー: CSVファイルの読み込みに失敗しました: {e}")
        return None


def display_csv_data(df, head_lines=10, tail_lines=10):
    """CSVデータの先頭と末尾を表示"""
    print(f"\n=== データ先頭 {head_lines} 行 ===")
    print(df.head(head_lines).to_string(index=True))
    
    if len(df) > head_lines + tail_lines:
        print(f"\n=== データ末尾 {tail_lines} 行 ===")
        print(df.tail(tail_lines).to_string(index=True))


def plot_csv_data(df, filename):
    """EMGデータをプロット"""
    plt.figure(figsize=(15, 8))
    
    # サンプリング時間を計算（相対時間）
    start_time = df['t_ms_packet'].min()
    relative_time = (df['t_ms_packet'] - start_time) / 1000.0  # 秒に変換
    
    # メインプロット
    plt.subplot(2, 1, 1)
    plt.plot(relative_time, df['value_norm'], linewidth=0.5, alpha=0.8)
    plt.title(f'EMG Data: {filename}')
    plt.xlabel('Time (seconds)')
    plt.ylabel('Normalized Value')
    plt.grid(True, alpha=0.3)
    
    # 統計情報をプロット上に表示
    mean_val = df['value_norm'].mean()
    std_val = df['value_norm'].std()
    plt.axhline(y=mean_val, color='red', linestyle='--', alpha=0.7, label=f'Mean: {mean_val:.3f}')
    plt.axhline(y=mean_val + std_val, color='orange', linestyle=':', alpha=0.7, label=f'+1σ: {mean_val + std_val:.3f}')
    plt.axhline(y=mean_val - std_val, color='orange', linestyle=':', alpha=0.7, label=f'-1σ: {mean_val - std_val:.3f}')
    plt.legend()
    
    # ヒストグラム
    plt.subplot(2, 1, 2)
    plt.hist(df['value_norm'], bins=50, alpha=0.7, edgecolor='black')
    plt.title('Value Distribution')
    plt.xlabel('Normalized Value')
    plt.ylabel('Frequency')
    plt.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.show()


def analyze_packets(df):
    """パケット解析を実行"""
    print(f"\n=== 詳細パケット解析 ===")
    
    # パケットごとの統計
    packet_stats = df.groupby('seq_packet').agg({
        'sample_idx': ['min', 'max', 'count'],
        'value_norm': ['mean', 'std', 'min', 'max'],
        't_ms_packet': ['min', 'max']
    }).round(6)
    
    print("パケットごとの統計情報（最初の5パケット）:")
    print(packet_stats.head().to_string())
    
    # サンプルインデックスの連続性チェック
    sample_idx_issues = []
    for packet_id, group in df.groupby('seq_packet'):
        expected_idx = list(range(group['sample_idx'].min(), group['sample_idx'].max() + 1))
        actual_idx = sorted(group['sample_idx'].tolist())
        if expected_idx != actual_idx:
            sample_idx_issues.append(packet_id)
    
    if sample_idx_issues:
        print(f"\n警告: 以下のパケットでサンプルインデックスの欠損または重複があります:")
        print(f"パケットID: {sample_idx_issues[:10]}{'...' if len(sample_idx_issues) > 10 else ''}")
        print(f"問題のあるパケット数: {len(sample_idx_issues)}")
    else:
        print(f"\n✓ 全パケットでサンプルインデックスが正常です")


def main():
    parser = argparse.ArgumentParser(description='EMGデータセッションのCSVファイル表示ツール')
    parser.add_argument('csv_filename', nargs='?', help='表示するCSVファイル名')
    parser.add_argument('--session-dir', default='.', help='セッションディレクトリのパス (デフォルト: 現在のディレクトリ)')
    parser.add_argument('--list', action='store_true', help='利用可能なCSVファイル一覧を表示')
    parser.add_argument('--plot', action='store_true', help='データをプロット表示')
    parser.add_argument('--analyze', action='store_true', help='詳細なパケット解析を実行')
    parser.add_argument('--head', type=int, default=10, help='表示する先頭行数 (デフォルト: 10)')
    parser.add_argument('--tail', type=int, default=10, help='表示する末尾行数 (デフォルト: 10)')
    parser.add_argument('--no-data', action='store_true', help='データの先頭・末尾表示をスキップ')
    
    args = parser.parse_args()
    
    # manifest.jsonを読み込み
    manifest_path = os.path.join(args.session_dir, 'manifest.json')
    manifest_data = load_manifest(manifest_path)
    
    if not manifest_data:
        return 1
    
    print(f"セッション: {manifest_data['session_id']}")
    print(f"利用可能なラベル: {', '.join(manifest_data['labels'])}")
    
    # CSVファイル一覧を取得
    csv_files = list_csv_files(args.session_dir)
    
    if not csv_files:
        print("CSVファイルが見つかりません。")
        return 1
    
    # --listオプションが指定された場合は一覧表示のみ
    if args.list:
        return 0
    
    # CSVファイル名が指定されていない場合は対話的に選択
    if not args.csv_filename:
        print("\nCSVファイルを選択してください:")
        try:
            choice = int(input("番号を入力: ")) - 1
            if 0 <= choice < len(csv_files):
                csv_filename = csv_files[choice]
            else:
                print("無効な番号です。")
                return 1
        except (ValueError, KeyboardInterrupt):
            print("キャンセルされました。")
            return 1
    else:
        csv_filename = args.csv_filename
    
    # CSVファイルのパスを構築
    csv_path = os.path.join(args.session_dir, 'samples', csv_filename)
    
    # CSVファイルを表示
    df = display_csv_info(csv_path, manifest_data)
    if df is None:
        return 1
    
    # データの先頭と末尾を表示
    if not args.no_data:
        display_csv_data(df, args.head, args.tail)
    
    # 詳細解析
    if args.analyze:
        analyze_packets(df)
    
    # プロット表示
    if args.plot:
        try:
            plot_csv_data(df, csv_filename)
        except Exception as e:
            print(f"プロット表示エラー: {e}")
    
    return 0


if __name__ == "__main__":
    sys.exit(main())