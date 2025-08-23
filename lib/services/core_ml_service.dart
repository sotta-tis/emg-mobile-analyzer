import 'dart:typed_data';
import 'package:flutter/services.dart';

// Core ML連携用のサービス

class CoreMLService {
  static const MethodChannel _channel = MethodChannel('core_ml_channel');

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
