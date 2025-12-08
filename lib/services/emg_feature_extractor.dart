import 'dart:math' as math;

class EmgFeatures {
  final double mva; // 平均絶対値
  final double cps; // 周波数中心など
  final double lfo; // 低周波帯のエネルギー
  final double variance;
  final double aw; // 平均波形長
  final double complexity; // 複雑度
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

  /// CoreML への入力ベクトルに変換
  List<double> toInputVector() {
    return <double>[mva, cps, lfo, variance, aw, complexity, ...ar];
  }
}

class EmgFeatureExtractor {
  /// samples: 1 ウィンドウ分の sEMG 生データ
  /// fs: サンプリング周波数 [Hz]（例: 1000）
  static EmgFeatures compute(List<double> samples, {double fs = 1000.0}) {
    final n = samples.length;
    if (n == 0) {
      throw ArgumentError('samples must not be empty');
    }

    final nDouble = n.toDouble();

    // MVA (Mean Voltage Amplitude / MAV)
    double sumAbs = 0;
    double sum = 0;
    for (final v in samples) {
      final av = v.abs();
      sumAbs += av;
      sum += v;
    }
    final mva = sumAbs / nDouble;

    // VAR
    final mean = sum / nDouble;
    double varAcc = 0;
    for (final v in samples) {
      final d = v - mean;
      varAcc += d * d;
    }
    final variance = varAcc / (nDouble - 1.0);

    // AW: Waveform length の平均
    double wl = 0;
    for (var i = 0; i < n - 1; i++) {
      wl += (samples[i + 1] - samples[i]).abs();
    }
    final aw = wl / (nDouble - 1.0);

    // 簡易 FFT で CPS/LFO/complexity 用のスペクトルを計算したいが
    // 実装が長くなるため、ここではダミーや外部ライブラリ前提とする。
    // TODO: 実環境に合わせて実装する
    final cps = 0.0;
    final lfo = 0.0;
    final complexity = 0.0;

    // AR(4) も Yule-Walker / Burg 法などの実装が必要なので簡易版
    // TODO: 真面目に実装するなら DSP ライブラリか自前実装を追加
    final ar = _estimateAr4(samples);

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

  /// 簡易な AR(4) 推定（ここではごく雑な placeholder）
  static List<double> _estimateAr4(List<double> x) {
    // 本番用途では必ず適切な AR 推定アルゴリズムに置き換えること
    // ここではゼロ配列を返す
    return const <double>[0.0, 0.0, 0.0, 0.0];
  }
}
