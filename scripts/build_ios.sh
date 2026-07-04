#!/bin/bash
# AdvanceMediaKB - iOS 构建脚本
# 需要在 macOS 系统上运行，且需要 Xcode 和 iOS 签名证书
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=========================================="
echo "  AdvanceMediaKB - iOS 构建"
echo "=========================================="
echo "项目目录: $PROJECT_ROOT"
echo ""

# 检查运行环境
if [[ "$(uname)" != "Darwin" ]]; then
    echo "错误: iOS 构建必须在 macOS 系统上执行"
    exit 1
fi

# 检查依赖
echo "[1/6] 检查构建依赖..."
command -v cargo >/dev/null 2>&1 || { echo "错误: 未找到 cargo"; exit 1; }
command -v flutter >/dev/null 2>&1 || { echo "错误: 未找到 flutter"; exit 1; }
command -v xcodebuild >/dev/null 2>&1 || { echo "错误: 未找到 xcodebuild (Xcode)"; exit 1; }

# 检查 Rust iOS 目标
if ! rustup target list --installed | grep -q "aarch64-apple-ios"; then
    echo "  安装 Rust iOS arm64 目标..."
    rustup target add aarch64-apple-ios
fi

# 2. 清理旧产物
echo "[2/6] 清理旧产物..."
rm -rf build/ios

# 3. 重新生成 flutter_rust_bridge 绑定代码
echo "[3/6] 重新生成 Dart/Rust 绑定代码..."
if command -v flutter_rust_bridge_codegen >/dev/null 2>&1; then
    flutter_rust_bridge_codegen generate
    echo "  绑定代码已生成"
else
    echo "  警告: 未找到 flutter_rust_bridge_codegen，跳过代码生成"
fi

# 4. 构建 Rust 库 (iOS arm64)
echo "[4/6] 构建 Rust 库 (aarch64-apple-ios)..."
cargo build --release --target aarch64-apple-ios --manifest-path rust/Cargo.toml
echo "  Rust iOS 库构建成功"

# 5. 构建 iOS IPA（不签名）
echo "[5/6] 构建 Flutter iOS 应用..."
echo "  注意: 未指定签名证书时构建为 .app（无 IPA）"
flutter build ios --release --no-codesign

# 6. 验证产物
APP_PATH="build/ios/iphoneos/Runner.app"
if [ -d "$APP_PATH" ]; then
    echo ""
    echo "=========================================="
    echo "  构建成功!"
    echo "=========================================="
    echo "应用位置: $APP_PATH"
    echo ""
    echo "如需签名并安装到设备:"
    echo "  1. 在 Xcode 中配置签名证书"
    echo "  2. flutter build ios --release"
    echo "  3. flutter install"
else
    echo ""
    echo "错误: iOS 应用未生成!"
    exit 1
fi
