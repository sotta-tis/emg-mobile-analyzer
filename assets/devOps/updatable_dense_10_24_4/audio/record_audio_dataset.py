"""Record short audio clips per label and extract 10 numeric features for training.

Default flow
------------
poetry run python assets/devOps/record_audio_dataset.py \\
    --labels mva cps lfo var \\
    --seconds 2 \\
    --repeats 5 \\
    --out assets/devOps/audio_dataset.json

What it does
------------
- Prompts and records for each label in order, `seconds` seconds per clip.
- Extracts 10 float features (normalized) per clip:
  1-5: mean MFCC[0-4], 6: spectral_centroid, 7: spectral_bandwidth,
  8: spectral_rolloff, 9: zero_crossing_rate, 10: RMS energy.
- Appends JSON lines: {"features": [...10 floats...], "classLabel": "<label>"}.
- Dataset format matches `make_updatable_classifier` expected schema.

Requirements
------------
poetry add sounddevice librosa numpy
# macOS の場合はマイク許可ダイアログが出るので許可してください。
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import List, Sequence

import numpy as np

try:
    import sounddevice as sd
    import librosa
except Exception as exc:  # noqa: BLE001
    print(f"[import error] Please install dependencies: {exc}", file=sys.stderr)
    sys.exit(1)


def extract_10_features(samples: np.ndarray, sr: int) -> List[float]:
    """Compute 10 simple, stable features from a mono waveform."""
    # ensure float32
    y = samples.astype(np.float32)

    # MFCCs: take first 5 coefficients, mean over frames
    mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=5)
    mfcc_mean = mfcc.mean(axis=1)

    centroid = librosa.feature.spectral_centroid(y=y, sr=sr).mean()
    bandwidth = librosa.feature.spectral_bandwidth(y=y, sr=sr).mean()
    rolloff = librosa.feature.spectral_rolloff(y=y, sr=sr, roll_percent=0.85).mean()
    zcr = librosa.feature.zero_crossing_rate(y).mean()
    rms = librosa.feature.rms(y=y).mean()

    feats = [
        *mfcc_mean.tolist(),  # 5 values
        float(centroid),
        float(bandwidth),
        float(rolloff),
        float(zcr),
        float(rms),
    ]

    # guard against NaN/inf if silence
    feats = [0.0 if not np.isfinite(v) else float(v) for v in feats]
    return feats


def record_clip(seconds: float, sr: int, channels: int, device: int | str | None = None) -> np.ndarray:
    """Record audio; blocks until finished."""
    print(f"Recording {seconds}s ...")
    audio = sd.rec(
        int(seconds * sr),
        samplerate=sr,
        channels=channels,
        dtype="float32",
        device=device,
        blocking=True,
    )
    sd.wait()
    # convert to mono if needed
    if channels > 1:
        audio = audio.mean(axis=1)
    return audio.squeeze()


def main() -> None:
    parser = argparse.ArgumentParser(description="Record labeled audio and extract 10 features.")
    parser.add_argument(
        "--labels",
        nargs="+",
        default=["mva", "cps", "lfo", "var"],
        help="Labels recorded in order; cycles for each repeat.",
    )
    parser.add_argument("--seconds", type=float, default=2.0, help="Seconds per clip.")
    parser.add_argument("--repeats", type=int, default=5, help="How many full label cycles to record.")
    parser.add_argument("--sr", type=int, default=16000, help="Sample rate.")
    parser.add_argument("--channels", type=int, default=1, help="Input channels (1=mono).")
    parser.add_argument("--device", type=str, default=None, help="sounddevice input device name/id (optional).")
    parser.add_argument(
        "--out",
        type=Path,
        default=Path("assets/devOps/audio_dataset.json"),
        help="Output JSON (appends if exists).",
    )
    args = parser.parse_args()

    labels: Sequence[str] = args.labels
    output_path: Path = args.out

    rows: List[dict] = []
    total = args.repeats * len(labels)
    print(f"Will capture {total} clips ({args.repeats} cycles × {len(labels)} labels).")
    print("Press Ctrl+C to abort.")

    try:
        for cycle in range(args.repeats):
            print(f"\n=== Cycle {cycle + 1}/{args.repeats} ===")
            for label in labels:
                input(f"[Enter] to record label '{label}' for {args.seconds}s...")
                clip = record_clip(args.seconds, args.sr, args.channels, device=args.device)
                feats = extract_10_features(clip, args.sr)
                rows.append({"features": feats, "classLabel": label})
    except KeyboardInterrupt:
        print("\nRecording interrupted; saving what was collected.")

    # append to file; keep as JSON array for compatibility with existing demo
    if output_path.exists():
        try:
            existing = json.loads(output_path.read_text())
            if isinstance(existing, list):
                rows = existing + rows
        except Exception:
            pass

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(rows, indent=2))
    print(f"Wrote {len(rows)} samples to {output_path}")


if __name__ == "__main__":
    main()
