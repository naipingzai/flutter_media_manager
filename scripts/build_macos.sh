#!/bin/bash
# AdvanceMediaKB - macOS 构建脚本
# 需要在 macOS 系统上运行，支持 x86_64 和 arm64 (Universal Binary)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=========================================="
echo "  AdvanceMediaKB - macOS 构建"
echo "=========================================="
echo "项目目录: $PROJECT_ROOT"
echo ""

# 检查运行环境
if [[ "$(uname)" != "Darwin" ]]; then
    echo "错误: macOS 构建必须在 macOS 系统上执行"
    echo "当前系统: $(uname)"
    exit 1
fi

export PATH="$PATH:/snap/bin"

# 检查依赖
echo "[1/6] 检查构建依赖..."
command -v cargo >/dev/null 2>&1 || { echo "错误: 未找到 cargo"; exit 1; }
command -v flutter >/dev/null 2>&1 || { echo "错误: 未找到 flutter"; exit 1; }

# 检查 Rust macOS 目标
if ! rustup target list --installed | grep -q "aarch64-apple-darwin"; then
    echo "  安装 Rust macOS arm64 目标..."
    rustup target add aarch64-apple-darwin
fi
if ! rustup target list --installed | grep -q "x86_64-apple-darwin"; then
    echo "  安装 Rust macOS x86_64 目标..."
    rustup target add x86_64-apple-darwin
fi

# 2. 清理旧产物
echo "[2/6] 清理旧产物..."
rm -rf build/macos

# 3. 重新生成 flutter_rust_bridge 绑定代码
echo "[3/6] 重新生成 Dart/Rust 绑定代码..."
if command -v flutter_rust_bridge_codegen >/dev/null 2>&1; then
    flutter_rust_bridge_codegen generate
    echo "  绑定代码已生成"
else
    echo "  警告: 未找到 flutter_rust_bridge_codegen，跳过代码生成"
fi

# 4. 构建 Rust 库 (arm64)
echo "[4/6] 构建 Rust 库..."
echo "  构建 aarch64-apple-darwin..."
cargo build --release --target aarch64-apple-darwin --manifest-path rust/Cargo.toml
echo "  构建 x86_64-apple-darwin..."
cargo build --release --target x86_64-apple-darwin --manifest-path rust/Cargo.toml

# 创建 Universal Binary
echo "  创建 Universal Binary..."
mkdir -p rust/target/universal/release
lipo -create \
    rust/target/aarch64-apple-darwin/release/libadvance_media_kb.dylib \
    rust/target/x86_64-apple-darwin/release/libadvance_media_kb.dylib \
    -output rust/target/universal/release/libadvance_media_kb.dylib
echo "  Universal Binary 已创建"

# 5. 构建 Flutter macOS 应用
echo "[5/6] 构建 Flutter macOS 应用..."
flutter build macos --release

# 6. 验证产物
APP_PATH="build/macos/Build/Products/Release/advance_media_kb.app"
if [ -d "$APP_PATH" ]; then
    echo ""
    echo "=========================================="
    echo "  构建成功!"
    echo "=========================================="
    echo "应用位置: $APP_PATH"
    echo ""
    echo "运行命令:"
    echo "  open $APP_PATH"
else
    echo ""
    echo "错误: macOS 应用未生成!"
    exit 1
fi
