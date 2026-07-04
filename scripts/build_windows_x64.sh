#!/bin/bash
# AdvanceMediaKB - Windows x64 构建脚本 (Linux 交叉编译)
# 构建 Rust 库的 Windows DLL 版本
# 注意: Flutter Windows 应用需要在 Windows 上构建，此脚本仅构建 Rust DLL
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=========================================="
echo "  AdvanceMediaKB - Windows x64 构建"
echo "=========================================="
echo "项目目录: $PROJECT_ROOT"
echo ""

# 检查依赖
echo "[1/4] 检查构建依赖..."
command -v cargo >/dev/null 2>&1 || { echo "错误: 未找到 cargo"; exit 1; }
command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1 || {
    echo "错误: 未找到 x86_64-w64-mingw32-gcc"
    echo "安装: sudo apt install gcc-mingw-w64-x86-64"
    exit 1
}

# 检查 Rust 目标
if ! rustup target list --installed | grep -q "x86_64-pc-windows-gnu"; then
    echo "  安装 Rust Windows 目标..."
    rustup target add x86_64-pc-windows-gnu
fi

# 2. 清理旧产物
echo "[2/4] 清理旧产物..."
rm -f rust/target/x86_64-pc-windows-gnu/release/advance_media_kb.dll

# 3. 重新生成 flutter_rust_bridge 绑定代码
echo "[3/4] 重新生成 Dart/Rust 绑定代码..."
if command -v flutter_rust_bridge_codegen >/dev/null 2>&1; then
    flutter_rust_bridge_codegen generate
    echo "  绑定代码已生成"
else
    echo "  警告: 未找到 flutter_rust_bridge_codegen，跳过代码生成"
fi

# 4. 构建 Rust Windows x64 DLL
echo "[4/4] 构建 Rust 库 (x86_64-pc-windows-gnu)..."
cargo build --release --target x86_64-pc-windows-gnu --manifest-path rust/Cargo.toml

# 验证产物
DLL_PATH="rust/target/x86_64-pc-windows-gnu/release/advance_media_kb.dll"
if [ -f "$DLL_PATH" ]; then
    echo ""
    echo "=========================================="
    echo "  Rust DLL 构建成功!"
    echo "=========================================="
    echo "DLL 位置: $DLL_PATH"
    echo "DLL 大小: $(du -h "$DLL_PATH" | cut -f1)"
    file "$DLL_PATH"
    echo ""
    echo "=== 下一步 ==="
    echo "要生成完整的 Windows 应用包，需要在 Windows 上执行:"
    echo "  1. 将 $DLL_PATH 复制到 Windows 环境"
    echo "  2. flutter build windows --release"
    echo "  3. 将 DLL 复制到 build/windows/x64/runner/Release/"
else
    echo ""
    echo "错误: DLL 未生成!"
    exit 1
fi
