#!/bin/bash
######################################################################
# 文件坐标: scripts/build.sh
# 作用:     Flutter Media Knowledge Base 统一构建脚本
# 支持:     linux-x64, android-arm64
# 说明:     自动完成 C++ 原生库编译、产物拷贝、Flutter 打包等步骤
######################################################################

# --------------------------------------------------------------------
# 任何命令返回非零状态时立即退出脚本，防止错误继续传播
set -e
# 管道中任一命令失败即退出
set -o pipefail

# --------------------------------------------------------------------
# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --------------------------------------------------------------------
# 判断脚本位置：若位于 scripts/ 目录，则项目根目录为其父目录；
# 否则认为脚本本身就在项目根目录
if [ "$(basename "$SCRIPT_DIR")" = "scripts" ]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
    PROJECT_ROOT="$SCRIPT_DIR"
fi

# --------------------------------------------------------------------
# 后续所有路径都基于项目根目录
cd "$PROJECT_ROOT"

# --------------------------------------------------------------------
# 某些系统通过 snap 安装 flutter，需要额外 PATH
export PATH="$PATH:/snap/bin"

# --------------------------------------------------------------------
# RED=错误, GREEN=成功, YELLOW=警告, BLUE=信息, CYAN=标题
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'  # No Color，重置颜色

# --------------------------------------------------------------------
info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
err()   { echo -e "${RED}[ERROR]${NC} $1"; }
title() { echo -e "${CYAN}$1${NC}"; }

# --------------------------------------------------------------------
OUT_DIR="out"

# --------------------------------------------------------------------
CPP_BUILD_DIR="native/build"

# --------------------------------------------------------------------
SO_NAME="libadvance_media_kb.so"

# --------------------------------------------------------------------
show_help() {
    echo "用法: $0 <target>"
    echo ""
    echo "  linux-x64       Linux x86_64 桌面应用"
    echo "  android-arm64   Android ARM64 APK"
    echo "  all             当前系统所有目标"
}

# --------------------------------------------------------------------
# 根据 target 参数选择 CMake 工具链
build_cpp() {
    local target="${1:-linux-x64}"

    info "构建 C++ 原生库: $target"

    case "$target" in
        # -----------------------------------------------------------
        linux-x64)
            # tail -n 2 只显示最后两行，减少输出
            cmake -S native -B "$CPP_BUILD_DIR" -DCMAKE_BUILD_TYPE=Release 2>&1 | tail -n 2

            cmake --build "$CPP_BUILD_DIR" -- -j$(nproc) 2>&1 | tail -n 5
            ;;

        # -----------------------------------------------------------
        android-arm64)
            # 优先使用环境变量 ANDROID_NDK_HOME，否则使用默认路径
            local ndk_root="${ANDROID_NDK_HOME:-/usr/lib/android-sdk/ndk/27.0.12077973}"

            cmake -S native -B "$CPP_BUILD_DIR/android-arm64" \
                -DCMAKE_BUILD_TYPE=Release \
                -DCMAKE_TOOLCHAIN_FILE="$ndk_root/build/cmake/android.toolchain.cmake" \
                -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-21 2>&1 | tail -n 2

            cmake --build "$CPP_BUILD_DIR/android-arm64" -- -j$(nproc) 2>&1 | tail -n 5
            ;;
    esac

    ok "C++ 库构建完成"
}

# --------------------------------------------------------------------
build_linux_x64() {
    title "=== 构建 Linux x64 ==="

    build_cpp "linux-x64"

    local dest="build/linux/x64/release/native_build"

    mkdir -p "$dest"

    cp "$CPP_BUILD_DIR/$SO_NAME" "$dest/"

    ok "预置 C++ 库到: $dest/$SO_NAME"

    # 显式指定 GCC 14 以解决 Ubuntu 24.04 默认 GCC 版本兼容问题
    CC=/usr/bin/gcc-14 CXX=/usr/bin/g++-14 flutter build linux --release

    mkdir -p "$OUT_DIR/linux-x64"

    cp -r build/linux/x64/release/bundle/* "$OUT_DIR/linux-x64/"

    ok "产物: $OUT_DIR/linux-x64/"
}

# --------------------------------------------------------------------
build_android_arm64() {
    title "=== 构建 Android ARM64 ==="

    build_cpp "android-arm64"

    local jni_dir="android/app/src/main/jniLibs/arm64-v8a"

    mkdir -p "$jni_dir"

    cp "$CPP_BUILD_DIR/android-arm64/$SO_NAME" "$jni_dir/"

    ok "C++ 库已拷贝到 jniLibs/arm64-v8a/"

    flutter build apk --release --target-platform android-arm64

    mkdir -p "$OUT_DIR/android-arm64"

    cp build/app/outputs/flutter-apk/app-release.apk "$OUT_DIR/android-arm64/"

    ok "APK: $OUT_DIR/android-arm64/app-release.apk"

    ls -lh "$OUT_DIR/android-arm64/app-release.apk"
}

# ====================================================================
# 脚本主入口
# ====================================================================

if [ $# -eq 0 ]; then show_help; exit 0; fi

case "$1" in
    -h|--help|help)
        show_help; exit 0
        ;;
    linux-x64)
        build_linux_x64
        ;;
    android-arm64)
        build_android_arm64
        ;;
    all)
        build_linux_x64
        build_android_arm64
        ;;
    *)
        err "未知目标: $1"
        show_help
        exit 1
        ;;
esac
