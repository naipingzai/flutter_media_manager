#!/bin/bash
# AdvanceMediaKB - Web 构建脚本
# 注意: Web 平台不支持 FFI/Rust 原生库，此脚本仅构建 Flutter Web 应用
# Rust 功能在 Web 上不可用，需要在 Dart 侧做降级处理
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=========================================="
echo "  AdvanceMediaKB - Web 构建"
echo "=========================================="
echo "项目目录: $PROJECT_ROOT"
echo ""

export PATH="$PATH:/snap/bin"

# 检查依赖
echo "[1/4] 检查构建依赖..."
command -v flutter >/dev/null 2>&1 || { echo "错误: 未找到 flutter"; exit 1; }

# 2. 清理旧产物
echo "[2/4] 清理旧产物..."
rm -rf build/web

# 3. 重新生成 flutter_rust_bridge 绑定代码
echo "[3/4] 重新生成 Dart/Rust 绑定代码..."
if command -v flutter_rust_bridge_codegen >/dev/null 2>&1; then
    flutter_rust_bridge_codegen generate
    echo "  绑定代码已生成"
else
    echo "  警告: 未找到 flutter_rust_bridge_codegen，跳过代码生成"
fi

# 4. 构建 Flutter Web 应用
echo "[4/4] 构建 Flutter Web 应用..."
flutter build web --release

# 验证产物
if [ -f "build/web/index.html" ]; then
    echo ""
    echo "=========================================="
    echo "  构建成功!"
    echo "=========================================="
    echo "产物位置: build/web/"
    echo ""
    echo "运行命令:"
    echo "  flutter run -d chrome --release"
    echo "  # 或者用 HTTP 服务器:"
    echo "  cd build/web && python3 -m http.server 8080"
    echo ""
    echo "注意: Web 平台不支持 Rust FFI 原生库"
    echo "需要在 Dart 侧做平台检测和降级处理"
else
    echo ""
    echo "错误: Web 构建产物未找到!"
    exit 1
fi
