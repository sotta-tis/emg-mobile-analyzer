## C++ Nativeのビルド
### ios
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