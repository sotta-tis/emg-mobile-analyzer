## C++ Nativeのビルド
### ios
``` bash
mkdir native/build 
cd native/build 
```
- simulator用ビルド

```
cmake .. -G "Xcode" -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" -DCMAKE_OSX_SYSROOT=iphonesimulator -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO
```

- cmake
```
cmake --build . --config Release
```