import Flutter
import UIKit
import CoreML

final class EmgMlPlugin: NSObject, FlutterPlugin {

  // 現在メモリにロードされているモデルと、その .mlmodelc の場所を保持
  private var model: MLModel? = nil
  private var compiledModelURL: URL? = nil

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
    case "train":
      handleTrain(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // モデルロード: Flutter から渡された .mlmodel を .mlmodelc にコンパイルして読み込む
  private func handleLoadModel(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let bytes = args["bytes"] as? FlutterStandardTypedData
    else {
      result(FlutterError(code: "bad_args", message: "missing bytes", details: nil))
      return
    }

    do {
      //  tmp に .mlmodel を書き出す（binaryMessenger から届くのは raw bytes）
      let dir = FileManager.default.temporaryDirectory
      let mlmodelURL = dir.appendingPathComponent("UpdatableClassifier_trained_emg.mlmodel")
      try bytes.data.write(to: mlmodelURL, options: .atomic)

      //  .mlmodel -> .mlmodelc にコンパイル
      let compiledURL = try MLModel.compileModel(at: mlmodelURL)

      // 永続パス（ApplicationSupport）に move して常に同じ場所を参照する
      // 学習時もこのパスを基準にするため、毎回同じ場所に配置しておく
      let supportDir = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
      )
      let persistentCompiledURL = supportDir.appendingPathComponent("UpdatableClassifier_trained_emg.mlmodelc")

      if FileManager.default.fileExists(atPath: persistentCompiledURL.path) {
        try FileManager.default.removeItem(at: persistentCompiledURL)
      }
      try FileManager.default.moveItem(at: compiledURL, to: persistentCompiledURL)

      // Load
      let config = MLModelConfiguration()
      config.computeUnits = .all // Neural Engine を使えるなら使う（可能な範囲で）
      self.model = try MLModel(contentsOf: persistentCompiledURL, configuration: config)
      self.compiledModelURL = persistentCompiledURL

      result(true)
    } catch {
      result(FlutterError(code: "load_failed", message: "\(error)", details: nil))
    }
  }

  // 推論: 10次元特徴量を受け取り、classProbability を labels の順序で並べ直す
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

      // Core ML の出力は multiArray もしくは dictionary のどちらかで返る
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

  // on-device 学習: Core ML のアップデート API を呼び出し、更新後モデルを永続化
  private func handleTrain(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let baseURL = compiledModelURL, let _ = self.model else {
      result(FlutterError(code: "not_ready", message: "model not loaded", details: nil))
      return
    }

    guard let args = call.arguments as? [String: Any],
          let sampleDicts = args["samples"] as? [[String: Any]],
          !sampleDicts.isEmpty else {
      result(FlutterError(code: "bad_args", message: "samples (non-empty) is required", details: nil))
      return
    }

    var providers: [MLFeatureProvider] = []
    providers.reserveCapacity(sampleDicts.count)

    for (idx, row) in sampleDicts.enumerated() {
      guard let feats = row["features"] as? [NSNumber], feats.count == 10 else {
        result(FlutterError(code: "bad_args", message: "samples[\(idx)] features must be length 10", details: nil))
        return
      }

      // labelIndex または classLabel(string) のどちらかで指定
      var label: String?
      if let labelIndex = row["labelIndex"] as? Int, labelIndex >= 0, labelIndex < labels.count {
        label = labels[labelIndex]
      } else if let labelName = row["classLabel"] as? String {
        label = labelName
      }

      guard let classLabel = label else {
        result(FlutterError(code: "bad_args", message: "samples[\(idx)] missing labelIndex/classLabel", details: nil))
        return
      }

      do {
        let x = try MLMultiArray(shape: [10], dataType: .double)
        for i in 0..<10 { x[i] = feats[i] }
        let fp = LabeledFeatureProvider(features: x, classLabel: classLabel)
        providers.append(fp)
      } catch {
        result(FlutterError(code: "make_array_failed", message: "\(error)", details: nil))
        return
      }
    }

    let batchProvider = MLArrayBatchProvider(array: providers)

    let config = MLModelConfiguration()
    config.computeUnits = .all

    // Core ML のアップデートは「書き込み可能な .mlmodelc」が必要。
    // ApplicationSupport 上の本体を直接渡すとロック・上書き競合を起こすので、
    // 毎回 tmp にコピーしたものをベースとして渡す。
    let tempBaseURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("UpdatableClassifier_train_base.mlmodelc", isDirectory: true)
    if FileManager.default.fileExists(atPath: tempBaseURL.path) {
      try? FileManager.default.removeItem(at: tempBaseURL)
    }
    do {
      try FileManager.default.copyItem(at: baseURL, to: tempBaseURL)
    } catch {
      result(FlutterError(code: "train_failed", message: "failed to prepare temp model: \(error)", details: nil))
      return
    }

    let handlers = MLUpdateProgressHandlers(
      forEvents: [.trainingBegin, .epochEnd],
      progressHandler: { _ in },
      completionHandler: { [weak self] context in
        if let err = context.task.error {
          result(FlutterError(code: "train_failed", message: "\(err)", details: nil))
          return
        }

        guard let self = self else { return }
        let updatedModel = context.model

        do {
          let supportDir = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
          )

          let modelDir = supportDir.appendingPathComponent("EmgModels", isDirectory: true)
          try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)

          // Core ML は .mlmodelc をディレクトリとして扱う。安全のため temp に書き出し、move で置換。
          let tempSaveURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("UpdatableClassifier_trained_emg_tmp.mlmodelc", isDirectory: true)
          let finalSaveURL = modelDir.appendingPathComponent(
            "UpdatableClassifier_trained_emg.mlmodelc",
            isDirectory: true
          )

          // 既存 temp を掃除
          if FileManager.default.fileExists(atPath: tempSaveURL.path) {
            try FileManager.default.removeItem(at: tempSaveURL)
          }
          // 既存 final は後で move で上書きされる（atomic に近い形）
          if FileManager.default.fileExists(atPath: finalSaveURL.path) {
            try FileManager.default.removeItem(at: finalSaveURL)
          }

          try updatedModel.write(to: tempSaveURL)

          // ディレクトリとして move（copy ではなく）することで「ディレクトリをディレクトリにコピー」問題を回避
          try FileManager.default.moveItem(at: tempSaveURL, to: finalSaveURL)

          let reloaded = try MLModel(contentsOf: finalSaveURL, configuration: config)
          self.model = reloaded
          self.compiledModelURL = finalSaveURL

          result([
            "updatedModelPath": finalSaveURL.path,
            "sampleCount": providers.count
          ])
        } catch {
          self.model = updatedModel
          let ns = error as NSError
          result(FlutterError(code: "train_save_failed", message: "\(ns)", details: ns.userInfo))
        }
      }
    )

    do {
      let task = try MLUpdateTask(
        forModelAt: tempBaseURL,
        trainingData: batchProvider,
        configuration: config,
        progressHandlers: handlers
      )
      task.resume()
    } catch {
      if #available(iOS 13.0, *) {
        result(FlutterError(code: "train_failed", message: "\(error)", details: nil))
      } else {
        result(FlutterError(code: "unsupported", message: "requires iOS 13+", details: nil))
      }
    }
  }
}

// ===== Helper =====
// Core ML へ特徴量 + クラスラベルを渡すためのラッパー
private final class LabeledFeatureProvider: MLFeatureProvider {
  let features: MLMultiArray
  let classLabel: String

  init(features: MLMultiArray, classLabel: String) {
    self.features = features
    self.classLabel = classLabel
  }

  var featureNames: Set<String> {
    return ["features", "classLabel"]
  }

  func featureValue(for featureName: String) -> MLFeatureValue? {
    switch featureName {
    case "features":
      return MLFeatureValue(multiArray: features)
    case "classLabel":
      return MLFeatureValue(string: classLabel)
    default:
      return nil
    }
  }
}
