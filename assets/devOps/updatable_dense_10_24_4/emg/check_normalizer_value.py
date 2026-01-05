import json
from pathlib import Path

import numpy as np

WEIGHTS = Path(__file__).with_name("trained_weights_emg.npz")
OUT_JSON = Path(__file__).with_name("normalizer.json")


def main() -> None:
  w = np.load(WEIGHTS)
  mu = w["mu"].reshape(-1).tolist()
  sd = w["sd"].reshape(-1).tolist()

  print("mu =", mu)
  print("sd =", sd)

  OUT_JSON.write_text(
      json.dumps({"mu": mu, "sd": sd}, indent=2),
      encoding="utf-8",
  )
  print(f"wrote {OUT_JSON.name}")


if __name__ == "__main__":
  main()
