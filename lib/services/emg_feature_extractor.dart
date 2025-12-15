import 'dart:math' as math;

import 'dart:typed_data';

class EmgFeatures {
  final double mva; // Mean Absolute Value
  final double cps; // Center Power Spectrum (スペクトル重心周波数)
  final double lfo; // 低周波帯エネルギー比 [0..1]
  final double variance; // 分散（Hjorth Activity と同じ）
  final double aw; // 平均波形長
  final double complexity; // Hjorth Complexity
  final List<double> ar; // AR1〜AR4

  EmgFeatures({
    required this.mva,
    required this.cps,
    required this.lfo,
    required this.variance,
    required this.aw,
    required this.complexity,
    required this.ar,
  }) : assert(ar.length == 4);

  List<double> toVector() => <double>[
    mva,
    cps,
    lfo,
    variance,
    aw,
    complexity,
    ...ar,
  ];
}

class _FreqFeatures {
  final double cps;
  final double lfoRatio;
  _FreqFeatures(this.cps, this.lfoRatio);
}

class EmgFeatureExtractor {
  // 正規化データを返す
  static Float64List computeNormalizedVector(
    List<double> samples, {
    required FeatureNormalizer normalizer,
    double fs = 1000.0,
    double lfoCutoffHz = 150.0,
  }) {
    final f = compute(samples, fs: fs, lfoCutoffHz: lfoCutoffHz);
    return normalizer.normalize10(f.toVector());
  }

  /// 1ウィンドウ分の sEMG 生データから特徴量を計算する
  static EmgFeatures compute(
    List<double> x, {
    double fs = 1000.0, // サンプリング周波数 [Hz]
    double lfoCutoffHz = 150, // 低周波帯の上限 [Hz]
  }) {
    final n = x.length;
    if (n == 0) {
      throw ArgumentError('samples must not be empty');
    }
    final nDouble = n.toDouble();

    // --- 基本統計 ---
    double sum = 0;
    double sumAbs = 0;
    for (final v in x) {
      sum += v;
      sumAbs += v.abs();
    }
    final mean = sum / nDouble;
    final mva = sumAbs / nDouble;

    // variance (Hjorth Activity)
    double varAcc = 0;
    final centered = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final d = x[i] - mean;
      centered[i] = d;
      varAcc += d * d;
    }
    final variance = varAcc / (nDouble - 1.0);

    // AW: Waveform length を点数で割ったもの
    double wl = 0;
    for (int i = 0; i < n - 1; i++) {
      wl += (x[i + 1] - x[i]).abs();
    }
    final aw = wl / (nDouble - 1.0);

    // --- Hjorth mobility / complexity ---
    // Activity = variance
    final activity = variance;

    // 一階差分
    final diff1 = List<double>.filled(n - 1, 0);
    for (int i = 0; i < n - 1; i++) {
      diff1[i] = x[i + 1] - x[i];
    }

    // var(diff1)
    final meanDiff1 = diff1.reduce((a, b) => a + b) / diff1.length;
    double varDiff1Acc = 0;
    for (final v in diff1) {
      final d = v - meanDiff1;
      varDiff1Acc += d * d;
    }
    final varDiff1 = varDiff1Acc / (diff1.length > 1 ? (diff1.length - 1) : 1);

    // mobility(x) = sqrt(var(dx)/var(x))
    final mobility =
        (activity <= 0 || varDiff1 <= 0) ? 0.0 : math.sqrt(varDiff1 / activity);

    // 二階差分
    final diff2 = List<double>.filled(diff1.length - 1, 0);
    for (int i = 0; i < diff1.length - 1; i++) {
      diff2[i] = diff1[i + 1] - diff1[i];
    }

    // var(diff2)
    double meanDiff2 = 0;
    double varDiff2Acc = 0;
    if (diff2.isNotEmpty) {
      meanDiff2 = diff2.reduce((a, b) => a + b) / diff2.length;
      for (final v in diff2) {
        final d = v - meanDiff2;
        varDiff2Acc += d * d;
      }
    }
    final varDiff2 = diff2.length > 1 ? varDiff2Acc / (diff2.length - 1) : 0.0;

    // mobility(diff1)
    final mobilityDiff1 =
        (varDiff1 <= 0 || varDiff2 <= 0) ? 0.0 : math.sqrt(varDiff2 / varDiff1);

    // Hjorth complexity = mobility(diff1) / mobility(x)
    final complexity = (mobility <= 0) ? 0.0 : (mobilityDiff1 / mobility);

    // --- 周波数特徴 (CPS, LFO) ---
    final freqFeatures = _computeFrequencyFeatures(
      centered, // DC成分を除いた信号を使う
      fs: fs,
      lfoCutoffHz: lfoCutoffHz,
    );
    final cps = freqFeatures.cps;
    final lfo = freqFeatures.lfoRatio;

    // --- AR(4) 係数 ---
    final ar = _estimateAr4(centered);

    return EmgFeatures(
      mva: mva,
      cps: cps,
      lfo: lfo,
      variance: variance,
      aw: aw,
      complexity: complexity,
      ar: ar,
    );
  }

  // ===== FFT working buffers (reused) =====
  static int _fftN = 0;
  static Float64List? _re;
  static Float64List? _im;
  static Float64List? _hann; // optional window

  static int _nextPow2(int n) {
    int p = 1;
    while (p < n) p <<= 1;
    return p;
  }

  static void _ensureFftBuffers(int n0) {
    final n = _nextPow2(n0); // 150 -> 256
    if (_fftN == n && _re != null && _im != null && _hann != null) return;

    _fftN = n;
    _re = Float64List(n);
    _im = Float64List(n);

    // Hann window for n0 (not n). We'll store length n0 window, reuse if same n0.
    // ここでは n0 が変わる可能性が低い想定(150固定)ならOK
    _hann = Float64List(n0);
    if (n0 > 1) {
      for (int i = 0; i < n0; i++) {
        _hann![i] = 0.5 * (1.0 - math.cos(2.0 * math.pi * i / (n0 - 1)));
      }
    } else if (n0 == 1) {
      _hann![0] = 1.0;
    }
  }

  static void _fftInPlace(Float64List re, Float64List im, int n) {
    // bit reversal
    for (int i = 1, j = 0; i < n; i++) {
      int bit = n >> 1;
      for (; (j & bit) != 0; bit >>= 1) {
        j ^= bit;
      }
      j ^= bit;
      if (i < j) {
        final tr = re[i];
        re[i] = re[j];
        re[j] = tr;
        final ti = im[i];
        im[i] = im[j];
        im[j] = ti;
      }
    }

    // FFT
    for (int len = 2; len <= n; len <<= 1) {
      final ang = -2.0 * math.pi / len;
      final wlenRe = math.cos(ang);
      final wlenIm = math.sin(ang);

      for (int i = 0; i < n; i += len) {
        double wRe = 1.0;
        double wIm = 0.0;

        final half = len >> 1;
        for (int j = 0; j < half; j++) {
          final uRe = re[i + j];
          final uIm = im[i + j];

          final vRe0 = re[i + j + half];
          final vIm0 = im[i + j + half];

          // v * w
          final vRe = vRe0 * wRe - vIm0 * wIm;
          final vIm = vRe0 * wIm + vIm0 * wRe;

          // u + v
          re[i + j] = uRe + vRe;
          im[i + j] = uIm + vIm;

          // u - v
          re[i + j + half] = uRe - vRe;
          im[i + j + half] = uIm - vIm;

          // w *= wlen
          final nextWRe = wRe * wlenRe - wIm * wlenIm;
          final nextWIm = wRe * wlenIm + wIm * wlenRe;
          wRe = nextWRe;
          wIm = nextWIm;
        }
      }
    }
  }

  static _FreqFeatures _computeFrequencyFeatures(
    List<double> x, {
    required double fs,
    required double lfoCutoffHz,
  }) {
    final n0 = x.length;
    if (n0 == 0) return _FreqFeatures(0.0, 0.0);

    _ensureFftBuffers(n0);
    final re = _re!;
    final im = _im!;
    final hann = _hann!;

    final n = _fftN;

    // load input with window, zero pad
    for (int i = 0; i < n0; i++) {
      re[i] = x[i] * hann[i];
      im[i] = 0.0;
    }
    for (int i = n0; i < n; i++) {
      re[i] = 0.0;
      im[i] = 0.0;
    }

    _fftInPlace(re, im, n);

    final int nFreq = n ~/ 2; // Nyquistまで
    double totalPower = 0.0;
    double weightedFreqSum = 0.0;
    double lowFreqPower = 0.0;

    // DC(0Hz)含める/含めないは好み。CPSはDCが強いと下がるので、
    // ここでは k=1 から（DC除外）にしておくこと
    for (int k = 1; k <= nFreq; k++) {
      final rr = re[k];
      final ii = im[k];
      final power = rr * rr + ii * ii;
      final freq = fs * k / n;

      totalPower += power;
      weightedFreqSum += freq * power;
      if (freq <= lfoCutoffHz) lowFreqPower += power;
    }

    final cps = totalPower > 0 ? (weightedFreqSum / totalPower) : 0.0;
    final lfoRatio = totalPower > 0 ? (lowFreqPower / totalPower) : 0.0;
    return _FreqFeatures(cps, lfoRatio);
  }

  // Yule-Walker による AR(4) 推定（簡易実装）
  static List<double> _estimateAr4(List<double> x) {
    final n = x.length;
    const p = 4;
    if (n <= p) {
      return List<double>.filled(p, 0.0);
    }

    // 自己相関 r[0..p]
    final r = List<double>.filled(p + 1, 0.0);
    for (int k = 0; k <= p; k++) {
      double acc = 0;
      for (int t = k; t < n; t++) {
        acc += x[t] * x[t - k];
      }
      r[k] = acc / n;
    }

    if (r[0].abs() < 1e-12) {
      return List<double>.filled(p, 0.0);
    }

    // Toeplitz 行列 R * a = r_vec を解く (簡単なガウス消去)
    // R[i,j] = r[|i-j|], r_vec[i] = r[i+1]
    final R = List.generate(p, (i) => List<double>.filled(p, 0.0));
    final rVec = List<double>.filled(p, 0.0);

    for (int i = 0; i < p; i++) {
      rVec[i] = r[i + 1];
      for (int j = 0; j < p; j++) {
        R[i][j] = r[(i - j).abs()];
      }
    }

    final a = _solveLinearSystem(R, rVec);
    return a;
  }

  // 簡単なガウス消去で線形方程式 A x = b を解く
  static List<double> _solveLinearSystem(List<List<double>> A, List<double> b) {
    final n = b.length;
    // 拡大行列 [A | b]
    for (int i = 0; i < n; i++) {
      A[i] = [...A[i], b[i]];
    }

    // 前進消去
    for (int i = 0; i < n; i++) {
      // ピボット選択（単純版）
      int pivot = i;
      double maxVal = A[i][i].abs();
      for (int r = i + 1; r < n; r++) {
        final v = A[r][i].abs();
        if (v > maxVal) {
          maxVal = v;
          pivot = r;
        }
      }
      if (maxVal < 1e-12) {
        // 解けない場合はゼロで返す
        return List<double>.filled(n, 0.0);
      }
      if (pivot != i) {
        final tmp = A[i];
        A[i] = A[pivot];
        A[pivot] = tmp;
      }

      final piv = A[i][i];
      // ピボット行を正規化
      for (int j = i; j <= n; j++) {
        A[i][j] /= piv;
      }

      // 他行から消去
      for (int r = 0; r < n; r++) {
        if (r == i) continue;
        final factor = A[r][i];
        for (int j = i; j <= n; j++) {
          A[r][j] -= factor * A[i][j];
        }
      }
    }

    // 解は最後の列
    final x = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      x[i] = A[i][n];
    }
    return x;
  }
}

class FeatureNormalizer {
  final Float64List mu; // length 10
  final Float64List sd; // length 10

  const FeatureNormalizer(this.mu, this.sd);

  Float64List normalize10(List<double> x) {
    if (x.length != 10) {
      throw ArgumentError('Expected 10-dim feature vector, got ${x.length}');
    }
    const eps = 1e-6;
    final out = Float64List(10);
    for (int i = 0; i < 10; i++) {
      final s = sd[i].abs() < eps ? eps : sd[i];
      out[i] = (x[i] - mu[i]) / s;
    }
    return out;
  }
}
