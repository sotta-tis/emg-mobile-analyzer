import Flutter
import UIKit
import CoreML

final class EmgMlPlugin: NSObject, FlutterPlugin {

  private var model: MLModel? = nil

  // ラベル順は「学習に使った順」と一致させる（paper/cizer/rock/pinchなど）
  // ※ train_offline.py の --labels に渡した順番と同じにする
  private let labels: [String] = ["paper", "cizer", "rock", "pinch"]

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "emg_ml", binaryMessenger: registrar.messenger())
    let instance = EmgMlPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  // MethodChannelのハンドラ登録
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "loadModel":
      handleLoadModel(call, result: result)
    case "predict":
      handlePredict(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // modelのload
  private func handleLoadModel(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let bytes = args["bytes"] as? FlutterStandardTypedData
    else {
      result(FlutterError(code: "bad_args", message: "missing bytes", details: nil))
      return
    }

    do {
      // 1) Documents/tmpに .mlmodel を保存
      let dir = FileManager.default.temporaryDirectory
      let mlmodelURL = dir.appendingPathComponent("UpdatableClassifier_trained_emg.mlmodel")
      try bytes.data.write(to: mlmodelURL, options: .atomic)

      // 2) .mlmodel -> .mlmodelc にコンパイル
      let compiledURL = try MLModel.compileModel(at: mlmodelURL)

      // 3) Load
      let config = MLModelConfiguration()
      config.computeUnits = .all // Neural Engine を使えるなら使う（可能な範囲で）
      self.model = try MLModel(contentsOf: compiledURL, configuration: config)

      result(true)
    } catch {
      result(FlutterError(code: "load_failed", message: "\(error)", details: nil))
    }
  }

  // 推論メンバ
  private func handlePredict(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let model = self.model else {
      result(FlutterError(code: "not_ready", message: "model not loaded", details: nil))
      return
    }
    guard let args = call.arguments as? [String: Any],
          let features = args["features"] as? [NSNumber],
          features.count == 10
    else {
      result(FlutterError(code: "bad_args", message: "features must be length 10", details: nil))
      return
    }

    do {
      // 入力 "features": MLMultiArray(10)
      let x = try MLMultiArray(shape: [10], dataType: .double)
      for i in 0..<10 { x[i] = features[i] }

      // ここは CoreMLモデルの input name に合わせる：model.py で input_name="features"
      let input = try MLDictionaryFeatureProvider(dictionary: ["features": x])

      let out = try model.prediction(from: input)

      var scores: [Double] = []
      if let probArray = out.featureValue(for: "classProbability")?.multiArrayValue {
        scores.reserveCapacity(probArray.count)
        for i in 0..<probArray.count {
          scores.append(probArray[i].doubleValue)
        }
      } else if let probDict = out.featureValue(for: "classProbability")?.dictionaryValue {
        // ラベル順に並べる
        scores = labels.map { probDict[$0]?.doubleValue ?? 0.0 }
      } else {
        result(FlutterError(code: "bad_output", message: "missing classProbability", details: nil))
        return
      }

      // argmax
      var bestIdx = 0
      var bestVal = scores[0]
      for i in 1..<scores.count {
        if scores[i] > bestVal {
          bestVal = scores[i]
          bestIdx = i
        }
      }

      result([
        "labelIndex": bestIdx,
        "scores": scores
      ])
    } catch {
      result(FlutterError(code: "predict_failed", message: "\(error)", details: nil))
    }
  }
}
