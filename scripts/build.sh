#!/bin/bash
######################################################################
# AdvanceMediaKB - 统一全平台构建脚本
#
# 用法:
#   ./scripts/build.sh <target>
#   ./scripts/build.sh list              # 列出所有支持的构建目标
#   ./scripts/build.sh linux-x64         # Linux x86_64 桌面应用
#   ./scripts/build.sh android-arm64     # Android ARM64 (arm64-v8a) APK
#   ./scripts/build.sh android-x64       # Android x86_64 APK
#   ./scripts/build.sh windows-x64       # Windows x64 (交叉编译 Rust DLL)
#   ./scripts/build.sh macos-arm64       # macOS ARM64 (Apple Silicon)
#   ./scripts/build.sh macos-universal   # macOS Universal Binary
#   ./scripts/build.sh ios-arm64         # iOS ARM64
#   ./scripts/build.sh web               # Web 应用
#   ./scripts/build.sh all               # 当前系统支持的所有目标
#
# 产物统一输出到 out/<target>/ 目录
#
######################################################################
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

export PATH="$PATH:/snap/bin"

# ================================================================
#  颜色输出
# ================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
err()   { echo -e "${RED}[ERROR]${NC} $1"; }
title() { echo -e "${CYAN}$1${NC}"; }

# ================================================================
#  全局变量
# ================================================================
RUST_MANIFEST="rust/Cargo.toml"
RUST_LIB_NAME="advance_media_kb"
RUST_SO="lib${RUST_LIB_NAME}.so"
RUST_DLL="${RUST_LIB_NAME}.dll"
RUST_DYLIB="lib${RUST_LIB_NAME}.dylib"
CPP_NATIVE_DIR="native"
CPP_BUILD_DIR="native/build"
OUT_DIR="out"

# NDK 配置
NDK_BASE=""
NDK_API_LEVEL=""

# ================================================================
#  支持的目标定义（去除老旧平台）
# ================================================================
declare -A TARGET_INFO
declare -A TARGET_RUST_TRIPLE

TARGET_INFO[linux-x64]="Linux x86_64 桌面应用"
TARGET_RUST_TRIPLE[linux-x64]="x86_64-unknown-linux-gnu"

TARGET_INFO[android-arm64]="Android ARM64 (arm64-v8a)"
TARGET_RUST_TRIPLE[android-arm64]="aarch64-linux-android"

TARGET_INFO[android-x64]="Android x86_64 (模拟器)"
TARGET_RUST_TRIPLE[android-x64]="x86_64-linux-android"

TARGET_INFO[windows-x64]="Windows x86_64 (交叉编译 Rust DLL)"
TARGET_RUST_TRIPLE[windows-x64]="x86_64-pc-windows-gnu"

TARGET_INFO[macos-arm64]="macOS ARM64 (Apple Silicon)"
TARGET_RUST_TRIPLE[macos-arm64]="aarch64-apple-darwin"

TARGET_INFO[macos-x64]="macOS x86_64"
TARGET_RUST_TRIPLE[macos-x64]="x86_64-apple-darwin"

TARGET_INFO[macos-universal]="macOS Universal Binary (x86_64 + ARM64)"
TARGET_RUST_TRIPLE[macos-universal]="universal"

TARGET_INFO[ios-arm64]="iOS ARM64"
TARGET_RUST_TRIPLE[ios-arm64]="aarch64-apple-ios"

TARGET_INFO[web]="Web (Flutter Web, 不支持 Rust FFI)"
TARGET_RUST_TRIPLE[web]="web"

# 所有单目标列表（用于帮助显示）
ALL_TARGETS="linux-x64 android-arm64 android-x64 windows-x64 macos-arm64 macos-x64 macos-universal ios-arm64 web"

# ================================================================
#  辅助函数
# ================================================================

show_help() {
    title "=========================================="
    title "  AdvanceMediaKB - 统一构建脚本"
    title "=========================================="
    echo ""
    echo "用法: $0 <target>"
    echo ""
    echo "支持的构建目标:"
    for key in $ALL_TARGETS; do
        printf "  ${GREEN}%-20s${NC} %s\n" "$key" "${TARGET_INFO[$key]}"
    done
    echo ""
    echo "组合目标:"
    printf "  ${GREEN}%-20s${NC} %s\n" "android-all"   "Android 全架构 (arm64 + x64)"
    printf "  ${GREEN}%-20s${NC} %s\n" "desktop-all"   "桌面平台 (linux-x64 + windows-x64)"
    printf "  ${GREEN}%-20s${NC} %s\n" "mobile-all"    "移动平台 (android + ios)"
    printf "  ${GREEN}%-20s${NC} %s\n" "all"           "当前系统可构建的所有目标"
    echo ""
    echo "产物目录: out/<target>/"
    echo ""
    echo "示例:"
    echo "  $0 linux-x64       # 构建 Linux x64"
    echo "  $0 android-arm64   # 构建 Android ARM64 APK"
    echo "  $0 web             # 构建 Web 应用"
    echo "  $0 all             # 构建当前系统所有目标"
}

# 检查基本依赖
check_base_deps() {
    info "检查基本构建依赖..."
    command -v cargo >/dev/null 2>&1 || { err "未找到 cargo (Rust)"; exit 1; }
    command -v flutter >/dev/null 2>&1 || { err "未找到 flutter"; exit 1; }
    ok "基本依赖检查通过"
}

# 初始化 Android NDK
init_ndk() {
    if [ -n "$NDK_BASE" ]; then return 0; fi

    info "初始化 Android NDK..."
    for ndk_ver in "27.0.12077973" "26.1.10909125"; do
        ndk_path="/usr/lib/android-sdk/ndk/$ndk_ver/toolchains/llvm/prebuilt/linux-x86_64"
        if [ -d "$ndk_path" ]; then
            NDK_BASE="$ndk_path"
            info "使用 NDK: $ndk_ver"
            break
        fi
    done

    if [ -z "$NDK_BASE" ]; then
        err "未找到 Android NDK"
        exit 1
    fi

    for api in 35 34 33 32 31 30 29 28 27 26 25 24; do
        if [ -f "$NDK_BASE/bin/aarch64-linux-android${api}-clang" ]; then
            NDK_API_LEVEL="$api"
            info "NDK API 级别: $api"
            break
        fi
    done
    NDK_API_LEVEL="${NDK_API_LEVEL:-24}"
}

# 设置 Android 交叉编译环境变量
set_android_env() {
    local rust_target="$1"
    init_ndk

    case "$rust_target" in
        aarch64-linux-android)
            export CC_aarch64_linux_android="$NDK_BASE/bin/aarch64-linux-android${NDK_API_LEVEL}-clang"
            export AR_aarch64_linux_android="$NDK_BASE/bin/llvm-ar"
            export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="$NDK_BASE/bin/aarch64-linux-android${NDK_API_LEVEL}-clang"
            ;;
        x86_64-linux-android)
            export CC_x86_64_linux_android="$NDK_BASE/bin/x86_64-linux-android${NDK_API_LEVEL}-clang"
            export AR_x86_64_linux_android="$NDK_BASE/bin/llvm-ar"
            export CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER="$NDK_BASE/bin/x86_64-linux-android${NDK_API_LEVEL}-clang"
            ;;
    esac
}

# 清除交叉编译环境变量
clean_cross_compile_env() {
    unset PKG_CONFIG_PATH PKG_CONFIG_LIBDIR PKG_CONFIG_SYSROOT_DIR
    unset FLUTTER_TARGET_PLATFORM_SYSROOT
    unset CC_aarch64_linux_android AR_aarch64_linux_android CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER
    unset CC_armv7_linux_androideabi AR_armv7_linux_androideabi CARGO_TARGET_ARMV7_LINUX_ANDROIDEABI_LINKER
    unset CC_x86_64_linux_android AR_x86_64_linux_android CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER
    unset CC_i686_linux_android AR_i686_linux_android CARGO_TARGET_I686_LINUX_ANDROID_LINKER
}

# 生成 flutter_rust_bridge 绑定代码
generate_bindings() {
    info "生成 Dart/Rust 绑定代码..."
    if command -v flutter_rust_bridge_codegen >/dev/null 2>&1; then
        flutter_rust_bridge_codegen generate
        ok "绑定代码已生成"
    else
        warn "未找到 flutter_rust_bridge_codegen，使用已有绑定代码"
    fi
}

# 构建 Rust 库
build_rust_lib() {
    local rust_target="$1"
    info "构建 Rust 库: $rust_target"

    if [ "$rust_target" = "x86_64-unknown-linux-gnu" ]; then
        cargo build --release --manifest-path "$RUST_MANIFEST"
    else
        cargo build --release --target "$rust_target" --manifest-path "$RUST_MANIFEST"
    fi
    ok "Rust 库构建完成: $rust_target"
}

# 构建 C++ 原生库
build_cpp_lib() {
    local target="${1:-linux-x64}"
    info "构建 C++ 原生库: $target"

    case "$target" in
        linux-x64)
            mkdir -p "$CPP_BUILD_DIR"
            cmake -S "$CPP_NATIVE_DIR" -B "$CPP_BUILD_DIR" -DCMAKE_BUILD_TYPE=Release
            cmake --build "$CPP_BUILD_DIR" -- -j$(nproc)
            ok "C++ 库构建完成 (Linux x64)"
            ;;
        android-arm64)
            if [ -z "$ANDROID_NDK_HOME" ] && [ -z "$NDK_BASE" ]; then
                err "未设置 ANDROID_NDK_HOME 或 NDK_BASE"; return 1
            fi
            local ndk_root="${ANDROID_NDK_HOME:-/usr/lib/android-sdk/ndk/27.0.12077973}"
            mkdir -p "$CPP_BUILD_DIR/android-arm64"
            cmake -S "$CPP_NATIVE_DIR" -B "$CPP_BUILD_DIR/android-arm64" \
                -DCMAKE_BUILD_TYPE=Release \
                -DCMAKE_TOOLCHAIN_FILE="$ndk_root/build/cmake/android.toolchain.cmake" \
                -DANDROID_ABI=arm64-v8a \
                -DANDROID_PLATFORM=android-21
            cmake --build "$CPP_BUILD_DIR/android-arm64" -- -j$(nproc)
            ok "C++ 库构建完成 (Android ARM64)"
            ;;
        android-x64)
            if [ -z "$ANDROID_NDK_HOME" ] && [ -z "$NDK_BASE" ]; then
                err "未设置 ANDROID_NDK_HOME 或 NDK_BASE"; return 1
            fi
            local ndk_root="${ANDROID_NDK_HOME:-/usr/lib/android-sdk/ndk/27.0.12077973}"
            mkdir -p "$CPP_BUILD_DIR/android-x64"
            cmake -S "$CPP_NATIVE_DIR" -B "$CPP_BUILD_DIR/android-x64" \
                -DCMAKE_BUILD_TYPE=Release \
                -DCMAKE_TOOLCHAIN_FILE="$ndk_root/build/cmake/android.toolchain.cmake" \
                -DANDROID_ABI=x86_64 \
                -DANDROID_PLATFORM=android-21
            cmake --build "$CPP_BUILD_DIR/android-x64" -- -j$(nproc)
            ok "C++ 库构建完成 (Android x64)"
            ;;
        web)
            info "Web 平台不需要 C++ 库"
            ;;
    esac
}

# 获取 Rust 库路径
get_rust_lib_path() {
    local rust_target="$1"
    if [ "$rust_target" = "x86_64-unknown-linux-gnu" ]; then
        echo "rust/target/release"
    else
        echo "rust/target/$rust_target/release"
    fi
}

# 清理 Flutter 构建中间产物
clean_flutter_build() {
    local target="$1"
    case "$target" in
        linux-x64|linux-*)         rm -rf build/linux ;;
        android-arm64|android-*)   rm -rf build/app ;;
        web)                       rm -rf build/web ;;
    esac
}

# 清理 Rust 构建中间产物（保留 release 产物）
clean_rust_intermediates() {
    info "清理 Rust 构建中间产物..."
    # 只清理增量编译的中间文件，不清理最终产物
    find rust/target -name "*.d" -type f -delete 2>/dev/null || true
    find rust/target -name "*.fingerprint" -type d -exec rm -rf {} + 2>/dev/null || true
    find rust/target -name "build" -type d -exec rm -rf {} + 2>/dev/null || true
    find rust/target -name "deps" -type d -exec rm -rf {} + 2>/dev/null || true
    find rust/target -name "incremental" -type d -exec rm -rf {} + 2>/dev/null || true
    ok "Rust 中间产物已清理"
}

# 拷贝产物到 out/<target>/
copy_artifacts() {
    local target="$1"
    local out_path="$OUT_DIR/$target"
    mkdir -p "$out_path"

    case "$target" in
        linux-x64)
            cp -r build/linux/x64/release/bundle/* "$out_path/"
            ok "产物已拷贝到: $out_path/"
            info "可执行文件: $out_path/advance_media_kb"
            ;;
        android-arm64|android-x64)
            cp build/app/outputs/flutter-apk/app-release.apk "$out_path/" 2>/dev/null || true
            # 也拷贝 .so 文件
            local rust_triple="${TARGET_RUST_TRIPLE[$target]}"
            local lib_path
            lib_path="$(get_rust_lib_path "$rust_triple")/$RUST_SO"
            if [ -f "$lib_path" ]; then
                cp "$lib_path" "$out_path/"
            fi
            ok "产物已拷贝到: $out_path/"
            ls -lh "$out_path/"
            ;;
        windows-x64)
            local rust_triple="${TARGET_RUST_TRIPLE[$target]}"
            local lib_path
            lib_path="$(get_rust_lib_path "$rust_triple")/$RUST_DLL"
            cp "$lib_path" "$out_path/"
            ok "产物已拷贝到: $out_path/"
            ls -lh "$out_path/"
            ;;
        macos-arm64|macos-x64|macos-universal)
            if [ -d "build/macos/Build/Products/Release/advance_media_kb.app" ]; then
                cp -r "build/macos/Build/Products/Release/advance_media_kb.app" "$out_path/"
            fi
            # 拷贝 dylib
            local rust_triple="${TARGET_RUST_TRIPLE[$target]}"
            if [ "$rust_triple" = "universal" ]; then
                cp rust/target/universal/release/$RUST_DYLIB "$out_path/" 2>/dev/null || true
            else
                cp "$(get_rust_lib_path "$rust_triple")/$RUST_DYLIB" "$out_path/" 2>/dev/null || true
            fi
            ok "产物已拷贝到: $out_path/"
            ;;
        ios-arm64)
            if [ -d "build/ios/iphoneos/Runner.app" ]; then
                cp -r "build/ios/iphoneos/Runner.app" "$out_path/"
            fi
            ok "产物已拷贝到: $out_path/"
            ;;
        web)
            cp -r build/web/* "$out_path/"
            ok "产物已拷贝到: $out_path/"
            info "运行: cd $out_path && python3 -m http.server 8080"
            ;;
    esac
}

# ================================================================
#  构建入口
# ================================================================

build_target() {
    local target="$1"
    local rust_triple="${TARGET_RUST_TRIPLE[$target]}"
    local info_desc="${TARGET_INFO[$target]}"

    title ""
    title "============================================"
    title "  构建: $target - $info_desc"
    title "============================================"

    # 清理旧产物
    info "清理旧构建产物..."
    clean_flutter_build "$target"
    rm -rf "$OUT_DIR/$target"

    case "$target" in
        # ----------------------------------------------------------
        # Linux x64
        # ----------------------------------------------------------
        linux-x64)
            clean_cross_compile_env
            generate_bindings
            build_rust_lib "$rust_triple"

            # 拷贝 Rust 库到 Flutter build 目录（预构建模式）
            local dest="build/linux/x64/release/rust_build"
            mkdir -p "$dest"
            cp "$(get_rust_lib_path "$rust_triple")/$RUST_SO" "$dest/"
            ok "预置 Rust 库到: $dest/$RUST_SO"

            # 构建 C++ 原生库
            build_cpp_lib "linux-x64"
            # 拷贝 C++ 库到 Rust 同目录（供 Dart FFI 加载）
            if [ -f "$CPP_BUILD_DIR/$RUST_SO" ]; then
                cp "$CPP_BUILD_DIR/$RUST_SO" "$dest/"
                ok "预置 C++ 库到: $dest/$RUST_SO"
            fi

            # 构建 Flutter
            flutter build linux --release

            # 拷贝产物
            copy_artifacts "$target"
            ;;

        # ----------------------------------------------------------
        # Android ARM64 (单一架构)
        # ----------------------------------------------------------
        android-arm64)
            set_android_env "$rust_triple"
            generate_bindings
            build_rust_lib "$rust_triple"

            # 拷贝 .so 到 jniLibs
            local jni_dir="arm64-v8a"
            mkdir -p "android/app/src/main/jniLibs/$jni_dir"
            cp "$(get_rust_lib_path "$rust_triple")/$RUST_SO" "android/app/src/main/jniLibs/$jni_dir/"
            ok "已拷贝到 jniLibs/$jni_dir/"

            # 构建 APK（仅 arm64）
            flutter build apk --release --target-platform android-arm64

            # 拷贝产物
            copy_artifacts "$target"
            ;;

        # ----------------------------------------------------------
        # Android x64 (模拟器)
        # ----------------------------------------------------------
        android-x64)
            set_android_env "$rust_triple"
            generate_bindings
            build_rust_lib "$rust_triple"

            local jni_dir="x86_64"
            mkdir -p "android/app/src/main/jniLibs/$jni_dir"
            cp "$(get_rust_lib_path "$rust_triple")/$RUST_SO" "android/app/src/main/jniLibs/$jni_dir/"
            ok "已拷贝到 jniLibs/$jni_dir/"

            flutter build apk --release --target-platform android-x64

            copy_artifacts "$target"
            ;;

        # ----------------------------------------------------------
        # Windows x64
        # ----------------------------------------------------------
        windows-x64)
            clean_cross_compile_env
            if ! command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
                err "缺少 x86_64-w64-mingw32-gcc (sudo apt install gcc-mingw-w64-x86-64)"
                return 1
            fi
            if ! rustup target list --installed | grep -q "x86_64-pc-windows-gnu"; then
                rustup target add x86_64-pc-windows-gnu
            fi
            generate_bindings
            build_rust_lib "$rust_triple"
            copy_artifacts "$target"
            warn "Flutter Windows 应用需在 Windows 上执行 flutter build windows"
            ;;

        # ----------------------------------------------------------
        # macOS
        # ----------------------------------------------------------
        macos-arm64|macos-x64)
            if [[ "$(uname)" != "Darwin" ]]; then
                err "macOS 构建必须在 macOS 上执行"
                return 1
            fi
            clean_cross_compile_env
            if ! rustup target list --installed | grep -q "$rust_triple"; then
                rustup target add "$rust_triple"
            fi
            generate_bindings
            build_rust_lib "$rust_triple"
            flutter build macos --release
            copy_artifacts "$target"
            ;;

        macos-universal)
            if [[ "$(uname)" != "Darwin" ]]; then
                err "macOS 构建必须在 macOS 上执行"
                return 1
            fi
            clean_cross_compile_env
            for t in aarch64-apple-darwin x86_64-apple-darwin; do
                if ! rustup target list --installed | grep -q "$t"; then
                    rustup target add "$t"
                fi
            done
            generate_bindings

            cargo build --release --target aarch64-apple-darwin --manifest-path "$RUST_MANIFEST"
            cargo build --release --target x86_64-apple-darwin --manifest-path "$RUST_MANIFEST"

            mkdir -p rust/target/universal/release
            lipo -create \
                rust/target/aarch64-apple-darwin/release/$RUST_DYLIB \
                rust/target/x86_64-apple-darwin/release/$RUST_DYLIB \
                -output rust/target/universal/release/$RUST_DYLIB

            ok "Universal Binary: $(lipo -info rust/target/universal/release/$RUST_DYLIB)"

            flutter build macos --release
            copy_artifacts "$target"
            ;;

        # ----------------------------------------------------------
        # iOS
        # ----------------------------------------------------------
        ios-arm64)
            if [[ "$(uname)" != "Darwin" ]]; then
                err "iOS 构建必须在 macOS 上执行"
                return 1
            fi
            clean_cross_compile_env
            if ! rustup target list --installed | grep -q "aarch64-apple-ios"; then
                rustup target add aarch64-apple-ios
            fi
            generate_bindings
            build_rust_lib "$rust_triple"
            flutter build ios --release --no-codesign
            copy_artifacts "$target"
            ;;

        # ----------------------------------------------------------
        # Web
        # ----------------------------------------------------------
        web)
            clean_cross_compile_env
            info "构建 Flutter Web 应用..."
            warn "Web 平台不支持 Rust FFI 原生库，部分功能不可用"
            flutter build web --release
            copy_artifacts "$target"
            ;;

        # ----------------------------------------------------------
        # 组合目标
        # ----------------------------------------------------------
        android-all)
            build_target android-arm64
            build_target android-x64
            ;;

        desktop-all)
            build_target linux-x64
            build_target windows-x64
            if [[ "$(uname)" == "Darwin" ]]; then
                build_target macos-universal
            fi
            ;;

        mobile-all)
            build_target android-all
            if [[ "$(uname)" == "Darwin" ]]; then
                build_target ios-arm64
            fi
            ;;

        all)
            local host_os
            host_os="$(uname)"
            info "当前系统: $host_os ($(uname -m))"

            case "$host_os" in
                Linux)
                    build_target linux-x64
                    build_target android-arm64
                    build_target web
                    build_target windows-x64
                    ;;
                Darwin)
                    build_target macos-universal
                    build_target ios-arm64
                    build_target web
                    ;;
                MINGW*|MSYS*|CYGWIN*)
                    build_target web
                    ;;
                *)
                    err "不支持的系统: $host_os"
                    return 1
                    ;;
            esac
            ;;

        *)
            err "未知的构建目标: $target"
            show_help
            return 1
            ;;
    esac

    # 清理中间产物
    clean_rust_intermediates
}

# ================================================================
#  主入口
# ================================================================

if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

TARGET="$1"

if [ "$TARGET" = "list" ] || [ "$TARGET" = "--help" ] || [ "$TARGET" = "-h" ]; then
    show_help
    exit 0
fi

title "=========================================="
title "  AdvanceMediaKB - 统一构建系统"
title "=========================================="
info "项目目录: $PROJECT_ROOT"
info "构建目标: $TARGET"
info "产物目录: $OUT_DIR/$TARGET"
echo ""

check_base_deps

START_TIME=$(date +%s)

build_target "$TARGET"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
title "=========================================="
ok "构建完成! 耗时: ${DURATION}秒"
title "=========================================="
echo ""
info "产物目录: $OUT_DIR/$TARGET/"
ls -la "$OUT_DIR/$TARGET/" 2>/dev/null || true
