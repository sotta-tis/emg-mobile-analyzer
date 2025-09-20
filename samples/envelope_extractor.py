#!/usr/bin/env python3
"""
EMGデータの波形外形（エンベロープ）抽出スクリプト
指定ディレクトリ内の全CSVファイルの波形包絡線を抽出・出力
"""

import json
import pandas as pd
import numpy as np
import os
import sys
import argparse
import matplotlib.pyplot as plt
from scipy import signal
from pathlib import Path


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


def extract_envelope_hilbert(data, sample_rate):
    """ヒルベルト変換を使用してエンベロープを抽出"""
    # ヒルベルト変換で解析信号を計算
    analytic_signal = signal.hilbert(data)
    # 振幅包絡線を計算
    envelope = np.abs(analytic_signal)
    return envelope


def extract_envelope_rectify_smooth(data, sample_rate, cutoff_freq=10):
    """整流・平滑化によるエンベロープ抽出"""
    # 全波整流
    rectified = np.abs(data)
    
    # ローパスフィルタで平滑化
    nyquist = sample_rate / 2
    normalized_cutoff = cutoff_freq / nyquist
    
    # バターワースローパスフィルタ
    b, a = signal.butter(4, normalized_cutoff, btype='low')
    envelope = signal.filtfilt(b, a, rectified)
    
    return envelope


def extract_envelope_peak_detection(data, window_size=100):
    """ピーク検出による簡易エンベロープ抽出"""
    envelope = np.zeros_like(data)
    half_window = window_size // 2
    
    for i in range(len(data)):
        start = max(0, i - half_window)
        end = min(len(data), i + half_window + 1)
        envelope[i] = np.max(np.abs(data[start:end]))
    
    return envelope


def process_csv_file(csv_path, manifest_data, method='hilbert', **kwargs):
    """CSVファイルを処理してエンベロープを抽出"""
    try:
        df = pd.read_csv(csv_path)
        filename = os.path.basename(csv_path)
        
        # ファイル名からラベルとサンプル番号を抽出
        parts = filename.split('_')
        label = parts[1] if len(parts) >= 3 else "unknown"
        sample_num = parts[2].split('.')[0] if len(parts) >= 3 else "unknown"
        
        # 時間軸を作成（相対時間、秒単位）
        start_time = df['t_ms_packet'].min()
        time_seconds = (df['t_ms_packet'] - start_time) / 1000.0
        
        # 正規化された値を取得
        values = df['value_norm'].values
        
        # サンプリングレートを取得
        sample_rate = manifest_data['sampling']['sample_rate_hz'] if manifest_data else 1000
        
        # エンベロープ抽出
        if method == 'hilbert':
            envelope = extract_envelope_hilbert(values, sample_rate)
        elif method == 'rectify':
            cutoff_freq = kwargs.get('cutoff_freq', 10)
            envelope = extract_envelope_rectify_smooth(values, sample_rate, cutoff_freq)
        elif method == 'peak':
            window_size = kwargs.get('window_size', 100)
            envelope = extract_envelope_peak_detection(values, window_size)
        else:
            raise ValueError(f"不明なエンベロープ抽出方法: {method}")
        
        result = {
            'filename': filename,
            'label': label,
            'sample_num': sample_num,
            'time_seconds': time_seconds,
            'original_values': values,
            'envelope': envelope,
            'sample_rate': sample_rate,
            'duration_ms': df['t_ms_packet'].max() - df['t_ms_packet'].min(),
            'data_points': len(values)
        }
        
        return result
        
    except Exception as e:
        print(f"エラー: {csv_path}の処理に失敗しました: {e}")
        return None


def save_envelope_data(results, output_dir, format='csv'):
    """エンベロープデータを保存"""
    os.makedirs(output_dir, exist_ok=True)
    
    for result in results:
        if result is None:
            continue
            
        label = result['label']
        sample_num = result['sample_num']
        
        if format == 'csv':
            # CSVファイルとして保存
            output_filename = f"envelope_{label}_{sample_num}.csv"
            output_path = os.path.join(output_dir, output_filename)
            
            envelope_df = pd.DataFrame({
                'time_seconds': result['time_seconds'],
                'original_value': result['original_values'],
                'envelope': result['envelope']
            })
            
            envelope_df.to_csv(output_path, index=False)
            print(f"エンベロープデータを保存: {output_path}")
            
        elif format == 'npy':
            # NumPy配列として保存
            output_filename = f"envelope_{label}_{sample_num}.npy"
            output_path = os.path.join(output_dir, output_filename)
            
            envelope_data = {
                'time_seconds': result['time_seconds'],
                'original_values': result['original_values'],
                'envelope': result['envelope'],
                'metadata': {
                    'label': label,
                    'sample_num': sample_num,
                    'sample_rate': result['sample_rate'],
                    'duration_ms': result['duration_ms']
                }
            }
            
            np.save(output_path, envelope_data)
            print(f"エンベロープデータを保存: {output_path}")


def plot_all_envelopes(results, save_path=None, show_original=True):
    """全ラベルのエンベロープをプロット"""
    # ラベルごとにグループ化
    labels = {}
    for result in results:
        if result is None:
            continue
        label = result['label']
        if label not in labels:
            labels[label] = []
        labels[label].append(result)
    
    # プロット設定
    n_labels = len(labels)
    fig, axes = plt.subplots(n_labels, 1, figsize=(15, 4 * n_labels))
    if n_labels == 1:
        axes = [axes]
    
    colors = plt.cm.Set1(np.linspace(0, 1, max(1, len(labels))))
    
    for i, (label, samples) in enumerate(labels.items()):
        ax = axes[i]
        
        for j, result in enumerate(samples):
            time = result['time_seconds']
            envelope = result['envelope']
            original = result['original_values']
            sample_num = result['sample_num']
            
            # 元波形（薄く表示）
            if show_original:
                ax.plot(time, original, alpha=0.3, linewidth=0.5, color='gray',
                       label=f'{sample_num} (原波形)' if j == 0 else "")
            
            # エンベロープ
            ax.plot(time, envelope, linewidth=2, color=colors[i % len(colors)],
                   label=f'{sample_num} (エンベロープ)')
        
        ax.set_title(f'EMG Envelope - Label: {label}')
        ax.set_xlabel('Time (seconds)')
        ax.set_ylabel('Amplitude')
        ax.grid(True, alpha=0.3)
        ax.legend()
    
    plt.tight_layout()
    
    if save_path:
        plt.savefig(save_path, dpi=300, bbox_inches='tight')
        print(f"プロットを保存: {save_path}")
    
    plt.show()


def plot_envelope_comparison(results, save_path=None):
    """ラベル別エンベロープ比較プロット"""
    # ラベルごとの平均エンベロープを計算
    labels = {}
    for result in results:
        if result is None:
            continue
        label = result['label']
        if label not in labels:
            labels[label] = []
        labels[label].append(result['envelope'])
    
    plt.figure(figsize=(12, 8))
    colors = plt.cm.Set1(np.linspace(0, 1, len(labels)))
    
    for i, (label, envelopes) in enumerate(labels.items()):
        if not envelopes:
            continue
            
        # 最短長に合わせてトリミング
        min_length = min(len(env) for env in envelopes)
        trimmed_envelopes = [env[:min_length] for env in envelopes]
        
        # 平均と標準偏差を計算
        mean_envelope = np.mean(trimmed_envelopes, axis=0)
        std_envelope = np.std(trimmed_envelopes, axis=0)
        
        # 時間軸（正規化）
        time_normalized = np.linspace(0, 1, min_length)
        
        # プロット
        plt.plot(time_normalized, mean_envelope, linewidth=2, 
                color=colors[i], label=f'{label} (平均)')
        plt.fill_between(time_normalized, 
                        mean_envelope - std_envelope,
                        mean_envelope + std_envelope,
                        alpha=0.2, color=colors[i])
    
    plt.title('Label-wise Envelope Comparison')
    plt.xlabel('Normalized Time')
    plt.ylabel('Amplitude')
    plt.legend()
    plt.grid(True, alpha=0.3)
    
    if save_path:
        plt.savefig(save_path, dpi=300, bbox_inches='tight')
        print(f"比較プロットを保存: {save_path}")
    
    plt.show()


def print_summary(results):
    """処理結果のサマリーを出力"""
    if not results:
        print("処理されたデータがありません。")
        return
    
    valid_results = [r for r in results if r is not None]
    
    print(f"\n=== 処理サマリー ===")
    print(f"総ファイル数: {len(results)}")
    print(f"正常処理: {len(valid_results)}")
    print(f"エラー: {len(results) - len(valid_results)}")
    
    # ラベル別統計
    labels = {}
    for result in valid_results:
        label = result['label']
        if label not in labels:
            labels[label] = []
        labels[label].append(result)
    
    print(f"\n=== ラベル別統計 ===")
    for label, samples in labels.items():
        durations = [s['duration_ms'] for s in samples]
        data_points = [s['data_points'] for s in samples]
        
        print(f"{label}: {len(samples)}サンプル")
        print(f"  平均持続時間: {np.mean(durations):.1f} ms")
        print(f"  平均データポイント数: {np.mean(data_points):.0f}")


def main():
    parser = argparse.ArgumentParser(description='EMGデータ波形外形抽出ツール')
    parser.add_argument('session_dir', help='セッションディレクトリのパス')
    parser.add_argument('--method', choices=['hilbert', 'rectify', 'peak'], 
                       default='hilbert', help='エンベロープ抽出方法')
    parser.add_argument('--output-dir', default='envelopes', 
                       help='出力ディレクトリ (デフォルト: envelopes)')
    parser.add_argument('--output-format', choices=['csv', 'npy'], default='csv',
                       help='出力ファイル形式')
    parser.add_argument('--plot', action='store_true', help='エンベロープをプロット表示')
    parser.add_argument('--comparison', action='store_true', help='ラベル別比較プロット表示')
    parser.add_argument('--save-plots', action='store_true', help='プロットをファイルに保存')
    parser.add_argument('--cutoff-freq', type=float, default=10, 
                       help='整流法でのカットオフ周波数 (Hz)')
    parser.add_argument('--window-size', type=int, default=100,
                       help='ピーク検出法でのウィンドウサイズ')
    
    args = parser.parse_args()
    
    # manifest.jsonを読み込み
    manifest_path = os.path.join(args.session_dir, 'manifest.json')
    manifest_data = load_manifest(manifest_path)
    
    if not manifest_data:
        return 1
    
    print(f"セッション: {manifest_data['session_id']}")
    print(f"エンベロープ抽出方法: {args.method}")
    
    # samplesディレクトリ内のCSVファイルを取得
    samples_dir = os.path.join(args.session_dir, 'samples')
    if not os.path.exists(samples_dir):
        print(f"エラー: samplesディレクトリが見つかりません: {samples_dir}")
        return 1
    
    csv_files = [f for f in os.listdir(samples_dir) if f.endswith('.csv')]
    csv_files.sort()
    
    if not csv_files:
        print("CSVファイルが見つかりません。")
        return 1
    
    print(f"処理対象ファイル: {len(csv_files)}個")
    
    # 各CSVファイルを処理
    results = []
    kwargs = {
        'cutoff_freq': args.cutoff_freq,
        'window_size': args.window_size
    }
    
    for filename in csv_files:
        csv_path = os.path.join(samples_dir, filename)
        print(f"処理中: {filename}")
        result = process_csv_file(csv_path, manifest_data, args.method, **kwargs)
        results.append(result)
    
    # 結果をファイルに保存
    save_envelope_data(results, args.output_dir, args.output_format)
    
    # サマリー出力
    print_summary(results)
    
    # プロット表示
    if args.plot:
        plot_path = os.path.join(args.output_dir, 'envelopes_all.png') if args.save_plots else None
        plot_all_envelopes(results, plot_path)
    
    if args.comparison:
        comparison_path = os.path.join(args.output_dir, 'envelopes_comparison.png') if args.save_plots else None
        plot_envelope_comparison(results, comparison_path)
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
