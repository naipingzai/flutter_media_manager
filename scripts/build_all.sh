#!/bin/bash
# AdvanceMediaKB - 全平台构建脚本
# 自动检测当前平台并执行对应的构建脚本，或指定平台构建
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=========================================="
echo "  AdvanceMediaKB - 全平台构建"
echo "=========================================="
echo "项目目录: $PROJECT_ROOT"
echo "当前系统: $(uname) $(uname -m)"
echo ""

# 支持的平台列表
SUPPORTED_PLATFORMS="linux android windows macos ios web all"

# 显示帮助
show_help() {
    echo "用法: $0 [平台]"
    echo ""
    echo "支持的平台:"
    echo "  linux     - Linux x64 桌面应用"
    echo "  android   - Android 全架构 APK"
    echo "  windows   - Windows x64 (交叉编译 Rust DLL)"
    echo "  macos     - macOS Universal Binary (需要 macOS)"
    echo "  ios       - iOS 应用 (需要 macOS + Xcode)"
    echo "  web       - Web 应用 (不支持 Rust FFI)"
    echo "  all       - 构建当前系统支持的所有平台"
    echo ""
    echo "示例:"
    echo "  $0              # 自动检测平台并构建"
    echo "  $0 linux        # 构建 Linux 版本"
    echo "  $0 android      # 构建 Android 版本"
    echo "  $0 all          # 构建所有支持的平台"
}

# 平台名称到脚本文件的映射
get_script_name() {
    local platform="$1"
    case "$platform" in
        linux)    echo "build_linux_x64.sh" ;;
        android)  echo "build_android_arm64.sh" ;;
        windows)  echo "build_windows_x64.sh" ;;
        macos)    echo "build_macos.sh" ;;
        ios)      echo "build_ios.sh" ;;
        web)      echo "build_web.sh" ;;
        *)        echo "build_${platform}.sh" ;;
    esac
}

# 执行构建脚本
build_platform() {
    local platform="$1"
    local script_name=$(get_script_name "$platform")
    local script="$SCRIPT_DIR/$script_name"
    
    if [ ! -f "$script" ]; then
        echo "错误: 构建脚本不存在: $script"
        return 1
    fi
    
    echo ""
    echo ">>> 开始构建: $platform ($script_name)"
    echo "------------------------------------------"
    bash "$script"
    echo "------------------------------------------"
    echo ">>> 完成构建: $platform"
}

# 获取当前平台支持的构建目标
get_platform_targets() {
    local os="$(uname)"
    local arch="$(uname -m)"
    
    case "$os" in
        Linux)
            echo "linux android windows web"
            ;;
        Darwin)
            echo "macos ios web"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "windows web"
            ;;
        *)
            echo ""
            ;;
    esac
}

# 主逻辑
if [ $# -eq 0 ]; then
    # 没有参数，自动检测平台
    TARGETS=$(get_platform_targets)
    if [ -z "$TARGETS" ]; then
        echo "错误: 无法自动检测当前平台的构建目标"
        show_help
        exit 1
    fi
    echo "自动检测到可构建的平台: $TARGETS"
elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
    exit 0
elif [ "$1" = "all" ]; then
    TARGETS=$(get_platform_targets)
    echo "构建当前系统支持的所有平台: $TARGETS"
else
    # 验证平台参数
    TARGET="$1"
    VALID=false
    for p in $SUPPORTED_PLATFORMS; do
        if [ "$p" = "$TARGET" ]; then
            VALID=true
            break
        fi
    done
    
    if [ "$VALID" = false ]; then
        echo "错误: 不支持的平台 '$TARGET'"
        show_help
        exit 1
    fi
    TARGETS="$TARGET"
fi

# 执行构建
SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_PLATFORMS=""

for platform in $TARGETS; do
    if build_platform "$platform"; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        FAILED_PLATFORMS="$FAILED_PLATFORMS $platform"
    fi
done

# 总结
echo ""
echo "=========================================="
echo "  构建总结"
echo "=========================================="
echo "成功: $SUCCESS_COUNT 个平台"
if [ $FAIL_COUNT -gt 0 ]; then
    echo "失败: $FAIL_COUNT 个平台:$FAILED_PLATFORMS"
    exit 1
else
    echo "所有平台构建成功!"
fi
