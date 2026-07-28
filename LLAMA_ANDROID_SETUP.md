# llamo.cpp Android Native Integration Guide

## 编译 llama.cpp for Android

### 前置条件
- Android NDK r25+
- CMake 3.18+

### 步骤

1. 克隆 llama.cpp:
```bash
cd /tmp
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp
```

2. 编译 Android arm64-v8a:
```bash
mkdir build-android-arm64 && cd build-android-arm64
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-26 \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=ON \
  -DLLAMA_BUILD_TESTS=OFF \
  -DLLAMA_BUILD_EXAMPLES=OFF
make -j$(nproc)
```

3. 复制产物:
```bash
cp libllama.so /path/to/local_ai_assistant/android/app/src/main/jniLibs/arm64-v8a/
```

4. armeabi-v7a（32位ARM）类似流程，替换 `-DANDROID_ABI=armeabi-v7a`

## Dart FFI 绑定

已在 `lib/services/llm_service.dart` 的 `LlamaCppService` 中实现，关键代码:

```dart
final DynamicLibrary _lib = DynamicLibrary.open('libllama.so');

// 绑定关键函数
final _llamaInitBackend = _lib.lookupFunction<Void Function(), void Function()>('llama_backend_init');
final _llamaModelLoad = _lib.lookupFunction<IntPtr Function(Pointer<Utf8>, Int32), 
    int Function(Pointer<Utf8>, int)>('llama_load_model_from_file');
// ... 更多绑定见 llm_service.dart
```

## 模型文件放置

模型GGUF文件放在 `assets/models/` 目录下，首次运行时自动复制到应用私有目录。
