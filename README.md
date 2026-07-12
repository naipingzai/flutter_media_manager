# Flutter Media Knowledge Base

跨平台多媒体文件管理应用（Flutter + C++ FFI + SQLite3）。

支持 Linux 桌面和 Android 移动端。使用 C++ 原生层通过 SQLite3 管理本地数据库，并通过 Dart FFI 与 Flutter 交互。

## 主要功能

- 多媒体文件导入与管理
- 相册管理
- 标签层级管理
- 富文本笔记
- 高级搜索与过滤
- 图片、视频、音频预览

## 技术栈

- **Flutter 3.x** / Dart 3.x
- **C++ 17** 原生层
- **SQLite3** 单文件数据库
- **Dart FFI** 调用原生库
- **BLoC** 状态管理
- **Material 3** 设计系统

## 快速构建

```bash
# Linux 桌面
./scripts/build.sh linux-x64

# Android APK
./scripts/build.sh android-arm64
```

更多详细说明请查看 [BUILD.md](BUILD.md)。

## 项目目录

```text
lib/
├── bridge/native/    # Dart FFI 桥接
├── core/             # 主题、导航、国际化、权限
├── functionality/    # BLoC 状态管理
├── ui/               # 页面和 Widget
main.dart

native/
├── src/
│   ├── db/database.h      # C++ 数据模型与数据库接口
│   ├── db/database.cpp    # SQLite3 实现
│   └── ffi_bridge.cpp     # C ABI 导出层
└── third_party/sqlite3.c  # SQLite3 单文件合并
```

## 许可证

MIT
