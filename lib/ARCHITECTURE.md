# AdvanceMediaKB - 项目架构

本文档说明 Flutter 端代码的组织结构，便于快速定位 UI、业务逻辑、Rust 通信相关代码。

## 顶层目录结构

```
lib/
├── core/                  # 框架层 - 与业务无关的通用设施
│   ├── design_system/     # UI 设计系统（M3 主题、组件）
│   ├── i18n/              # 国际化
│   ├── navigation/        # 路由
│   ├── permissions/       # 平台权限
│   ├── utils/             # 工具函数（待添加）
│   └── ...
├── data/                  # 数据层 - Rust 通信（待添加）
│   └── bridge/            # FFI 桥接
├── features/              # 功能模块（垂直切片）
│   ├── home/              # 主屏幕（底部导航）
│   ├── media/             # 媒体管理
│   ├── album/             # 相册管理
│   ├── tag/               # 标签管理
│   ├── note/              # 笔记功能
│   ├── search/            # 搜索
│   ├── settings/          # 设置
│   └── viewer/            # 媒体查看器
├── app/                   # 应用层（待添加）
│   ├── app.dart           # MaterialApp
│   └── app_router.dart    # 顶层路由
├── src/                    # 自动生成的 FFI 桥接（不要编辑）
│   └── rust/              # flutter_rust_bridge 生成
└── main.dart              # 入口
```

## 功能模块标准结构

每个 `features/<feature>/` 目录下采用统一的 3 层结构：

```
features/<feature>/
├── bloc/                  # 业务逻辑层 - BLoC 状态管理
│   ├── <feature>_bloc.dart        # 主 BLoC 类（包含 part of 引用）
│   ├── <feature>_event.dart       # 事件定义（part of <feature>_bloc）
│   └── <feature>_state.dart       # 状态定义（part of <feature>_bloc）
├── view/                  # UI 层 - 页面/屏幕
│   └── *_screen.dart
└── widgets/               # 复用 UI 组件（仅该 feature 使用）
    └── *_widget.dart 或 *_dialog.dart
```

## 跨模块引用规则

- **同 feature 内**：使用相对路径 `../bloc/<file>.dart`、`../widgets/<file>.dart`
- **跨 feature**：使用 package 路径 `package:advance_media_kb/features/<other>/bloc/<file>.dart`
- **core/ 引用**：使用 `package:advance_media_kb/core/...`
- **src/ FFI 引用**：使用 `package:advance_media_kb/src/rust/...`

## Rust 端结构（`rust/src/`）

```
rust/src/
├── lib.rs                  # 库入口
├── frb_generated.rs        # 自动生成（不要编辑）
├── api/                    # Rust 功能层 - 业务逻辑实现
│   ├── mod.rs
│   ├── media.rs            # 媒体管理功能
│   ├── search.rs           # 搜索功能
│   ├── tag.rs              # 标签管理
│   ├── album.rs            # 相册管理
│   ├── note.rs             # 笔记功能
│   ├── settings.rs         # 设置功能
│   ├── scanner.rs          # 文件扫描
│   ├── import_export.rs    # 导入导出
│   └── enums.rs            # 枚举定义
└── db/                     # Rust 数据访问层 - SQLite 数据库
    ├── mod.rs              # 数据库连接池、迁移
    └── models.rs           # 数据库模型
```

## Material 3 设计系统

设计令牌定义在 `lib/core/design_system/app_theme.dart`：
- `AppTheme.lightTheme()` / `darkTheme()` - M3 主题构造
- `ColorScheme` - 完整 M3 色板（含 tertiary、surfaceContainer 系列）
- `TextTheme` - 完整 M3 类型尺度
- `AppSpacing` - 4dp 网格间距
- `AppRadius` - M3 形状系统
- `AppAnimation` - M3 缓动动画
- `AppSize` - 尺寸令牌

## 关键设计决策

1. **features/ 垂直切片**：每个功能独立目录，自包含 bloc/view/widgets
2. **BLoC 集中管理状态**：业务规则不写在 Widget 里
3. **Rust 通信解耦**：UI 通过 BLoC 调用，BLoC 通过 `src/rust/api/` 调用 Rust API
4. **类型安全**：`src/rust/frb_generated.dart` 提供编译期类型检查
5. **Material 3 一致性**：所有 UI 通过 `Theme.of(context).colorScheme` 访问颜色

## 构建

```bash
# Linux x64
./scripts/build.sh linux-x64

# Android ARM64
./scripts/build.sh android-arm64

# Web
./scripts/build.sh web

# 所有支持平台
./scripts/build.sh all
```
