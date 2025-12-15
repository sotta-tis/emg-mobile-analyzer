"""Record a short audio clip, extract the same 10 features, and run Core ML inference.

Usage:
poetry run python assets/devOps/predict_audio.py \
  --model assets/devOps/updatable_dense_10_24_4/UpdatableClassifier_trained.mlmodel \
  --seconds 2.0

It prints predicted class and probabilities.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

import coremltools as ct
import numpy as np

# Add repo root to path so imports work from anywhere
REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.append(str(REPO_ROOT))

# Reuse the same feature extractor as dataset creation
from assets.devOps.record_audio_dataset import extract_10_features, record_clip


def main() -> None:
    parser = argparse.ArgumentParser(description="Record audio and run Core ML prediction.")
    parser.add_argument(
        "--model",
        type=Path,
        default=Path("updatable_dense_10_24_4/UpdatableClassifier_trained.mlmodel"),
        help="Path to .mlmodel",
    )
    parser.add_argument("--seconds", type=float, default=2.0, help="Record length in seconds")
    parser.add_argument("--sr", type=int, default=16000, help="Sample rate")
    parser.add_argument("--channels", type=int, default=1, help="Channels")
    parser.add_argument("--device", type=str, default=None, help="sounddevice input device name/id (optional).")
    parser.add_argument(
        "--weights",
        type=Path,
        default=None,
        help="Optional npz containing mu/sd (and weights). Defaults to <model_dir>/weights.npz",
    )
    args = parser.parse_args()

    # TMPDIR workaround for Core ML temp dir permissions
    import os
    os.environ.setdefault("TMPDIR", "/tmp")

    audio = record_clip(args.seconds, args.sr, args.channels, device=args.device)
    max_abs = float(np.max(np.abs(audio))) if audio.size else 0.0
    rms = float(np.sqrt(np.mean(audio ** 2))) if audio.size else 0.0
    print(f"Recorded audio stats: max_abs={max_abs:.6f}, rms={rms:.6f}")
    if max_abs < 1e-4:
        print("[warn] Input level extremely low (likely silence or wrong device).")

    feats = extract_10_features(audio, args.sr)
    feats = np.array(feats, dtype=np.float32)

    # Apply normalization using mu/sd from weights npz if available
    weights_path = args.weights or args.model.with_name("weights.npz")
    if weights_path.exists():
        w = np.load(weights_path)
        if "mu" in w and "sd" in w:
            mu = w["mu"].astype(np.float32)
            sd = w["sd"].astype(np.float32)
            feats = (feats - mu.squeeze()) / (sd.squeeze() + 1e-6)
            print(f"Applied normalization from {weights_path}")
        else:
            print(f"[info] {weights_path} has no mu/sd; skipping normalization.")
    else:
        print(f"[info] weights file not found: {weights_path}; skipping normalization.")

    model = ct.models.MLModel(str(args.model))
    pred = model.predict({"features": feats})

    print("Predicted class:", pred.get("classLabel"))
    print("Probabilities:", pred.get("classProbability"))


if __name__ == "__main__":
    main()
