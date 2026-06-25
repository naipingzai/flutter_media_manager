# AdvanceMediaKB-FR 项目 — 完整 Skill 规划文档

> 本文档是项目的核心设计文档，整合了所有功能需求、技术方案、实现细节和迁移计划。
> 实现语言：Flutter 3.24.5 + Dart 3.5.4 / Rust
> 目标平台：Windows、iOS、Android、Linux
> 参考项目：`/home/npznnz/VirtualBoxShareFloder/projects/AdvanceMediaKB`（Android Kotlin）
>
> 📋 实施状态详见 [SKILLS_IMPLEMENTATION.md](SKILLS_IMPLEMENTATION.md)

---

## 第一章：项目概述

**AdvanceMediaKB-FR** 是一个跨平台多媒体文件管理应用，基于 Flutter 前端 + Rust 核心后端架构。

**核心功能**：
- 本地图片/视频/音频文件管理
- 媒体查看器（支持浏览模式与详情模式，含缩放/旋转/平移）
- 相册（Album）层级管理（无限嵌套）
- 标签（Tag）层级管理（无限嵌套）
- 笔记（Note）关联媒体
- 文件导入/导出（AMB 格式）
- 高级搜索（支持标签筛选、历史记录）
- 应用设置（主题、网格列数、缩略图质量、冲突策略等）
- 数据备份/恢复/清理/导出

**技术栈**（已确定）：
- 前端：Flutter 3.24.5 + Dart 3.5.4
- 后端核心：Rust（通过 flutter_rust_bridge 2.12.0 FFI 与 Flutter 通信）
- 状态管理：**Bloc**（flutter_bloc 8.1.6）
- 数据库：SQLite（通过 Rust 的 **sqlx** 0.7 管理）
- 媒体解码：Rust 端处理（图片缩略图、视频信息提取、EXIF 读取）
- UI 框架：Material 3

---

## 第二章：绝对规则

> **⚠️ 任何需要选择的或在不确定的东西，必须提供方案让用户手动选择，或给出新的设计方案，不允许自动选择方案，不允许用最简单最偷懒的方法，必须严格按照规范进行设计开发。**

这意味着：
1. 当存在多个技术方案时，必须列出所有候选方案的优缺点，由用户决策。
2. 不允许使用默认配置或"能跑就行"的实现。
3. 每个功能模块必须有明确的设计文档和接口规范。
4. 代码必须遵循严格的错误处理、日志记录、性能监控规范。

---

## 第三章：目录结构

```
AdvanceMediaKB-FR/
├── lib/                           # Flutter 前端代码
│   ├── main.dart                  # 应用入口（Bloc 全局初始化）
│   ├── bloc/                      # Bloc 状态管理
│   │   ├── bloc.dart              # 统一导出
│   │   ├── app/                   # 应用级状态（主题、初始化）
│   │   ├── media/                 # 媒体列表状态
│   │   ├── album/                 # 相册状态
│   │   └── tag/                   # 标签状态
│   ├── screens/                   # 页面级组件
│   │   ├── home_screen.dart       # 首页（底部导航四标签）
│   │   ├── media_screen.dart      # 媒体浏览页面
│   │   ├── media_detail_screen.dart # 媒体详情查看器
│   │   ├── album_screen.dart      # 相册浏览页
│   │   ├── tag_screen.dart        # 标签浏览页
│   │   ├── settings_screen.dart   # 设置页
│   │   └── api_test_screen.dart   # API 调试页
│   ├── widgets/                   # 可复用组件
│   │   ├── media_grid.dart        # 媒体网格展示
│   │   ├── search_bar.dart        # 搜索栏
│   │   ├── file_browser_dialog.dart # 文件浏览器对话框
│   │   └── widgets.dart           # 统一导出
│   └── src/rust/                  # FFI 生成代码
│       ├── frb_generated.dart     # 桥接代码
│       ├── frb_generated.io.dart  # 平台相关 FFI
│       └── api/                   # Rust API Dart 端类型
│           ├── media.dart
│           ├── album.dart
│           ├── tag.dart
│           ├── note.dart
│           ├── search.dart
│           ├── settings.dart
│           ├── scanner.dart
│           └── import_export.dart
├── rust/                          # Rust 核心后端
│   ├── Cargo.toml                 # 依赖配置
│   └── src/
│       ├── lib.rs                 # 库入口
│       ├── frb_generated.rs       # FFI 生成代码
│       ├── api/                   # API 模块
│       │   ├── mod.rs
│       │   ├── media.rs           # 媒体 CRUD
│       │   ├── album.rs           # 相册 CRUD
│       │   ├── tag.rs             # 标签 CRUD
│       │   ├── note.rs            # 笔记 CRUD
│       │   ├── search.rs          # 搜索功能
│       │   ├── settings.rs        # 应用设置
│       │   ├── scanner.rs         # 文件扫描
│       │   └── import_export.rs   # 导入导出
│       └── db/                    # 数据库模块
│           ├── mod.rs             # 连接池和表结构
│           └── models.rs          # 数据模型转换
├── android/                       # Android 平台配置
├── ios/                           # iOS 平台配置
├── linux/                         # Linux 平台配置
├── macos/                         # macOS 平台配置
├── windows/                       # Windows 平台配置
├── SKILLS.md                      # 本文档（完整设计）
├── SKILLS_IMPLEMENTATION.md       # 实施状态追踪
└── test/                          # 测试目录
```

---

## 第四章：功能需求详细方案

### 4.1 首页（HomeScreen）

**文件**：`lib/screens/home_screen.dart`

**功能描述**：
- 底部 NavigationBar 四标签切换：媒体 / 相册 / 标签 / 设置
- AppBar 显示当前位置名称
- 默认显示媒体页面（AllMedia）
- 使用 IndexedStack 保持页面状态

**方案流程**：
1. 应用启动 → AppBloc 初始化 → 加载设置 → 创建全部分支 Bloc
2. 用户点击底部导航 → AppNavigationChangedEvent → 切换 IndexedStack index
3. 媒体页面自动调用 MediaLoadAllEvent 加载列表
4. FAB 在媒体页面提供导入入口

---

### 4.2 媒体浏览页面（MediaScreen）

**文件**：`lib/screens/media_screen.dart`

**功能描述**：
- 顶部搜索栏（MediaSearchBar）
- 媒体网格展示（可配置列数 2-6）
- 空状态提示
- 过滤选项（全部/图片/视频/音频）
- 排序选项（日期/名称/大小/类型）
- 导入功能（扫描文件夹 / 文件浏览器选择）
- 多选模式

**导入流程（核心）**：
```
用户点击 FAB → 导入选项弹出
  ├── 扫描文件夹 → FilePicker 选择目录 → Rust scanDirectory() → 显示结果
  └── 浏览选择文件 → 打开 FileBrowserDialog（全屏文件浏览器）
        ├── 浏览文件系统目录
        ├── 多选文件（支持所有文件类型）
        ├── 点击"导入"按钮
        ├── 逐个调用 Rust importSingleFile()
        │     ├── SHA-256 哈希计算
        │     ├── 检查重复
        │     ├── 复制到应用私有目录
        │     ├── 生成缩略图
        │     └── 写入数据库
        ├── 全部完成后发送 MediaLoadAllEvent 刷新列表
        └── 显示导入结果（成功数 / 失败数 / 错误详情）
```

**文件浏览器设计**（参考项目 `FileBrowserDialog.kt` 全屏设计）：
- 全屏覆盖（非 Dialog），与系统文件管理器体验一致
- 顶部 AppBar + 路径面包屑（可点击跳转各级目录）
- 内容区：目录优先显示（文件夹图标），文件可勾选
- 底部：取消 / 导入按钮（显示选中数量）
- 每次进入清空上次选择状态

---

### 4.3 媒体详情查看器（MediaDetailScreen）

**文件**：`lib/screens/media_detail_screen.dart`

**功能描述**：
- 支持图片、视频、音频三种媒体类型
- 左右滑动翻页（PageView）
- 两种模式：浏览模式（默认）/ 详情模式

**浏览模式 UI**：
- 顶部栏：文件名 + 详情模式切换按钮
- 多页计数器悬浮显示
- 底部操作栏：分享 / 导出 / 标签 / 信息
- 点击媒体区域切换 overlay 显隐

**详情模式 UI**：
- 无顶部栏
- 底部悬浮窗：7 个图片变换按钮 + 视频播放控件
- 图片变换：上移 / 左旋 / 缩小 / 还原 / 放大 / 右旋 / 下移
- 变换参数：scale（0.25~4.0）、rotation（0/90/180/270）、offsetX、offsetY
- 拖动手势考虑旋转角度修正方向

**视频播放**：
- 保持原始宽高比（fit 到视图中心，禁止拉伸）
- 通过 Matrix 计算：视频宽高比 vs 视图宽高比 → fit scale → 居中
- 然后叠加用户旋转/缩放/平移变换
- 应用进入后台时暂停播放

---

### 4.4 相册模块（Album）

**文件**：`lib/screens/album_screen.dart`

**数据模型**（Rust）：
```rust
struct Album {
    id: String,
    name: String,
    parent_id: Option<String>,      // 父相册ID（无限嵌套）
    cover_media_id: Option<String>,  // 封面媒体ID
    sort_order: i32,
    created_at: i64,
}

struct AlbumWithInfo {
    album: Album,
    media_count: i32,
    has_children: bool,
    cover_thumbnail_path: Option<String>,
}
```

**方案流程**：
1. 进入相册 → 加载根相册列表 → 卡片展示（封面缩略图 + 相册名 + 媒体数量）
2. 面包屑导航：Home Icon → 各级相册名（可点击跳转）
3. 点击相册 → 加载子相册列表 / 显示该相册内的媒体
4. 长按相册 → 删除确认对话框
5. FAB → 创建相册（输入名称）
6. 空状态提示

**操作项**：
- 创建相册（输入名称，可选在当前相册内创建子相册）
- 删除相册（显示相册名称确认）
- 重命名相册
- 设置相册封面（选择策略）
- 添加媒体到相册（弹出未添加媒体列表，支持多选）
- 面包屑点击任意一级可快速跳转

---

### 4.5 标签模块（Tag）

**文件**：`lib/screens/tag_screen.dart`

**数据模型**（Rust）：
```rust
struct Tag {
    id: String,
    name: String,
    color: Option<String>,        // 标签颜色（hex 格式）
    parent_id: Option<String>,    // 父标签ID（无限嵌套）
    created_at: i64,
}

struct TagWithInfo {
    tag: Tag,
    media_count: i32,
    cover_thumbnail_path: Option<String>,
    has_children: bool,
}
```

**方案流程**：
1. 进入标签 → 加载根标签列表 → 卡片展示（封面缩略图 + 渐变蒙层 + 标签名 + 媒体数量）
2. 面包屑导航（与相册一致）
3. 点击标签 → 进入子标签列表 / 显示该标签的媒体
4. 长按标签 → 删除确认对话框
5. FAB → 创建标签（输入名称）

**标签选择器对话框（参考 `TagSelectorDialog.kt`）**：
- 两种模式：MULTI（多选打标签）/ FILTER（搜索筛选）
- 展示所有标签层级（扁平列表）
- 支持搜索过滤
- 批量打标签：差集计算（selectedTagIds - currentTags = toAdd, currentTags - selectedTagIds = toRemove）

**多标签筛选**：
- AND 模式：取标签媒体列表的交集
- OR 模式：取标签媒体列表的并集
- 使用 Flow/Rx 组合操作

---

### 4.6 笔记模块（Note）

**文件**：Rust: `rust/src/api/note.rs` / Dart: `lib/src/rust/api/note.dart`

**数据模型**（Rust）：
```rust
struct Note {
    id: String,
    media_id: String,
    content: String,
    created_at: i64,
    updated_at: i64,
}
```

**方案流程**：
1. 在媒体详情查看器中查看笔记
2. 一个媒体最多一个笔记（一对一关联）
3. 支持创建、编辑、删除
4. 笔记列表按更新时间排序
5. UPSERT 模式：查询是否存在 → 存在则更新 / 不存在则插入

---

### 4.7 搜索模块（Search）

**文件**：Rust: `rust/src/api/search.rs` / Dart: `lib/src/rust/api/search.dart`

**方案流程**：
1. 输入搜索关键词（OutlinedTextField，带防抖 300ms）
2. 实时搜索：文件名匹配 + 标签名匹配（SQL LIKE 查询）
3. 排序：文件名匹配优先，然后按创建时间倒序
4. 搜索结果网格展示（与首页一致）
5. 搜索历史记录（最近搜索列表，点击可快速搜索）
6. 清空历史记录按钮
7. 标签筛选：通过 TagSelectorDialog 选择标签进行筛选
8. 活动筛选 Chip 展示（可点击移除）

---

### 4.8 设置模块（Settings）

**文件**：`lib/screens/settings_screen.dart`

**设置项分类**：

**导入设置**：
- 导入冲突策略：跳过 / 替换 / 保留两者（Dropdown）
- 导入后删除原文件（Switch）

**外观设置**：
- 主题模式：跟随系统 / 浅色 / 深色（Dropdown）
- 首页网格列数（2-6）
- 相册网格列数（2-6）
- 搜索网格列数（2-6）
- 标签网格列数（2-6）
- 缩略图质量（30%-100%）

**交互设置**：
- 显示内容预览（Switch）：关闭后列表仅显示图标+文件名

**存储管理**：
- 存储统计：媒体数量、总大小、缩略图缓存大小
- 清理缩略图缓存
- 查找未引用文件

**数据管理**：
- 备份数据库
- 恢复数据库
- 导出数据（AMB 格式）
- 删除所有数据（危险操作，需确认对话框）

---

### 4.9 数据库模块

**文件**：`rust/src/db/mod.rs`、`rust/src/db/models.rs`

**数据库表结构**：

**media_items 表**：
```sql
CREATE TABLE media_items (
    id TEXT PRIMARY KEY,
    original_name TEXT NOT NULL,
    storage_name TEXT NOT NULL,
    file_path TEXT NOT NULL,
    thumbnail_path TEXT NOT NULL DEFAULT '',
    media_type INTEGER NOT NULL,     -- 0=Image, 1=Video, 2=Audio, 3=Document, 4=Other
    mime_type TEXT NOT NULL DEFAULT '',
    size INTEGER NOT NULL,
    width INTEGER,
    height INTEGER,
    duration INTEGER,                -- 毫秒
    sha256_hash TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);
CREATE INDEX idx_media_items_created_at ON media_items(created_at);
CREATE INDEX idx_media_items_type ON media_items(media_type);
CREATE INDEX idx_media_items_hash ON media_items(sha256_hash);
```

**albums 表**：
```sql
CREATE TABLE albums (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    parent_id TEXT REFERENCES albums(id) ON DELETE CASCADE,
    cover_media_id TEXT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL
);
CREATE INDEX idx_albums_parent ON albums(parent_id);
```

**media_albums 表**（多对多）：
```sql
CREATE TABLE media_albums (
    id TEXT PRIMARY KEY,
    album_id TEXT NOT NULL REFERENCES albums(id) ON DELETE CASCADE,
    media_id TEXT NOT NULL REFERENCES media_items(id) ON DELETE CASCADE,
    created_at INTEGER NOT NULL
);
```

**tags 表**：
```sql
CREATE TABLE tags (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    color TEXT,
    parent_id TEXT REFERENCES tags(id) ON DELETE CASCADE,
    created_at INTEGER NOT NULL
);
CREATE INDEX idx_tags_parent ON tags(parent_id);
```

**media_tags 表**（多对多）：
```sql
CREATE TABLE media_tags (
    id TEXT PRIMARY KEY,
    media_id TEXT NOT NULL REFERENCES media_items(id) ON DELETE CASCADE,
    tag_id TEXT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    created_at INTEGER NOT NULL
);
```

**notes 表**：
```sql
CREATE TABLE notes (
    id TEXT PRIMARY KEY,
    media_id TEXT NOT NULL REFERENCES media_items(id) ON DELETE CASCADE,
    content TEXT NOT NULL DEFAULT '',
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);
CREATE INDEX idx_notes_media ON notes(media_id);
```

**app_settings 表**：
```sql
CREATE TABLE app_settings (
    id INTEGER PRIMARY KEY DEFAULT 1,
    theme_mode INTEGER NOT NULL DEFAULT 0,
    grid_columns INTEGER NOT NULL DEFAULT 3,
    album_grid_columns INTEGER NOT NULL DEFAULT 2,
    show_content_previews INTEGER NOT NULL DEFAULT 1,
    thumbnail_quality INTEGER NOT NULL DEFAULT 85,
    language TEXT NOT NULL DEFAULT 'zh_CN'
);
```

---

### 4.10 Rust 核心模块

**scanner 模块**（`rust/src/api/scanner.rs`）：
- 扫描目录：递归遍历，识别媒体扩展名
- 导入文件：SHA-256 哈希 → 去重检查 → 复制到应用目录 → 缩略图生成 → 数据库写入
- 支持批量导入和单文件导入
- 缩略图生成：使用 image crate，最大 512px，Lanczos3 滤波
- 图片尺寸提取

**search 模块**（`rust/src/api/search.rs`）：
- 文本搜索：文件名 + 标签名 LIKE 查询
- 复合筛选：类型、日期范围、相册、标签（AND/OR）
- 排序：匹配优先 + 时间倒序

**settings 模块**（`rust/src/api/settings.rs`）：
- 设置 CRUD（upsert 模式）
- 存储统计
- 缩略图缓存清理
- 数据备份/恢复/导出
- 全部数据删除

---

### 4.11 文件导入方案

**导入方式**（当前实现）：
1. **扫描文件夹**：通过 file_picker 选择目录 → Rust 端递归扫描识别媒体 → 逐个导入
2. **文件浏览器选择**：通过 FileBrowserDialog 选择单个/多个文件 → 逐个导入

**导入流程（Rust 端 import_single_file）**：
1. 检查文件是否存在
2. 计算 SHA-256 哈希
3. 检查是否已存在（通过哈希查询）
4. 获取文件信息（名称、扩展名、MIME 类型、大小）
5. 生成 UUID 存储文件名
6. 复制文件到应用私有媒体目录
7. 生成缩略图（图片/视频类型）
8. 提取图片尺寸（图片类型）
9. 插入 media_items 表
10. 返回 MediaItem 结构体

---

## 第五章：已确定的技术方案

### 5.1 架构
| 方案 | 选择 |
|------|------|
| 状态管理 | **Bloc** (flutter_bloc 8.1.6) |
| Rust-Flutter | **flutter_rust_bridge** 2.12.0 |
| 数据库 | **sqlx** 0.7 + SQLite |
| 异步运行时 | **tokio** 1.x |
| 数据库迁移 | **refinery** 0.8 |

### 5.2 功能
| 方案 | 选择 |
|------|------|
| 视频播放 | **video_player** 2.9.1 + **chewie** 1.8.5 |
| 图片查看 | **photo_view** 0.15.0 |
| 文件选择 | **file_picker** 8.0.7 |
| 搜索算法 | **SQL LIKE** 查询 |
| 图片处理 | **image** crate 0.24 |
| EXIF 读取 | **kamadak-exif** 0.5 |

### 5.3 UI
| 方案 | 选择 |
|------|------|
| 主题框架 | **Material 3** + dynamic_color |
| 主题模式 | 跟随系统 / 浅色 / 深色 |
| 标签颜色 | **保留** |
| 国际化 | **Flutter 内置**（flutter_localizations + intl） |

---

## 第六章：已解决的问题

### 6.1 技术难题
1. **Rust 动态库未打包** → 手动创建 jniLibs 目录结构并复制 Rust 库
2. **数据库无法打开** → 使用 `SqliteConnectOptions::from_str()` + `libsqlite3-sys` bundled 特性
3. **FFI bool 类型映射错误** → 手动修复为 ffi.Int8
4. **Android Scoped Storage** → 使用应用外部存储目录
5. **Java 21 兼容性** → 降级到 Java 17

---

## 第七章：开发阶段规划

### 阶段 1：基础架构搭建 ✅
- 初始化 Flutter + Rust 项目
- 配置 FFI 桥接
- 数据库连接和表结构
- 主题配置

### 阶段 2：核心功能实现 ✅
- 文件扫描和导入
- 媒体数据库 CRUD
- 缩略图生成
- 媒体网格展示
- 媒体查看器（图片）

### 阶段 3：高级功能实现 🔄
- 视频播放功能
- 相册层级管理
- 标签层级管理
- 搜索功能
- 设置页面

### 阶段 4：优化和打磨 ⬜
- 性能优化（启动、列表、视频）
- UI 动画
- 错误处理
- 测试

### 阶段 5：发布准备 ⬜
- 多平台构建
- 应用签名
- 用户文档

---

## 第八章：验收标准

### 功能验收
- [ ] 所有参考项目功能完整迁移（部分完成）
- [x] 跨平台支持（代码层面支持 Windows/iOS/Android/Linux）
- [x] Android 构建通过（APK 47.5MB）
- [x] Rust FFI 接口测试通过（8/8）

### 性能验收
- [ ] 启动时间 < 2 秒
- [ ] 列表滑动帧率 > 55fps
- [ ] 内存占用稳定，无 OOM

### 质量验收
- [ ] 单元测试覆盖率 > 70%
- [ ] 无崩溃（Crash-free rate > 99%）
- [ ] 国际化完整
