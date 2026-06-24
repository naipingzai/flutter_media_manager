# AdvanceMediaKB-FR 项目 — 详细 Skill 规划文档

> 本文档记录项目目标、功能需求、技术架构、实现细节和开发规范。
> 实现语言：Flutter + Rust
> 目标平台：Windows、iOS、Android、Linux
> 必须遵守的命令：任何需要选择的或在不确定的东西，必须提供方案让用户手动选择，或给出新的设计方案，不允许自动选择方案，不允许用最简单最偷懒的方法，必须严格按照规范进行设计开发。

---

## 一、项目概述

**AdvanceMediaKB-FR** 是一个跨平台多媒体文件管理应用，基于 Flutter 前端 + Rust 核心后端架构。

**参考项目**：`/home/npznnz/VirtualBoxShareFloder/projects/AdvanceMediaKB`（Android Kotlin + Jetpack Compose + Hilt + Room + Media3 ExoPlayer + Material 3 + Coil）

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

**技术栈**：
- 前端：Flutter 3.x + Dart
- 后端核心：Rust（通过 flutter_rust_bridge FFI 与 Flutter 通信）
- 状态管理：Riverpod / Bloc（待选择方案）
- 数据库：SQLite（通过 Rust 的 rusqlite 或 sqlx 管理）
- 媒体解码：Rust 端处理（图片缩略图、视频信息提取、EXIF 读取）
- UI 框架：Material 3

---

## 二、绝对规则

> **⚠️ 绝对规则：任何需要选择的或在不确定的东西，必须提供方案让用户手动选择，或给出新的设计方案，不允许自动选择方案，不允许用最简单最偷懒的方法，必须严格按照规范进行设计开发。**

这意味着：
1. 当存在多个技术方案时，必须列出所有候选方案的优缺点，由用户决策。
2. 不允许使用默认配置或"能跑就行"的实现。
3. 每个功能模块必须有明确的设计文档和接口规范。
4. 代码必须遵循严格的错误处理、日志记录、性能监控规范。

---

## 三、目录结构规范

```
flutter/
├── lib/
│   ├── main.dart                    # 应用入口
│   ├── app.dart                     # 根应用组件（MaterialApp 配置）
│   ├── ui/                          # UI 层
│   │   ├── theme/                   # 主题配置（Material 3 动态颜色）
│   │   ├── components/              # 可复用组件
│   │   │   ├── selection_bottom_bar.dart
│   │   │   ├── selection_count_text.dart
│   │   │   └── standard_fab.dart
│   │   └── transitions/             # 页面转场动画
│   ├── pages/                       # 页面级组件
│   │   ├── home_page.dart           # 首页（含 AllMedia/Album/Tag 三标签）
│   │   ├── media_viewer_page.dart   # 媒体查看器（浏览模式 + 详情模式）
│   │   ├── search_page.dart         # 搜索页
│   │   ├── settings_page.dart       # 设置页
│   │   ├── album_page.dart          # 相册浏览页
│   │   ├── tag_page.dart            # 标签浏览页
│   │   └── note_page.dart           # 笔记页
│   ├── widgets/                     # 业务级 widgets
│   │   ├── media_grid.dart          # 媒体网格（支持多选）
│   │   ├── media_thumbnail_item.dart
│   │   ├── tag_card.dart            # 标签卡片
│   │   ├── album_card.dart          # 相册卡片
│   │   ├── breadcrumb_navigation.dart
│   │   ├── video_player_view.dart   # 视频播放器
│   │   ├── video_controls_inline.dart
│   │   ├── file_info_dialog.dart    # 文件信息对话框
│   │   ├── import_progress_dialog.dart
│   │   ├── file_browser_dialog.dart # 文件浏览器对话框
│   │   ├── tag_selector_dialog.dart # 标签选择器（多选/筛选模式）
│   │   ├── add_to_album_dialog.dart # 添加到相册对话框
│   │   └── create_rename_dialogs.dart
│   └── state/                       # 状态管理
│       ├── providers/               # Riverpod Providers（或 Bloc）
│       ├── models/                  # 状态模型（Freezed）
│       └── notifiers/               # StateNotifier / AsyncNotifier

rust_core/
├── Cargo.toml
├── src/
│   ├── lib.rs                       # Rust 库入口，导出 FFI 接口
│   ├── scanner/                     # 文件扫描模块
│   │   ├── mod.rs
│   │   ├── file_scanner.rs          # 递归扫描目录，识别媒体文件
│   │   └── mime_detector.rs         # MIME 类型检测（magic bytes）
│   ├── thumbnail/                   # 缩略图生成模块
│   │   ├── mod.rs
│   │   ├── image_thumbnail.rs       # 图片缩略图（使用 image crate）
│   │   ├── video_thumbnail.rs       # 视频首帧提取（使用 ffmpeg 或 opencv）
│   │   └── thumbnail_cache.rs       # 缩略图缓存管理（LRU + 磁盘缓存）
│   ├── database/                    # 数据库模块
│   │   ├── mod.rs
│   │   ├── connection.rs            # SQLite 连接池管理
│   │   ├── schema.rs                # 表结构定义 / 迁移
│   │   ├── media_dao.rs             # 媒体项 DAO
│   │   ├── album_dao.rs             # 相册 DAO
│   │   ├── tag_dao.rs               # 标签 DAO
│   │   ├── note_dao.rs              # 笔记 DAO
│   │   └── search_dao.rs            # 搜索 DAO
│   ├── search/                      # 搜索模块
│   │   ├── mod.rs
│   │   ├── text_search.rs           # 全文搜索（文件名 + 标签名）
│   │   └── filter_engine.rs         # 复合筛选引擎（类型/日期/相册/标签）
│   ├── exif/                        # EXIF 元数据模块
│   │   ├── mod.rs
│   │   └── exif_reader.rs           # EXIF 读取（使用 kamadak-exif）
│   ├── duplicate/                   # 重复文件检测模块
│   │   ├── mod.rs
│   │   └── hash_calculator.rs       # SHA-256 / perceptual hash 计算
│   ├── models/                      # 数据模型（与 Flutter 端共享）
│   │   ├── mod.rs
│   │   ├── media_item.rs
│   │   ├── album.rs
│   │   ├── tag.rs
│   │   ├── note.rs
│   │   └── search_result.rs
│   └── ffi/                         # FFI 桥接层（flutter_rust_bridge）
│       ├── mod.rs
│       └── api.rs                   # 导出给 Dart 调用的 API
├── tests/                           # Rust 单元测试
└── benches/                         # 性能基准测试

database/
└── photo.db                         # SQLite 数据库文件（运行时生成）

assets/
├── icons/
└── i18n/                            # 国际化资源（arb 文件）
    ├── en.arb
    └── zh.arb
```

---

## 四、功能需求详细说明（含参考代码映射）

### 4.1 首页（HomePage）

**参考文件**：`feature-home/HomeScreen.kt`（766行）、`feature-home/HomeViewModel.kt`

**功能描述**：
- 底部 NavigationBar 三标签切换：全部媒体 / 相册 / 标签
- 顶部 TopAppBar：显示当前位置名称 + 搜索按钮 + 设置按钮
- 全部媒体标签：
  - 顶部 FilterChip 行：全部 / 带标签 / 无标签 / 带相册 / 无相册（5 种过滤模式）
  - 媒体网格（可配置列数 2-6）
  - 支持多选模式（长按进入）
  - 多选底部操作栏：取消 / 添加到相册 / 打标签 / 删除
  - 导入 FAB（浮动操作按钮）

**参考代码关键片段（Kotlin → Dart 映射）**：

```kotlin
// Kotlin: HomeScreen.kt 过滤模式定义
enum class FilterMode { ALL, WITH_TAGS, WITHOUT_TAGS, WITH_ALBUMS, WITHOUT_ALBUMS }

// Kotlin: HomeViewModel.kt filterMode 切换
val filterMode = MutableStateFlow(FilterMode.ALL)
val mediaList = filterMode.flatMapLatest { mode ->
    when (mode) {
        FilterMode.ALL -> mediaRepository.observeAll()
        FilterMode.WITH_TAGS -> mediaRepository.observeWithAnyTag()
        FilterMode.WITHOUT_TAGS -> mediaRepository.observeWithoutAnyTag()
        FilterMode.WITH_ALBUMS -> mediaRepository.observeWithAnyAlbum()
        FilterMode.WITHOUT_ALBUMS -> mediaRepository.observeWithoutAnyAlbum()
    }
}.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())
```

```dart
// Dart 等价实现（使用 Riverpod）
enum FilterMode { all, withTags, withoutTags, withAlbums, withoutAlbums }

final filterModeProvider = StateProvider<FilterMode>((ref) => FilterMode.all);

final mediaListProvider = StreamProvider.autoDispose<List<MediaItem>>((ref) {
  final mode = ref.watch(filterModeProvider);
  final rustApi = ref.watch(rustApiProvider);
  switch (mode) {
    case FilterMode.all: return rustApi.observeAllMedia();
    case FilterMode.withTags: return rustApi.observeWithAnyTag();
    case FilterMode.withoutTags: return rustApi.observeWithoutAnyTag();
    case FilterMode.withAlbums: return rustApi.observeWithAnyAlbum();
    case FilterMode.withoutAlbums: return rustApi.observeWithoutAnyAlbum();
  }
});
```

**交互细节**：
- 点击媒体项 → 进入 MediaViewerPage（浏览模式），传递媒体列表和当前索引
- 长按媒体项 → 进入多选模式（选中该项）
- 多选模式下点击其他项 → 切换选中状态
- 返回键优先级：文件浏览器 > 设置/搜索覆盖层 > 多选模式 > 系统默认
- 过滤模式切换时清空选择状态，避免跨 filter 选中状态错乱
- 使用 AnimatedSwitcher 实现 Tab 切换淡入淡出动画

**多选底部栏**：
```kotlin
// Kotlin: SelectionBottomBar 组件
@Composable
fun SelectionBottomBar(
    text: @Composable () -> Unit,
    leading: @Composable () -> Unit,
    trailing: @Composable () -> Unit
)
```

**待选择方案**：
- [ ] 状态管理框架：Riverpod vs Bloc（需用户选择）
- [ ] 网格列数配置范围：2-6 列 vs 其他范围
- [ ] 多选模式下是否支持滑动连续选择

---

### 4.2 媒体查看器（MediaViewerPage）

**参考文件**：`app/MediaViewerActivity.kt`（1408行）

**功能描述**：
- 支持图片、视频、音频三种媒体类型
- 两种模式：浏览模式（默认）/ 详情模式（点击"详情"按钮进入）
- 左右滑动翻页（PageView）

**浏览模式 UI**：
- 顶部栏：白色背景 + 文件名（支持省略）+ 详情模式按钮
- 多页时显示计数器悬浮（"1 / 10" 格式，黑色半透明圆角背景）
- 底部栏：白色全宽栏，包含四个操作按钮：
  - 分享（Share）
  - 导出到 Download（Export）
  - 打标签（Tag）
  - 文件信息（Info）
- 点击媒体区域切换 overlay 显隐

**详情模式 UI**：
- 顶部栏隐藏
- 底部悬浮窗（玻璃透明效果）：
  - 视频/音频详情模式：上方嵌入播放控件（进度条 + 播放/暂停 + 后退10秒/前进10秒）
  - 图片变换按钮：上移 / 左旋 / 缩小 / 还原 / 放大 / 右旋 / 下移（7 个按钮）
  - 按钮位置：底部偏上（padding 精确控制）
  - 背景：Color.White.copy(alpha = 0.25f) + blur(20.dp) 模糊效果

**图片变换功能（参考代码）**：

```kotlin
// Kotlin: ImageTransformState 对象
object ImageTransformState {
    var scale by mutableFloatStateOf(1f)
    var rotation by mutableIntStateOf(0)
    var offsetX by mutableFloatStateOf(0f)
    var offsetY by mutableFloatStateOf(0f)
}

// Kotlin: 缩放
fun zoomIn() { scale = (scale * 1.25f).coerceAtMost(4f) }
fun zoomOut() { scale = (scale / 1.25f).coerceAtLeast(0.25f) }

// Kotlin: 旋转（使用 Int 度数避免浮点精度问题）
fun rotateLeft() { rotation -= 90 }
fun rotateRight() { rotation += 90 }

// Kotlin: 平移
fun shiftUp() { offsetY -= 80f }
fun shiftDown() { offsetY += 80f }
fun shiftLeft() { offsetX -= 80f }
fun shiftRight() { offsetX += 80f }

// Kotlin: 还原
fun reset() { scale = 1f; rotation = 0; offsetX = 0f; offsetY = 0f }

// Kotlin: 拖动手势（方向随旋转角度修正）
detectDragGestures { change, dragAmount ->
    change.consume()
    val angle = Math.toRadians(rotation.toDouble())
    val cos = cos(angle).toFloat()
    val sin = sin(angle).toFloat()
    offsetX += dragAmount.x * cos + dragAmount.y * sin
    offsetY += -dragAmount.x * sin + dragAmount.y * cos
}
```

```dart
// Dart 等价实现
class ImageTransform {
  double scale = 1.0;
  int rotation = 0;
  double offsetX = 0.0;
  double offsetY = 0.0;
  
  void zoomIn() => scale = (scale * 1.25).clamp(0.25, 4.0);
  void zoomOut() => scale = (scale / 1.25).clamp(0.25, 4.0);
  void rotateLeft() => rotation -= 90;
  void rotateRight() => rotation += 90;
  void shiftUp() => offsetY -= 80;
  void shiftDown() => offsetY += 80;
  void shiftLeft() => offsetX -= 80;
  void shiftRight() => offsetX += 80;
  void reset() { scale = 1.0; rotation = 0; offsetX = 0.0; offsetY = 0.0; }
}
```

**视频播放功能**：
- 视频 fit 到视图中心，保持原始宽高比（防止拉伸）
- 监听视频尺寸变化 → 重新计算 fit scale
- 叠加详情模式的用户变换（旋转 + 缩放 + 平移）
- 音频文件显示音乐图标占位（黑色背景 + MusicNote icon）
- 应用进入后台时暂停播放器，避免后台解码消耗 CPU
- 翻页时自动播放当前页视频，暂停其他页

**文件信息对话框**：
- 显示：文件名、文件大小、文件类型、MIME 类型、分辨率、时长、创建时间、文件路径、SHA-256
- 所属相册列表、关联标签列表

**导出功能**：
- 导出到 Download/AdvanceMediaKB 目录
- 文件名冲突时自动重命名（name_1.ext）
- 导出进度覆盖层

**待选择方案**：
- [ ] 视频播放器实现方案：video_player 插件 vs 自定义 PlatformView
- [ ] 图片查看器实现方案：photo_view 插件 vs 自定义实现
- [ ] 详情模式按钮布局：7 个（当前设计）vs 9 个（九宫格含左右移动）

---

### 4.3 相册模块（Album）

**参考文件**：`feature-home/album/AlbumScreen.kt`（完整）、`feature-home/album/AlbumViewModel.kt`（完整）

**功能描述**：
- 层级结构：支持根相册和子相册（无限嵌套）
- 相册实体字段：id, name, parentId, coverMediaId, sortOrder, createdAt
- 相册卡片展示：封面缩略图 + 渐变蒙层 + 相册名 + 媒体数量 + 子相册指示箭头
- 面包屑导航：Home icon + 各级相册名（AssistChip 样式）
- 空状态提示

**参考代码关键片段**：

```kotlin
// Kotlin: AlbumEntity 数据类
@Entity(
    tableName = "albums",
    indices = [Index(value = ["parent_id"])],
    foreignKeys = [ForeignKey(
        entity = AlbumEntity::class,
        parentColumns = ["id"],
        childColumns = ["parent_id"],
        onDelete = ForeignKey.CASCADE
    )]
)
data class AlbumEntity(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val name: String,
    @ColumnInfo(name = "parent_id") val parentId: String?,
    @ColumnInfo(name = "cover_media_id") val coverMediaId: String?,
    @ColumnInfo(name = "sort_order") val sortOrder: Int = 0,
    @ColumnInfo(name = "created_at") val createdAt: Long = System.currentTimeMillis()
)

// Kotlin: AlbumWithInfo 展示用数据类
data class AlbumWithInfo(
    val album: AlbumEntity,
    val mediaCount: Int,
    val hasChildren: Boolean,
    val coverThumbnailPath: String?
)

// Kotlin: AlbumViewModel 导航栈管理
private val _navigationStack = MutableStateFlow<List<String>>(emptyList())
val navigationStack: StateFlow<List<String>> = _navigationStack.asStateFlow()

fun navigateToAlbum(albumId: String?) {
    _isNavigating.value = true
    _currentAlbumId.value =
