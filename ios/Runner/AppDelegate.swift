import Flutter
import UIKit
import CoreML
import Vision

// Core ML連携のためのMethod Channel実装

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var methodChannel: FlutterMethodChannel?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    methodChannel = FlutterMethodChannel(name: "core_ml_channel", binaryMessenger: controller.binaryMessenger)
    
    methodChannel?.setMethodCallHandler { [weak self] (call, result) in
      self?.handleMethodCall(call, result: result)
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Flutter側からのメソッド呼び出しを処理
  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    print("📱 Method called: \(call.method)")
    print("📱 Arguments: \(String(describing: call.arguments))")
    
    switch call.method {
    case "classifyText":
      if let args = call.arguments as? [String: Any],
         let text = args["text"] as? String {
        print("📱 Classifying text: \(text)")
        classifyText(text: text, result: result)
      } else {
        print("❌ Invalid arguments for classifyText")
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      }
    case "classifyImage":
      if let args = call.arguments as? [String: Any],
         let imageData = args["imageData"] as? FlutterStandardTypedData {
        print("📱 Classifying image with data size: \(imageData.data.count)")
        classifyImage(imageData: imageData.data, result: result)
      } else {
        print("❌ Invalid arguments for classifyImage")
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
      }
    case "getAvailableModels":
      print("📱 Getting available models")
      getAvailableModels(result: result)
    default:
      print("❌ Method not implemented: \(call.method)")
      result(FlutterMethodNotImplemented)
    }
  }
  
  // テキスト分析（言語検出、長さ分析、感情分析）
  private func classifyText(text: String, result: @escaping FlutterResult) {
    print("📱 Starting text classification for: \(text)")
    
    // テキストの言語と感情分析を試行
    var classifications: [[String: Any]] = []
    
    // 言語検出
    let language = NSLinguisticTagger.dominantLanguage(for: text) ?? "unknown"
    classifications.append([
      "identifier": "Language: \(language)",
      "confidence": 0.9
    ])
    
    // テキストの長さ分析
    let textLength = text.count
    var lengthCategory = "short"
    if textLength > 50 {
      lengthCategory = "long"
    } else if textLength > 20 {
      lengthCategory = "medium"
    }
    classifications.append([
      "identifier": "Length: \(lengthCategory) (\(textLength) chars)",
      "confidence": 1.0
    ])
    
    // 感情分析
    let positiveWords = ["良い", "素晴らしい", "楽しい", "嬉しい", "最高"]
    let negativeWords = ["悪い", "悲しい", "辛い", "嫌い", "最悪"]
    
    var positiveCount = 0
    var negativeCount = 0
    
    for word in positiveWords {
      if text.contains(word) {
        positiveCount += 1
      }
    }
    
    for word in negativeWords {
      if text.contains(word) {
        negativeCount += 1
      }
    }
    
    if positiveCount > negativeCount {
      classifications.append([
        "identifier": "Sentiment: Positive",
        "confidence": Double(positiveCount) / Double(max(positiveCount + negativeCount, 1))
      ])
    } else if negativeCount > positiveCount {
      classifications.append([
        "identifier": "Sentiment: Negative",
        "confidence": Double(negativeCount) / Double(max(positiveCount + negativeCount, 1))
      ])
    } else {
      classifications.append([
        "identifier": "Sentiment: Neutral",
        "confidence": 0.5
      ])
    }
    
    print("📱 Text classification result: \(classifications)")
    result(classifications)
  }
  
  // 画像分類（Vision framework使用）
  private func classifyImage(imageData: Data, result: @escaping FlutterResult) {
    print("📱 Starting image classification with data size: \(imageData.count)")
    
    guard let image = UIImage(data: imageData) else {
      print("❌ Failed to create UIImage from data")
      result(FlutterError(code: "INVALID_IMAGE", message: "Invalid image data", details: nil))
      return
    }
    
    print("📱 Image created successfully, size: \(image.size)")
    
    // iOS 13.0+でのみ利用可能なVNClassifyImageRequestを使用
    if #available(iOS 13.0, *) {
      print("📱 Using VNClassifyImageRequest (iOS 13.0+)")
      
      let request = VNClassifyImageRequest { request, error in
        if let error = error {
          print("❌ Classification error: \(error.localizedDescription)")
          result(FlutterError(code: "CLASSIFICATION_ERROR", message: error.localizedDescription, details: nil))
          return
        }
        
        guard let results = request.results as? [VNClassificationObservation] else {
          print("❌ No classification results")
          result(FlutterError(code: "NO_RESULTS", message: "No classification results", details: nil))
          return
        }
        
        // 上位5つの結果を取得
        let topResults = Array(results.prefix(5))
        let classifications = topResults.map { observation in
          return [
            "identifier": observation.identifier,
            "confidence": observation.confidence
          ]
        }
        
        print("📱 Image classification result: \(classifications)")
        result(classifications)
      }
      
      guard let cgImage = image.cgImage else {
        print("❌ Failed to get CGImage from UIImage")
        result(FlutterError(code: "INVALID_IMAGE", message: "Failed to get CGImage", details: nil))
        return
      }
      
      let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
      
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          print("📱 Performing image classification...")
          try handler.perform([request])
        } catch {
          print("❌ Handler error: \(error.localizedDescription)")
          DispatchQueue.main.async {
            result(FlutterError(code: "HANDLER_ERROR", message: error.localizedDescription, details: nil))
          }
        }
      }
    } else {
      print("📱 Using fallback for iOS < 13.0")
      // iOS 13.0未満の場合のフォールバック
      let classifications = [
        [
          "identifier": "image_analysis",
          "confidence": 1.0
        ]
      ]
      print("📱 Fallback image classification result: \(classifications)")
      result(classifications)
    }
  }
  
  // 利用可能なモデル一覧を返す
  private func getAvailableModels(result: @escaping FlutterResult) {
    print("📱 Getting available models...")
    // 利用可能な組み込みモデルのリストを返す
    let availableModels = [
      "VNClassifyImageRequest", // 画像分類
      "VNRecognizeTextRequest", // テキスト認識
      "VNRecognizeAnimalsRequest", // 動物認識
      "VNRecognizeLandmarksRequest", // ランドマーク認識
      "VNGeneratePersonSegmentationRequest", // 人物セグメンテーション
      "VNGenerateObjectMaskRequest", // オブジェクトマスク生成
    ]
    
    print("📱 Available models: \(availableModels)")
    result(availableModels)
  }
}
