# AdvanceMediaKB 架构文档

## 目录结构

```
lib/
├── main.dart                       # 应用入口 (C++ FFI 初始化)
├── ARCHITECTURE.md                 # 架构文档（本文件）
│
├── ui/                             # 🎨 UI 层 - 纯页面和组件
│   ├── album/                      #   相册页面
│   ├── home/                       #   主页
│   ├── media/                      #   媒体浏览 + widgets (media_grid, file_browser, search_bar)
│   ├── note/                       #   笔记编辑/列表
│   ├── search/                     #   搜索 + widgets (advanced_search_dialog)
│   ├── settings/                   #   设置
│   ├── tag/                        #   标签管理
│   └── viewer/                     #   媒体查看器 + widgets (image/video/audio)
│
├── functionality/                  # ⚙️ 功能层 - 业务逻辑 (BLoC)
│   ├── album/                      #   相册 BLoC (event/state/bloc)
│   ├── home/                       #   应用全局 BLoC
│   ├── media/                      #   媒体 BLoC + import_state_machine
│   ├── note/                       #   笔记 BLoC
│   └── tag/                        #   标签 BLoC
│
├── bridge/                         # 🔌 桥接层 - 原生代码通信
│   └── native/                     #   FFI 桥接
│       ├── native_library.dart     #     C++ 库加载器
│       ├── frb_generated.dart      #     Rust bridge 生成代码 (兼容层)
│       ├── frb_generated.io.dart
│       ├── frb_generated.web.dart
│       └── api/                    #     API 包装
│           ├── settings.dart       #       Rust bridge API
│           ├── media.dart          #       Rust bridge API
│           ├── album.dart          #       Rust bridge API
│           ├── tag.dart            #       Rust bridge API
│           ├── note.dart           #       Rust bridge API
│           ├── settings_ffi.dart   #       C++ FFI API ✨
│           ├── media_ffi.dart      #       C++ FFI API ✨
│           ├── album_ffi.dart      #       C++ FFI API ✨
│           ├── tag_ffi.dart        #       C++ FFI API ✨
│           └── note_ffi.dart       #       C++ FFI API ✨
│
├── core/                           # 🧩 核心层
│   ├── design_system/              #   Material 3 主题
│   ├── i18n/                       #   国际化
│   ├── navigation/                 #   路由导航
│   └── permissions/                #   权限管理
│
├── app/                            # 📱 应用配置（预留）
└── data/                           # 💾 数据层（预留）
```

## 原生实现

```
native/                             # C++ 原生实现
├── CMakeLists.txt                  #   CMake 构建配置
├── src/
│   ├── db/
│   │   ├── database.h              #   数据模型 + Database 类声明
│   │   └── database.cpp            #   完整实现 (~800行 C++)
│   └── ffi_bridge.cpp              #   C ABI 导出函数
└── third_party/
    ├── sqlite3.c                   #   SQLite3 amalgamation
    └── sqlite3.h

rust/                               # Rust 原始实现 (保留兼容)
├── Cargo.toml
└── src/
    ├── api/                        #   settings/media/album/tag/note/scanner/search
    └── db/                         #   database models
```

## 架构分层

| 层级       | 目录                  | 职责                              |
|------------|----------------------|-----------------------------------|
| UI 层      | `lib/ui/`            | 页面、组件、布局，纯展示逻辑      |
| 功能层     | `lib/functionality/` | BLoC 业务逻辑、状态管理           |
| 桥接层     | `lib/bridge/native/` | FFI 通信 (Rust bridge + C++ FFI)  |
| 核心层     | `lib/core/`          | 主题、路由、国际化、权限          |
| 原生层     | `native/` + `rust/`  | C++ (sqlite3) / Rust 数据库       |

## 迁移状态

- ✅ C++ 实现完成，编译通过
- ✅ C++ FFI 包装器就绪 (media/album/tag/note/settings)
- ✅ main.dart 已使用 C++ 初始化
- 🔄 BLoC 层当前使用 Rust bridge API，可逐步切换到 *_ffi.dart
- ✅ 构建脚本支持 C++ 和 Rust 双构建
