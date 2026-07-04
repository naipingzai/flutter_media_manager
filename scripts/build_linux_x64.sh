#!/bin/bash
# AdvanceMediaKB - Linux x64 构建脚本
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=========================================="
echo "  AdvanceMediaKB - Linux x64 构建"
echo "=========================================="
echo "项目目录: $PROJECT_ROOT"
echo ""

export PATH="$PATH:/snap/bin"

# 清除可能残留的 ARM64 交叉编译环境变量
unset PKG_CONFIG_PATH
unset PKG_CONFIG_LIBDIR
unset PKG_CONFIG_SYSROOT_DIR
unset FLUTTER_TARGET_PLATFORM_SYSROOT

RUST_SO="libadvance_media_kb.so"
RUST_RELEASE_DIR="rust/target/release"
BUILD_BUNDLE="build/linux/x64/release/bundle"
RUST_DEST="build/linux/x64/release/rust_build"

# 1. 清理旧产物
echo "[1/6] 清理旧产物..."
rm -rf build/linux/x64

# 2. 检查依赖
echo "[2/6] 检查构建依赖..."
command -v cargo >/dev/null 2>&1 || { echo "错误: 未找到 cargo"; exit 1; }
command -v flutter >/dev/null 2>&1 || { echo "错误: 未找到 flutter"; exit 1; }

# 3. 重新生成 flutter_rust_bridge 绑定代码
echo "[3/6] 重新生成 Dart/Rust 绑定代码..."
if command -v flutter_rust_bridge_codegen >/dev/null 2>&1; then
    flutter_rust_bridge_codegen generate
    echo "  绑定代码已生成"
else
    echo "  警告: 未找到 flutter_rust_bridge_codegen，跳过代码生成"
    echo "  使用已有的绑定代码继续..."
fi

# 4. 构建 Rust 库
echo "[4/6] 构建 Rust 库..."
cargo build --release --manifest-path rust/Cargo.toml
echo "  Rust 库构建成功"

# 5. 拷贝 Rust 库到 Flutter build 目录（预构建模式，跳过 CMake 中的 cargo build）
echo "[5/6] 拷贝 Rust 库到 Flutter build 目录..."
mkdir -p "$RUST_DEST"
cp "$RUST_RELEASE_DIR/$RUST_SO" "$RUST_DEST/"
echo "  已拷贝到: $RUST_DEST/$RUST_SO"

# 6. 构建 Flutter Linux 应用
echo "[6/6] 构建 Flutter Linux 应用..."
flutter build linux --release

# 验证产物
if [ -f "$BUILD_BUNDLE/$BINARY_NAME" ] || [ -f "$BUILD_BUNDLE/advance_media_kb" ]; then
    echo ""
    echo "=========================================="
    echo "  构建成功!"
    echo "=========================================="
    echo "产物位置: $BUILD_BUNDLE/"
    echo "可执行文件: $BUILD_BUNDLE/advance_media_kb"
    echo ""
    echo "运行命令:"
    echo "  cd $BUILD_BUNDLE && ./advance_media_kb"
else
    echo ""
    echo "错误: 构建产物未找到!"
    exit 1
fi
