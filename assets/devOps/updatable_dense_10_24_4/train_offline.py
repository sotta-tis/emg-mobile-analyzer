"""Offline train the 10->24(ReLU)->4 classifier on a JSON dataset.

Dataset format (same as record_audio_dataset.py):
[
  {"features": [f1..f10], "classLabel": "mva"},
  ...
]

Outputs a ready-to-use .mlmodel with learned weights (still marked updatable).
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import List, Sequence

import numpy as np
import coremltools as ct

# Allow running as a script without installing the package
REPO_ROOT = Path(__file__).resolve().parents[3]
if str(REPO_ROOT) not in sys.path:
    sys.path.append(str(REPO_ROOT))

from assets.devOps.updatable_dense_10_24_4.model import _build_builder, DEFAULT_CLASSES
from coremltools.models.neural_network import SgdParams


def load_dataset(path: Path):
    rows = json.loads(path.read_text())
    if not isinstance(rows, list):
        raise ValueError("Dataset must be a JSON array.")
    X = np.array([r["features"] for r in rows], dtype=np.float32)
    labels = [r["classLabel"] for r in rows]
    return X, labels


def train_mlp(
    X: np.ndarray,
    y: Sequence[str],
    classes: List[str],
    hidden_dim: int = 24,
    epochs: int = 300,
    lr: float = 0.05,
    l2: float = 1e-4,
    batch_size: int = 32,
    seed: int = 0,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    rng = np.random.default_rng(seed)
    num_classes = len(classes)
    feat_dim = X.shape[1]
    y_idx = np.array([classes.index(lbl) for lbl in y], dtype=np.int64)

    W1 = (0.01 * rng.standard_normal((hidden_dim, feat_dim))).astype(np.float32)
    b1 = np.zeros(hidden_dim, dtype=np.float32)
    W2 = (0.01 * rng.standard_normal((num_classes, hidden_dim))).astype(np.float32)
    b2 = np.zeros(num_classes, dtype=np.float32)

    N = X.shape[0]
    idxs = np.arange(N)
    for ep in range(1, epochs + 1):
        rng.shuffle(idxs)
        for start in range(0, N, batch_size):
            batch = idxs[start : start + batch_size]
            xb = X[batch]
            yb = y_idx[batch]

            # forward
            h_pre = xb @ W1.T + b1
            h = np.maximum(0, h_pre)
            logits = h @ W2.T + b2
            logits -= logits.max(axis=1, keepdims=True)
            exp = np.exp(logits)
            probs = exp / exp.sum(axis=1, keepdims=True)

            # loss grad
            grad_logits = probs
            grad_logits[np.arange(len(batch)), yb] -= 1
            grad_logits /= len(batch)

            grad_W2 = grad_logits.T @ h + l2 * W2
            grad_b2 = grad_logits.sum(axis=0)

            grad_h = grad_logits @ W2
            grad_h[h_pre <= 0] = 0

            grad_W1 = grad_h.T @ xb + l2 * W1
            grad_b1 = grad_h.sum(axis=0)

            W2 -= lr * grad_W2
            b2 -= lr * grad_b2
            W1 -= lr * grad_W1
            b1 -= lr * grad_b1

        if ep % max(10, epochs // 10) == 0 or ep == 1:
            # full-batch eval
            h = np.maximum(0, X @ W1.T + b1)
            logits = h @ W2.T + b2
            pred = logits.argmax(axis=1)
            acc = (pred == y_idx).mean()
            print(f"epoch {ep:4d}  acc {acc:.3f}")

    return W1.astype(np.float32), b1.astype(np.float32), W2.astype(np.float32), b2.astype(np.float32)


def save_coreml(
    W1: np.ndarray,
    b1: np.ndarray,
    W2: np.ndarray,
    b2: np.ndarray,
    classes: List[str],
    output_path: Path,
    keep_updatable: bool = True,
    npz_path: Path | None = None,
    mu: np.ndarray | None = None,
    sd: np.ndarray | None = None,
):
    """Rebuild CoreML model with learned weights.

    keep_updatable=True (default): retain training config (make_updatable + loss + optimizer)
    keep_updatable=False: export inference-only model (no training config).
    """
    builder = _build_builder(
        feature_dim=W1.shape[1],
        class_labels=classes,
        hidden_dim=W1.shape[0],
        hidden_W=W1,
        hidden_b=b1,
        out_W=W2,
        out_b=b2,
    )

    if keep_updatable:
        builder.make_updatable(["dense"])
        builder.set_categorical_cross_entropy_loss(name="lossLayer", input="classProbability")
        # SGD optimizer (via SgdParams) is widely supported by Core ML compiler
        builder.set_sgd_optimizer(SgdParams(lr=0.01, batch=32, momentum=0.9))
        builder.set_epochs(10)
        builder.set_shuffle(1)

    spec = builder.spec
    spec.description.metadata.shortDescription = "Offline-trained 10->24->4 classifier."
    spec.description.metadata.author = "train_offline.py"
    spec.description.metadata.license = "internal"

    model = ct.models.MLModel(spec)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    model.save(output_path)
    print(f"Saved trained model to {output_path}")

    if npz_path is not None:
        npz_path.parent.mkdir(parents=True, exist_ok=True)
        np.savez(npz_path, hidden_W=W1, hidden_b=b1, out_W=W2, out_b=b2, mu=mu, sd=sd)
        print(f"Saved weights to {npz_path}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Offline-train 10->24->4 CoreML classifier.")
    parser.add_argument("--data", type=Path, required=True, help="JSON dataset path")
    parser.add_argument(
        "--out",
        type=Path,
        default=Path(__file__).parent / "UpdatableClassifier_trained.mlmodel",
        help="Output .mlmodel path",
    )
    parser.add_argument("--epochs", type=int, default=300)
    parser.add_argument("--lr", type=float, default=0.05)
    parser.add_argument("--l2", type=float, default=1e-4)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument(
        "--labels",
        nargs="+",
        default=None,
        help="Custom label order (length must be 4). If omitted, label order is taken from data as first-seen.",
    )
    parser.add_argument(
        "--keep-updatable",
        action="store_true",
        help="Keep training config (make_updatable + loss + optimizer) in the saved model. Default: ON.",
        default=True,
    )
    parser.add_argument(
        "--npz-out",
        type=Path,
        default=None,
        help="Optional path to save weights as npz (keys: hidden_W, hidden_b, out_W, out_b, mu, sd).",
    )
    args = parser.parse_args()

    X, labels = load_dataset(args.data)

    # seikika
    eps = 1e-6
    mu = X.mean(axis=0, keepdims=True)
    sd = X.std(axis=0, keepdims=True) + eps
    X = (X - mu) / sd

    if args.labels:
        classes = list(args.labels)
        if len(classes) != 4:
            raise ValueError(f"--labels must have length 4, got {len(classes)}")
    else:
        # preserve first-seen order from dataset
        classes = []
        for lbl in labels:
            if lbl not in classes:
                classes.append(lbl)
            if len(classes) == 4:
                break
        if len(classes) != 4:
            raise ValueError(f"Dataset must contain 4 distinct labels, found {classes}")

    unseen = sorted(set(labels) - set(classes))
    if unseen:
        raise ValueError(f"Found unknown labels: {unseen}; expected labels subset of {classes}")
    if X.shape[1] != 10:
        raise ValueError(f"Expected feature dim 10, got {X.shape[1]}")

    W1, b1, W2, b2 = train_mlp(
        X,
        labels,
        classes,
        hidden_dim=24,
        epochs=args.epochs,
        lr=args.lr,
        l2=args.l2,
        batch_size=args.batch_size,
        seed=args.seed,
    )
    save_coreml(
        W1,
        b1,
        W2,
        b2,
        classes,
        args.out,
        keep_updatable=args.keep_updatable,
        npz_path=args.npz_out,
        mu=mu,
        sd=sd,
    )


if __name__ == "__main__":
    main()
