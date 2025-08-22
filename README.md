# EMG Mobile Analyzer

## セットアップ

### スクリプトの実行権限を付与

初回のみ、ビルドスクリプトに実行権限を付与する必要があります：

```bash
chmod +x ios-sim ios-dev
```

## ビルドと実行

### iOS Simulator用

プロジェクトのどのディレクトリからでも実行可能：

```bash
./ios-sim
```

### iOS実機用

プロジェクトのどのディレクトリからでも実行可能：

```bash
./ios-dev
```

## 手動ビルド（上級者向け）

### C++ Nativeの手動ビルド
#### ios
``` bash
mkdir native/build 
cd native/build 
```
- simulator用ビルド

```bash
cmake .. -G "Xcode" \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  -DCMAKE_OSX_SYSROOT=iphonesimulator \
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO && \
cmake --build . --config Release && \
cp -r Release-iphonesimulator/native_engine.framework ../../ios/Frameworks/
```

- ios実機用
```bash 
cmake .. -G "Xcode" \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_ARCHITECTURES="arm64;arm64" \
  -DCMAKE_OSX_SYSROOT=iphoneos \
  -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO && \
cmake --build . --config Release && \
cp -r Release-iphoneos/native_engine.framework ../../ios/Frameworks/
```