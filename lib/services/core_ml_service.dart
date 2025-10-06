import 'dart:typed_data';
import 'package:flutter/services.dart';

// Core ML連携用のサービス

class CoreMLService {
  static const MethodChannel _channel = MethodChannel('core_ml_channel');
  static bool _isAudioClassificationActive = false;

  /// 利用可能なモデルのリストを取得
  static Future<List<String>> getAvailableModels() async {
    try {
      print('📱 Flutter: Getting available models...');
      final List<dynamic> result = await _channel.invokeMethod(
        'getAvailableModels',
      );
      print('📱 Flutter: Available models: $result');
      return result.cast<String>();
    } on PlatformException catch (e) {
      print('❌ Flutter: Error getting available models: ${e.message}');
      throw CoreMLException('Failed to get available models: ${e.message}');
    }
  }

  /// 画像を分類
  static Future<List<ClassificationResult>> classifyImage(
    Uint8List imageData,
  ) async {
    try {
      print(
        '📱 Flutter: Classifying image with data size: ${imageData.length}',
      );
      final List<dynamic> result = await _channel.invokeMethod(
        'classifyImage',
        {'imageData': imageData},
      );
      print('📱 Flutter: Image classification result: $result');
      return result.map((item) => ClassificationResult.fromMap(item)).toList();
    } on PlatformException catch (e) {
      print('❌ Flutter: Error classifying image: ${e.message}');
      throw CoreMLException('Failed to classify image: ${e.message}');
    }
  }

  /// テキストを分類
  static Future<List<ClassificationResult>> classifyText(String text) async {
    try {
      print('📱 Flutter: Classifying text: $text');
      final List<dynamic> result = await _channel.invokeMethod('classifyText', {
        'text': text,
      });
      print('📱 Flutter: Text classification result: $result');
      return result.map((item) => ClassificationResult.fromMap(item)).toList();
    } on PlatformException catch (e) {
      print('❌ Flutter: Error classifying text: ${e.message}');
      throw CoreMLException('Failed to classify text: ${e.message}');
    }
  }

  /// リアルタイム音声分類を開始
  static Future<bool> startAudioClassification({
    Function(List<ClassificationResult>)? onClassification,
    Function(String)? onError,
    Function(List<double>)? onWaveform,
  }) async {
    try {
      if (_isAudioClassificationActive) {
        print('⚠️ Flutter: Audio classification is already active');
        return false;
      }

      print('📱 Flutter: Starting audio classification...');

      // コールバックを設定
      _channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'onAudioClassification':
            if (onClassification != null && call.arguments is List) {
              final classifications =
                  (call.arguments as List)
                      .map((item) => ClassificationResult.fromMap(item))
                      .toList();
              onClassification(classifications);
            }
            break;
          case 'onAudioClassificationError':
            if (onError != null && call.arguments is String) {
              onError(call.arguments as String);
            }
            break;
          case 'onRealtimeWaveform':
            if (onWaveform != null && call.arguments is List) {
              final waveformData =
                  (call.arguments as List)
                      .map((item) => (item as num).toDouble())
                      .toList();
              onWaveform(waveformData);
            }
            break;
        }
      });

      final Map<dynamic, dynamic> result = await _channel.invokeMethod(
        'startAudioClassification',
      );

      if (result['status'] == 'started') {
        _isAudioClassificationActive = true;
        print('📱 Flutter: Audio classification started successfully');
        return true;
      } else {
        print('❌ Flutter: Failed to start audio classification');
        return false;
      }
    } on PlatformException catch (e) {
      print('❌ Flutter: Error starting audio classification: ${e.message}');
      throw CoreMLException(
        'Failed to start audio classification: ${e.message}',
      );
    }
  }

  /// リアルタイム音声分類を停止
  static Future<bool> stopAudioClassification() async {
    try {
      if (!_isAudioClassificationActive) {
        print('⚠️ Flutter: Audio classification is not active');
        return false;
      }

      print('📱 Flutter: Stopping audio classification...');
      final Map<dynamic, dynamic> result = await _channel.invokeMethod(
        'stopAudioClassification',
      );

      if (result['status'] == 'stopped') {
        _isAudioClassificationActive = false;
        _channel.setMethodCallHandler(null);
        print('📱 Flutter: Audio classification stopped successfully');
        return true;
      } else {
        print('❌ Flutter: Failed to stop audio classification');
        return false;
      }
    } on PlatformException catch (e) {
      print('❌ Flutter: Error stopping audio classification: ${e.message}');
      throw CoreMLException(
        'Failed to stop audio classification: ${e.message}',
      );
    }
  }

  /// 音声分類の状態を確認
  static bool get isAudioClassificationActive => _isAudioClassificationActive;
}

/// 分類結果を表すクラス
class ClassificationResult {
  final String identifier;
  final double confidence;

  ClassificationResult({required this.identifier, required this.confidence});

  factory ClassificationResult.fromMap(Map<Object?, Object?> map) {
    return ClassificationResult(
      identifier: map['identifier'] as String,
      confidence: (map['confidence'] as num).toDouble(),
    );
  }

  @override
  String toString() {
    return 'ClassificationResult(identifier: $identifier, confidence: $confidence)';
  }
}

/// Core ML関連の例外クラス
class CoreMLException implements Exception {
  final String message;

  CoreMLException(this.message);

  @override
  String toString() {
    return 'CoreMLException: $message';
  }
}
