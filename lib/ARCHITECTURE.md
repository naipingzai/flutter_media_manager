# AdvanceMediaKB 架构文档

## 目录结构

```
lib/
├── main.dart                       # 应用入口
├── ARCHITECTURE.md                 # 架构文档（本文件）
│
├── ui/                             # 🎨 UI 层 - 纯页面和组件
│   ├── album/                      #   相册页面
│   │   ├── album_screen.dart
│   │   └── widgets/
│   ├── home/                       #   主页
│   │   ├── home_screen.dart
│   │   └── widgets/
│   ├── media/                      #   媒体浏览页面
│   │   ├── media_screen.dart
│   │   ├── api_test_screen.dart
│   │   └── widgets/                #     media_grid, file_browser_dialog, search_bar
│   ├── note/                       #   笔记页面
│   │   ├── note_edit_screen.dart
│   │   ├── note_list_screen.dart
│   │   └── widgets/
│   ├── search/                     #   搜索页面
│   │   ├── search_screen.dart
│   │   └── widgets/                #     advanced_search_dialog
│   ├── settings/                   #   设置页面
│   │   ├── settings_screen.dart
│   │   └── widgets/
│   ├── tag/                        #   标签页面
│   │   ├── tag_screen.dart
│   │   └── widgets/
│   └── viewer/                     #   媒体查看器
│       ├── viewer_page.dart
│       └── widgets/                #     image_viewer, video_player, audio_player
│
├── functionality/                  # ⚙️ 功能层 - 业务逻辑 (BLoC)
│   ├── album/                      #   相册 BLoC
│   │   ├── album_bloc.dart
│   │   ├── album_event.dart
│   │   └── album_state.dart
│   ├── home/                       #   应用全局 BLoC
│   │   ├── app_bloc.dart
│   │   ├── app_event.dart
│   │   └── app_state.dart
│   ├── media/                      #   媒体 BLoC
│   │   ├── media_bloc.dart
│   │   ├── media_event.dart
│   │   ├── media_state.dart
│   │   └── import_state_machine.dart
│   ├── note/                       #   笔记 BLoC
│   │   ├── note_bloc.dart
│   │   ├── note_event.dart
│   │   └── note_state.dart
│   ├── search/                     #   搜索（预留）
│   ├── settings/                   #   设置（预留）
│   ├── tag/                        #   标签 BLoC
│   │   ├── tag_bloc.dart
│   │   ├── tag_event.dart
│   │   └── tag_state.dart
│   └── viewer/                     #   查看器（预留）
│
├── bridge/                         # 🔌 桥接层 - 原生代码通信
│   └── native/                     #   Rust FFI 桥接 (flutter_rust_bridge 生成)
│       ├── frb_generated.dart
│       ├── frb_generated.io.dart
│       ├── frb_generated.web.dart
│       └── api/                    #     各模块的 API 桥接
│           ├── album.dart
│           ├── media.dart
│           ├── tag.dart
│           ├── note.dart
│           ├── scanner.dart
│           ├── search.dart
│           ├── settings.dart
│           ├── import_export.dart
│           └── enums.dart
│
├── core/                           # 🧩 核心层 - 共享工具和常量
│   ├── design_system/              #   设计系统 (Material 3)
│   │   ├── app_theme.dart
│   │   └── components.dart
│   ├── i18n/                       #   国际化
│   │   └── app_localizations.dart
│   ├── navigation/                 #   路由导航
│   │   └── app_router.dart
│   ├── permissions/                #   权限管理
│   │   └── permission_service.dart
│   └── utils/                      #   工具函数（预留）
│
├── app/                            # 📱 应用配置（预留）
└── data/                           # 💾 数据层（预留）
    ├── api/
    └── models/
```

## 架构分层

| 层级       | 目录           | 职责                              |
|------------|----------------|-----------------------------------|
| UI 层      | `lib/ui/`      | 页面、组件、布局，纯展示逻辑      |
| 功能层     | `lib/functionality/` | BLoC 业务逻辑、状态管理、事件处理 |
| 桥接层     | `lib/bridge/`  | Flutter ↔ 原生代码（Rust/C++）通信 |
| 核心层     | `lib/core/`    | 主题、路由、国际化、权限等共享模块 |

## 依赖方向

```
ui → functionality → bridge → native (Rust/C++)
  ↘ core (共享常量/工具)
```

## 设计原则

- **UI 层** 只负责渲染和用户交互，不含业务逻辑
- **功能层** 通过 BLoC 模式管理状态，调用桥接层 API
- **桥接层** 提供类型安全的 FFI 接口，由 flutter_rust_bridge 生成
- **核心层** 提供跨功能模块共享的工具、主题、路由等
