import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:emg_mobile_analyzer/services/emg_feature_extractor.dart';

// デフォルト値（npzから事前に書き出したもの）
final _defaultMu = Float64List.fromList([
  0.23925741,
  16.439785,
  0.99114132,
  0.0078748921,
  0.0046733702,
  8.3036709,
  1.149771,
  -0.15878189,
  0.026741035,
  -0.05409557,
]);

final _defaultSd = Float64List.fromList([
  0.10237387,
  6.8772049,
  0.0081362473,
  0.0092841722,
  0.0022634859,
  5.0403185,
  0.15369788,
  0.19685261,
  0.10244801,
  0.060839657,
]);

FeatureNormalizer _emgNormalizer = FeatureNormalizer(_defaultMu, _defaultSd);
bool _normalizerLoaded = false;

/// 既にロード済みの正規化器を返す（アセット未読でもデフォルト値）。
FeatureNormalizer get emgNormalizer => _emgNormalizer;

/// アセットから平均値と偏差( `mu` / `sd` )を読み込み、グローバルな正規化器を更新する。a
Future<FeatureNormalizer> loadEmgNormalizerFromAsset({
  String assetPath =
      'assets/devOps/updatable_dense_10_24_4/emg/normalizer.json',
}) async {
  if (_normalizerLoaded) return _emgNormalizer;

  try {
    final jsonStr = await rootBundle.loadString(assetPath);
    final map = json.decode(jsonStr) as Map<String, dynamic>;
    final muRaw =
        (map['mu'] as List).cast<num>().map((e) => e.toDouble()).toList();
    final sdRaw =
        (map['sd'] as List).cast<num>().map((e) => e.toDouble()).toList();

    if (muRaw.length != 10 || sdRaw.length != 10) {
      throw StateError(
        'mu/sd must be length 10, got ${muRaw.length}/${sdRaw.length}',
      );
    }

    _emgNormalizer = FeatureNormalizer(
      Float64List.fromList(muRaw),
      Float64List.fromList(sdRaw),
    );
    _normalizerLoaded = true;
  } catch (e, st) {
    debugPrint('loadEmgNormalizerFromAsset failed ($e), fallback to defaults');
    debugPrint('$st');
    _normalizerLoaded = true; // 再試行を無限にしない
  }

  return _emgNormalizer;
}
