class EmgPrediction {
  final int labelIndex;
  final List<double> scores; // length 4 (paper,cizer,rock,pinch)

  const EmgPrediction({required this.labelIndex, required this.scores});

  double get bestScore =>
      scores.isEmpty ? 0 : scores.reduce((a, b) => a > b ? a : b);
}

/// クラスラベル（学習時の順序）を一元管理
class EmgLabels {
  // emg_dataset.json を train_offline.py に通した際のクラス順
  static const List<String> names = ['paper', 'cizer', 'rock', 'pinch'];
}

/// 学習用のラベル付きサンプル
class LabeledEmgSample {
  final List<double> features; // 生の10次元特徴（まだ正規化前）
  final int labelIndex;

  LabeledEmgSample({required this.features, required this.labelIndex});

  Map<String, dynamic> toJson() => {
    'features': features,
    'labelIndex': labelIndex,
  };
}
