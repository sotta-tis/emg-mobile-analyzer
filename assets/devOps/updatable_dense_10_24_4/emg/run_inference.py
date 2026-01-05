"""emg_dataset.json を使って UpdatableClassifier_trained_emg.mlmodel で推論するスクリプト。

使い方:
  poetry run python assets/devOps/updatable_dense_10_24_4/emg/run_inference.py \
      --model assets/devOps/updatable_dense_10_24_4/emg/UpdatableClassifier_trained_emg.mlmodel \
      --data  assets/devOps/updatable_dense_10_24_4/emg_dataset.json \
      --limit 5
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from typing import List

import numpy as np
import coremltools as ct


def load_dataset(path: Path) -> List[dict]:
    rows = json.loads(path.read_text())
    if not isinstance(rows, list):
        raise ValueError("dataset must be a JSON array")
    return rows


def load_norm(path: Path):
    """必須の正規化パラメータ(mu, sd)を npz から読む。無い場合はエラー。"""
    if not path.exists():
        raise FileNotFoundError(f"weights file not found: {path}")
    weights = np.load(path)
    if "mu" not in weights or "sd" not in weights:
        raise KeyError(f"{path} must contain mu and sd for normalization")
    return weights["mu"], weights["sd"]


def main():
    parser = argparse.ArgumentParser(description="Run inference on emg_dataset with Core ML model.")
    parser.add_argument(
        "--model",
        type=Path,
        default=Path(__file__).parent / "UpdatableClassifier_trained_emg.mlmodel",
        help="Path to .mlmodel file",
    )
    parser.add_argument(
        "--data",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "emg_dataset.json",
        help="Path to dataset JSON",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=10,
        help="Number of samples to run (<= dataset length)",
    )
    parser.add_argument(
        "--weights",
        type=Path,
        default=Path(__file__).parent / "trained_weights_emg.npz",
        help="Optional npz for normalization (mu, sd)",
    )
    args = parser.parse_args()

    # coremltools が書き込み可能な一時ディレクトリを使うよう強制
    tmpdir = Path("/tmp/coreml_tmp")
    tmpdir.mkdir(parents=True, exist_ok=True)
    os.environ["TMPDIR"] = str(tmpdir)
    os.environ["COREML_TEMPDIR"] = str(tmpdir)

    rows = load_dataset(args.data)
    rows = rows[: args.limit]

    mu, sd = load_norm(args.weights)

    # 一部環境で GPU/ANE コンパイルが失敗するため CPU のみに固定
    model = ct.models.MLModel(
        str(args.model),
        compute_units=ct.ComputeUnit.CPU_ONLY,
    )

    for idx, row in enumerate(rows):
        feats = np.array(row["features"], dtype=np.float32).reshape(-1)
        feats = (feats - mu.reshape(-1)) / (sd.reshape(-1) + 1e-6)
        try:
            result = model.predict({"features": feats})
            probs = result["classProbability"]
            top_label = max(probs, key=probs.get)
            top_prob = probs[top_label]
            truth = row.get("classLabel", "N/A")
            print(f"[{idx:03d}] pred={top_label:>6} ({top_prob:.3f})  truth={truth}")
        except Exception as exc:  # noqa: BLE001
            print(f"[{idx:03d}] Core ML predict failed ({exc}); trying NumPy fallback")
            try:
                weights = np.load(args.weights)
                W1 = weights["hidden_W"]
                b1 = weights["hidden_b"]
                W2 = weights["out_W"]
                b2 = weights["out_b"]
                h = np.maximum(0, feats @ W1.T + b1)
                logits = h @ W2.T + b2
                logits -= logits.max()
                exp = np.exp(logits)
                probs = exp / exp.sum()
                top_idx = int(np.argmax(probs))
                classes = [f"class_{i}" for i in range(len(probs))]
                top_label = classes[top_idx]
                top_prob = float(probs[top_idx])
                print(f"      fallback pred={top_label:>6} ({top_prob:.3f})  truth={row.get('classLabel','N/A')}")
            except Exception as exc2:  # noqa: BLE001
                print(f"      Fallback inference also failed: {exc2}")


if __name__ == "__main__":
    main()
