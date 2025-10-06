import Flutter
import UIKit
import CoreML
import Vision
import SoundAnalysis
import AVFoundation

// Core ML連携のためのMethod Channel実装

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var methodChannel: FlutterMethodChannel?
  private var audioEngine: AVAudioEngine?
  private var streamAnalyzer: SNAudioStreamAnalyzer?
  private var testTimer: Timer?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    methodChannel = FlutterMethodChannel(name: "core_ml_channel", binaryMessenger: controller.binaryMessenger)
    
    methodChannel?.setMethodCallHandler { [weak self] (call, result) in
      self?.handleMethodCall(call, result: result)
    }
    
    // アプリライフサイクル監視
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  @objc private func appWillResignActive() {
    print("📱 App will resign active - keeping audio running")
  }
  
  @objc private func appDidBecomeActive() {
    print("📱 App did become active")
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
    case "startAudioClassification":
      print("📱 Starting audio classification")
      startAudioClassification(result: result)
    case "stopAudioClassification":
      print("📱 Stopping audio classification")
      stopAudioClassification(result: result)
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
      "SNClassifySoundRequest", // 音声分類
    ]
    
    print("📱 Available models: \(availableModels)")
    result(availableModels)
  }
  
  // 音声レベルを計算
  private func calculateAudioLevel(buffer: AVAudioPCMBuffer) -> Float {
    guard let channelData = buffer.floatChannelData else { return 0.0 }
    
    let channelDataValue = channelData.pointee
    let channelDataValueArray = Array(UnsafeBufferPointer(start: channelDataValue, count: Int(buffer.frameLength)))
    
    let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
    let avgPower = 20 * log10(rms)
    let normalizedPower = max(0, (avgPower + 60) / 60) // -60dBから0dBを0-1に正規化
    
    return normalizedPower
  }
  
  // リアルタイム波形データを送信
  private var lastWaveformSentTime: TimeInterval = 0
  private func sendRealtimeWaveformData(buffer: AVAudioPCMBuffer, audioLevel: Float) {
    let currentTime = Date().timeIntervalSince1970
    
    // 60fpsで波形更新（約16ms間隔）
    guard currentTime - lastWaveformSentTime > 0.016 else { return }
    lastWaveformSentTime = currentTime
    
    // オーディオバッファから波形データを抽出
    guard let channelData = buffer.floatChannelData else { return }
    let channelDataValue = channelData.pointee
    let frameLength = Int(buffer.frameLength)
    
    // ダウンサンプリング（8192フレームから50ポイントに削減）
    let downsampleRate = max(1, frameLength / 50)
    var waveformPoints: [Float] = []
    
    for i in stride(from: 0, to: frameLength, by: downsampleRate) {
      let sample = channelDataValue[i]
      // 正規化なしでそのまま使用
      waveformPoints.append(sample)
    }
    
    self.methodChannel?.invokeMethod("onRealtimeWaveform", arguments: waveformPoints)
  }
  
  // 音声レベルに基づいた分類結果を送信
  private var lastSentTime: TimeInterval = 0
  private func sendAudioLevelBasedClassification(audioLevel: Float) {
    let currentTime = Date().timeIntervalSince1970
    
    // 0.5秒間隔で送信（負荷軽減）
    guard currentTime - lastSentTime > 0.5 else { return }
    lastSentTime = currentTime
    
    var classifications: [[String: Any]] = []
    
    if audioLevel > 0.1 {
      // 音声が検出された場合
      classifications.append([
        "identifier": "audio_detected",
        "confidence": Double(audioLevel)
      ])
      
      if audioLevel > 0.3 {
        classifications.append([
          "identifier": "loud_sound",
          "confidence": Double(audioLevel * 0.8)
        ])
      } else {
        classifications.append([
          "identifier": "quiet_sound", 
          "confidence": Double(audioLevel * 1.2)
        ])
      }
    } else {
      // 静寂
      classifications.append([
        "identifier": "silence",
        "confidence": 0.9
      ])
    }
    
    print("📱 Sending audio level based classification: \(classifications)")
    self.methodChannel?.invokeMethod("onAudioClassification", arguments: classifications)
  }
  
  // テスト用タイマーを開始
  private func startTestTimer() {
    print("📱 Starting test timer for dummy audio data")
    testTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
      // ダミーの音声分類結果を生成
      let dummyClassifications = [
        [
          "identifier": "speech",
          "confidence": Double.random(in: 0.5...0.9)
        ],
        [
          "identifier": "silence",
          "confidence": Double.random(in: 0.1...0.4)
        ]
      ]
      
      print("📱 Sending dummy audio classification: \(dummyClassifications)")
      DispatchQueue.main.async {
        self.methodChannel?.invokeMethod("onAudioClassification", arguments: dummyClassifications)
      }
    }
  }
  
  // リアルタイム音声分類を開始
  private func startAudioClassification(result: @escaping FlutterResult) {
    print("📱 Starting real-time audio classification...")
    
    // iOS 15.0以降でのみ利用可能
    if #available(iOS 15.0, *) {
      do {
        // 既存のオーディオエンジンを停止
        if let existingEngine = audioEngine {
          if existingEngine.isRunning {
            existingEngine.stop()
            existingEngine.inputNode.removeTap(onBus: 0)
          }
        }
        
        // オーディオセッションをリセット
        try AVAudioSession.sharedInstance().setActive(false)
        
        // オーディオエンジンを設定
        audioEngine = AVAudioEngine()
        let inputNode = audioEngine!.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        print("📱 Input format: \(inputFormat)")
        
        // ストリームアナライザーを作成
        streamAnalyzer = try SNAudioStreamAnalyzer(format: inputFormat)
        
        // 音声分類リクエストを作成
        let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
        print("📱 Created SNClassifySoundRequest with version1")
        print("📱 iOS Version: \(UIDevice.current.systemVersion)")
        print("📱 Sound Analysis available: \(NSClassFromString("SNClassifySoundRequest") != nil)")
        
        // オブザーバーとして自分自身を設定
        let observer = AudioClassificationObserver(methodChannel: methodChannel)
        try streamAnalyzer!.add(request, withObserver: observer)
        print("📱 Added observer to stream analyzer")
        
        // オーディオエンジンにノードを接続（安定したバッファサイズを使用）
        inputNode.installTap(onBus: 0, bufferSize: 8192, format: inputFormat) { buffer, time in
          // 音声レベルを計算
          let audioLevel = self.calculateAudioLevel(buffer: buffer)
          
          // 50回に1回だけログ出力（ログ量削減）
          if Int(time.sampleTime) % 40960 == 0 {
            print("📱 Audio buffer: frames=\(buffer.frameLength), level=\(String(format: "%.3f", audioLevel)), sampleTime=\(time.sampleTime)")
          }
          
          // Sound Analysisに送信
          self.streamAnalyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
          
          // リアルタイム波形データをFlutterに送信
          DispatchQueue.main.async {
            self.sendRealtimeWaveformData(buffer: buffer, audioLevel: audioLevel)
          }
        }
        print("📱 Installed audio tap with buffer size: 8192")
        
        // 録音権限をリクエスト
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
          DispatchQueue.main.async {
            if granted {
              do {
                // バックグラウンド対応のオーディオセッション設定
                try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
                try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
                
                print("📱 Audio session configured - Sample rate: \(AVAudioSession.sharedInstance().sampleRate), Buffer duration: \(AVAudioSession.sharedInstance().ioBufferDuration)")
                
                try self.audioEngine!.start()
                print("📱 Audio engine started successfully")
                
                // テスト用ダミーデータは無効化して実際のSound Analysisを使用
                // self.startTestTimer()
                
                result(["status": "started"])
              } catch {
                print("❌ Failed to start audio engine: \(error)")
                result(FlutterError(code: "AUDIO_ENGINE_ERROR", message: error.localizedDescription, details: nil))
              }
            } else {
              print("❌ Microphone permission denied")
              result(FlutterError(code: "PERMISSION_DENIED", message: "Microphone permission required", details: nil))
            }
          }
        }
      } catch {
        print("❌ Error setting up audio classification: \(error)")
        print("❌ Error details: \(error)")
        
        if let nsError = error as NSError? {
          print("❌ Error domain: \(nsError.domain)")
          print("❌ Error code: \(nsError.code)")
          print("❌ Error userInfo: \(nsError.userInfo)")
        }
        
        result(FlutterError(code: "SETUP_ERROR", message: "Audio setup failed: \(error.localizedDescription)", details: "\(error)"))
      }
    } else {
      print("❌ Sound Analysis requires iOS 15.0+")
      result(FlutterError(code: "UNSUPPORTED_VERSION", message: "Sound Analysis requires iOS 15.0+", details: nil))
    }
  }
  
  // リアルタイム音声分類を停止
  private func stopAudioClassification(result: @escaping FlutterResult) {
    print("📱 Stopping audio classification...")
    
    audioEngine?.stop()
    audioEngine?.inputNode.removeTap(onBus: 0)
    audioEngine = nil
    streamAnalyzer = nil
    
    // テストタイマーを停止
    testTimer?.invalidate()
    testTimer = nil
    
    do {
      try AVAudioSession.sharedInstance().setActive(false)
      print("📱 Audio classification stopped")
      result(["status": "stopped"])
    } catch {
      print("❌ Error stopping audio session: \(error)")
      result(FlutterError(code: "STOP_ERROR", message: error.localizedDescription, details: nil))
    }
  }
  
}

// リアルタイム音声分類結果を処理するオブザーバー
@available(iOS 15.0, *)
class AudioClassificationObserver: NSObject, SNResultsObserving {
  private weak var methodChannel: FlutterMethodChannel?
  private var isFirstResult = true
  
  init(methodChannel: FlutterMethodChannel?) {
    self.methodChannel = methodChannel
    super.init()
    print("📱 AudioClassificationObserver initialized")
    
    // 5秒後にSound Analysisが動作しているかチェック
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
      if self.isFirstResult {
        print("⚠️ Sound Analysis not producing results after 5 seconds - starting fallback")
        // フォールバック: 定期的にダミーデータを送信
        self.startFallbackTimer()
      }
    }
  }
  
  private func startFallbackTimer() {
    Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
      let fallbackClassifications = [
        [
          "identifier": "ambient_sound",
          "confidence": 0.3
        ]
      ]
      
      DispatchQueue.main.async {
        self.methodChannel?.invokeMethod("onAudioClassification", arguments: fallbackClassifications)
      }
    }
  }
  
  func request(_ request: SNRequest, didProduce result: SNResult) {
    if isFirstResult {
      print("🎉 First Sound Analysis result received!")
      isFirstResult = false
    }
    
    guard let classificationResult = result as? SNClassificationResult else { 
      print("❌ Failed to cast result to SNClassificationResult")
      return 
    }
    
    let totalCount = classificationResult.classifications.count
    print("📱 Sound Analysis: \(totalCount) classifications received")
    
    // 信頼度フィルタリングを緩和し、より多くの結果を送信
    let filteredClassifications = classificationResult.classifications.filter { $0.confidence > 0.05 }
    let topClassifications = Array(filteredClassifications.prefix(5))
    
    let classifications = topClassifications.map { classification in
      return [
        "identifier": classification.identifier,
        "confidence": classification.confidence
      ]
    }
    
    // 結果が空でも定期的にダミーデータを送信して継続性を保つ
    if classifications.isEmpty {
      let fallbackClassifications = [
        [
          "identifier": "background_noise",
          "confidence": 0.1
        ]
      ]
      DispatchQueue.main.async {
        self.methodChannel?.invokeMethod("onAudioClassification", arguments: fallbackClassifications)
      }
    } else {
      print("📱 Sending Sound Analysis results: \(classifications)")
      
      DispatchQueue.main.async {
        self.methodChannel?.invokeMethod("onAudioClassification", arguments: classifications)
      }
    }
  }
  
  func request(_ request: SNRequest, didFailWithError error: Error) {
    print("❌ Audio classification error: \(error)")
    DispatchQueue.main.async {
      self.methodChannel?.invokeMethod("onAudioClassificationError", arguments: error.localizedDescription)
    }
  }
  
  func requestDidComplete(_ request: SNRequest) {
    print("📱 Audio classification request completed")
  }
  
  deinit {
    print("📱 AudioClassificationObserver deallocated")
  }
}

