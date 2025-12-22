import 'package:flutter/services.dart';

import 'package:emg_mobile_analyzer/emg_prediction.dart';
import 'package:emg_mobile_analyzer/services/emg_feature_extractor.dart';
import 'package:emg_mobile_analyzer/emg_normalizer_const.dart';

class EmgMlService {
  static const MethodChannel _channel = MethodChannel('emg_ml');
  bool _ready = false;

  Future<void> initModel({
    String assetPath = 'assets/model/inference_model.mlmodel',
  }) async {
    if (_ready) return;

    // 正規化パラメータを一緒にロード
    await loadEmgNormalizerFromAsset();

    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();

    final ok = await _channel.invokeMethod<bool>('loadModel', {
      'assetPath': assetPath,
      'bytes': bytes,
    });

    if (ok != true) {
      throw Exception('loadModel failed');
    }
    _ready = true;
  }

  Future<EmgPrediction> predict(EmgFeatures features) async {
    if (!_ready) {
      await initModel();
    }

    final inputVector = features.toVector(); // length 10

    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'predict',
      {'features': inputVector},
    );

    if (result == null) throw Exception('predict result is null');

    final labelIndex = (result['labelIndex'] as num).toInt();
    final scoresDynamic = (result['scores'] as List<dynamic>);
    final scores = scoresDynamic.map((e) => (e as num).toDouble()).toList();

    return EmgPrediction(labelIndex: labelIndex, scores: scores);
  }

  Future<EmgPrediction> predictVector(List<double> features10) async {
    if (!_ready) {
      await initModel();
    }

    // ★ TypedData を避けるため必ず普通の List<double> にする
    final plain = List<double>.from(features10);

    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'predict',
      {'features': plain},
    );

    if (result == null) throw Exception('predict result is null');

    final labelIndex = (result['labelIndex'] as num).toInt();
    final scoresDynamic = (result['scores'] as List<dynamic>);
    final scores = scoresDynamic.map((e) => (e as num).toDouble()).toList();

    return EmgPrediction(labelIndex: labelIndex, scores: scores);
  }
}
