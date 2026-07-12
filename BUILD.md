# Flutter Media Knowledge Base - 构建指南

本文件详细说明如何在 Linux 桌面和 Android 平台构建本项目。

## 项目结构

```
flutter_media_knowledge_base/
├── android/              # Android 平台配置
├── lib/                  # Flutter / Dart 源码
│   ├── bridge/native/    # Dart FFI 桥接层
│   ├── core/             # 主题、导航、国际化、权限
│   ├── functionality/    # BLoC 状态管理
│   └── ui/               # 页面和组件
├── linux/                # Linux 平台配置
├── native/               # C++ 原生代码
│   ├── src/              # database.h / database.cpp / ffi_bridge.cpp
│   └── third_party/      # sqlite3.c 单文件数据库
├── out/                  # 构建产物（被 .gitignore 忽略）
└── scripts/
    └── build.sh          # 统一构建脚本
```

## 依赖环境

### 通用依赖

1. Flutter SDK（推荐 3.24.x 或更高，Dart ^3.5.4）
2. CMake >= 3.10
3. C++ 编译器（GCC 14 / Clang）

### Android 依赖

1. Android SDK
2. Android NDK（推荐 r27：`/usr/lib/android-sdk/ndk/27.0.12077973`）
   - 可通过环境变量 `ANDROID_NDK_HOME` 自定义路径
3. 在 Android SDK 中安装 `cmdline-tools`、`platform-tools`、`build-tools`

### Linux 依赖

1. GTK 开发库（`libgtk-3-dev`）
2. CMake
3. ninja-build（可选）

安装示例（Ubuntu/Debian）：

```bash
sudo apt update
sudo apt install -y cmake ninja-build clang \
    libgtk-3-dev pkg-config libblkid-dev liblzma-dev \
    libsqlite3-dev
```

## Linux 构建方法

### 方法 A：使用统一脚本（推荐）

```bash
./scripts/build.sh linux-x64
```

脚本执行流程：

1. 使用 CMake 配置并编译 `native/CMakeLists.txt`
2. 生成 `native/build/libadvance_media_kb.so`
3. 将 `.so` 复制到 `build/linux/x64/release/native_build/`
4. 调用 `flutter build linux --release` 打包
5. 产物输出到 `out/linux-x64/`

### 方法 B：手动构建

```bash
# 1. 编译 C++ 原生库
cmake -S native -B native/build -DCMAKE_BUILD_TYPE=Release
cmake --build native/build -- -j$(nproc)

# 2. 预置 .so 到 Flutter 构建目录
mkdir -p build/linux/x64/release/native_build
cp native/build/libadvance_media_kb.so build/linux/x64/release/native_build/

# 3. 构建 Linux 桌面应用
flutter build linux --release

# 4. 收集产物
mkdir -p out/linux-x64
cp -r build/linux/x64/release/bundle/* out/linux-x64/
```

### Linux 运行

```bash
./out/linux-x64/flutter_media_knowledge_base
```

或直接在 `build/linux/x64/release/bundle/` 目录运行。

## Android 构建方法

### 方法 A：使用统一脚本（推荐）

```bash
./scripts/build.sh android-arm64
```

脚本执行流程：

1. 使用 Android NDK 工具链编译 C++ 库
2. 生成 `native/build/android-arm64/libadvance_media_kb.so`
3. 将 `.so` 复制到 `android/app/src/main/jniLibs/arm64-v8a/`
4. 调用 `flutter build apk --release --target-platform android-arm64`
5. 产物 APK 输出到 `out/android-arm64/app-release.apk`

### 方法 B：手动构建

```bash
# 设置 NDK 路径
export ANDROID_NDK_HOME=/usr/lib/android-sdk/ndk/27.0.12077973

# 1. 交叉编译 C++ 库
cmake -S native \
    -B native/build/android-arm64 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-21

cmake --build native/build/android-arm64 -- -j$(nproc)

# 2. 安装 .so 到 jniLibs
mkdir -p android/app/src/main/jniLibs/arm64-v8a
cp native/build/android-arm64/libadvance_media_kb.so \
   android/app/src/main/jniLibs/arm64-v8a/

# 3. 构建 APK
flutter build apk --release --target-platform android-arm64

# 4. 收集产物
mkdir -p out/android-arm64
cp build/app/outputs/flutter-apk/app-release.apk out/android-arm64/
```

### Android 安装

```bash
adb install out/android-arm64/app-release.apk
```

## 构建脚本参数

```bash
./scripts/build.sh <target>
```

可选 `<target>`：

| 参数 | 说明 |
| --- | --- |
| `linux-x64` | 构建 Linux x64 桌面应用 |
| `android-arm64` | 构建 Android ARM64 APK |
| `all` | 依次构建 Linux 和 Android |
| `-h` / `--help` / `help` | 显示帮助 |

## 常见问题

### 1. `unable to find library -lpthread`

**原因**：Android NDK 工具链中已经包含 pthread 支持，不需要显式链接 `pthread`。  
**解决**：确保 `native/CMakeLists.txt` 中只在非 Android 平台链接 `pthread`：

```cmake
if(NOT ANDROID)
    target_link_libraries(advance_media_kb PRIVATE pthread dl m)
endif()
if(ANDROID)
    target_link_libraries(advance_media_kb PRIVATE log)
endif()
```

### 2. 找不到 NDK 路径

**解决**：设置环境变量 `ANDROID_NDK_HOME`，或修改 `scripts/build.sh` 中的默认路径。

### 3. Flutter 找不到 libadvance_media_kb.so

**原因**：Linux 构建需要在 `flutter build` 前将 `.so` 放到 `build/linux/x64/release/native_build/`。  
**解决**：运行脚本会自动复制，手动构建时不要跳过第 2 步。

### 4. Dart FFI 符号未找到

**原因**：Dart 侧期望的 C 函数签名与 C++ 导出不一致。  
**解决**：检查 `native/src/ffi_bridge.cpp` 中导出函数是否使用了 `extern "C"`，并且函数名与 Dart `DynamicLibrary.lookup` 完全一致。

## 清理

```bash
rm -rf build/ out/ .dart_tool/ .flutter-plugins .flutter-plugins-dependencies
rm -rf native/build
rm -rf android/app/src/main/jniLibs/
```

然后重新运行构建脚本。
