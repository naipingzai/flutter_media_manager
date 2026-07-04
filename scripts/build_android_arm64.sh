#!/bin/bash
# AdvanceMediaKB - Android 全架构构建脚本
# 构建所有 Android 架构的 Rust 库并打包 APK
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=========================================="
echo "  AdvanceMediaKB - Android 构建"
echo "=========================================="
echo "项目目录: $PROJECT_ROOT"
echo ""

export PATH="$PATH:/snap/bin"

# NDK 路径配置（优先使用 27.0，与 build.gradle 中 ndkVersion 匹配）
NDK_BASE=""
for ndk_ver in "27.0.12077973" "26.1.10909125"; do
    ndk_path="/usr/lib/android-sdk/ndk/$ndk_ver/toolchains/llvm/prebuilt/linux-x86_64"
    if [ -d "$ndk_path" ]; then
        NDK_BASE="$ndk_path"
        echo "使用 NDK: $ndk_ver"
        break
    fi
done

if [ -z "$NDK_BASE" ]; then
    echo "错误: 未找到 Android NDK，请安装 NDK 27.0 或 26.1"
    exit 1
fi

# 设置 Android 交叉编译环境变量
export CC_aarch64_linux_android="$NDK_BASE/bin/aarch64-linux-android35-clang"
export AR_aarch64_linux_android="$NDK_BASE/bin/llvm-ar"
export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$NDK_BASE/bin/aarch64-linux-android35-clang"
export CC_armv7_linux_androideabi="$NDK_BASE/bin/armv7a-linux-androideabi35-clang"
export AR_armv7_linux_androideabi="$NDK_BASE/bin/llvm-ar"
export CARGO_TARGET_ARMV7_LINUX_ANDROIDEABI_LINKER="$NDK_BASE/bin/armv7a-linux-androideabi35-clang"
export CC_x86_64_linux_android="$NDK_BASE/bin/x86_64-linux-android35-clang"
export AR_x86_64_linux_android="$NDK_BASE/bin/llvm-ar"
export CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER="$NDK_BASE/bin/x86_64-linux-android35-clang"
export CC_i686_linux_android="$NDK_BASE/bin/i686-linux-android35-clang"
export AR_i686_linux_android="$NDK_BASE/bin/llvm-ar"
export CARGO_TARGET_I686_LINUX_ANDROID_LINKER="$NDK_BASE/bin/i686-linux-android35-clang"

# 检查依赖
echo "[1/6] 检查构建依赖..."
command -v cargo >/dev/null 2>&1 || { echo "错误: 未找到 cargo"; exit 1; }
command -v flutter >/dev/null 2>&1 || { echo "错误: 未找到 flutter"; exit 1; }

# 2. 清理旧产物
echo "[2/6] 清理旧产物..."
rm -rf build/app

# 3. 重新生成 flutter_rust_bridge 绑定代码
echo "[3/6] 重新生成 Dart/Rust 绑定代码..."
if command -v flutter_rust_bridge_codegen >/dev/null 2>&1; then
    flutter_rust_bridge_codegen generate
    echo "  绑定代码已生成"
else
    echo "  警告: 未找到 flutter_rust_bridge_codegen，跳过代码生成"
fi

# 4. 构建 Android Rust 库（所有架构）
echo "[4/6] 构建 Rust 库..."

# 检测可用的 NDK clang API 级别
detect_clang_api() {
    local target_prefix="$1"
    for api in 35 34 33 32 31 30 29 28 27 26 25 24 23 21; do
        if [ -f "$NDK_BASE/bin/${target_prefix}${api}-clang" ]; then
            echo "$api"
            return 0
        fi
    done
    echo "24"  # fallback
}

API_LEVEL=$(detect_clang_api "aarch64-linux-android")
echo "  检测到 API 级别: $API_LEVEL"

# 更新环境变量使用正确的 API 级别
export CC_aarch64_linux_android="$NDK_BASE/bin/aarch64-linux-android${API_LEVEL}-clang"
export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$NDK_BASE/bin/aarch64-linux-android${API_LEVEL}-clang"
export CC_armv7_linux_androideabi="$NDK_BASE/bin/armv7a-linux-androideabi${API_LEVEL}-clang"
export CARGO_TARGET_ARMV7_LINUX_ANDROIDEABI_LINKER="$NDK_BASE/bin/armv7a-linux-androideabi${API_LEVEL}-clang"
export CC_x86_64_linux_android="$NDK_BASE/bin/x86_64-linux-android${API_LEVEL}-clang"
export CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER="$NDK_BASE/bin/x86_64-linux-android${API_LEVEL}-clang"
export CC_i686_linux_android="$NDK_BASE/bin/i686-linux-android${API_LEVEL}-clang"
export CARGO_TARGET_I686_LINUX_ANDROID_LINKER="$NDK_BASE/bin/i686-linux-android${API_LEVEL}-clang"

# 构建各架构
TARGETS=("aarch64-linux-android" "armv7-linux-androideabi" "x86_64-linux-android" "i686-linux-android")
JNI_DIRS=("arm64-v8a" "armeabi-v7a" "x86_64" "x86")

for i in "${!TARGETS[@]}"; do
    target="${TARGETS[$i]}"
    jni_dir="${JNI_DIRS[$i]}"
    echo "  构建 $target..."
    cargo build --release --target "$target" --manifest-path rust/Cargo.toml
    # 拷贝到 jniLibs
    mkdir -p "android/app/src/main/jniLibs/$jni_dir"
    cp "rust/target/$target/release/libadvance_media_kb.so" "android/app/src/main/jniLibs/$jni_dir/"
    echo "  已拷贝到 android/app/src/main/jniLibs/$jni_dir/"
done

# 5. 构建 Android APK
echo "[5/6] 构建 Android APK..."
flutter build apk --release

# 6. 验证产物
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK_PATH" ]; then
    echo ""
    echo "=========================================="
    echo "  构建成功!"
    echo "=========================================="
    echo "APK 位置: $APK_PATH"
    echo "APK 大小: $(du -h "$APK_PATH" | cut -f1)"
else
    echo ""
    echo "错误: APK 未生成!"
    exit 1
fi
