# AdvanceMediaKB-FR 项目 — 详细 Skill 规划文档

> 本文档记录项目目标、功能需求、技术架构、实现细节和开发规范。
> 实现语言：Flutter + Rust
> 目标平台：Windows、iOS、Android、Linux
> 必须遵守的命令：任何需要选择的或在不确定的东西，必须提供方案让用户手动选择，或给出新的设计方案，不允许自动选择方案，不允许用最简单最偷懒的方法，必须严格按照规范进行设计开发。

---

## 一、项目概述

**AdvanceMediaKB-FR** 是一个跨平台多媒体文件管理应用，基于 Flutter 前端 + Rust 核心后端架构。

**核心功能**：
- 本地图片/视频/音频文件管理
- 媒体查看器（支持浏览模式与详情模式，含缩放/旋转/平移）
- 相册（Album）层级管理
- 标签（Tag）层级管理
- 笔记（Note）关联媒体
- 文件导入/导出
- 高级搜索（支持标签筛选）
- 应用设置（主题、网格列数、缩略图质量等）
- 数据备份/恢复/清理

**技术栈**：
- 前端：Flutter 3.x + Dart
- 后端核心：Rust（通过 FFI / flutter_rust_bridge 与 Flutter 通信）
- 状态管理：Riverpod / Bloc（待选择方案）
- 数据库：SQLite（通过 Rust 的 rusqlite 或 sqlx 管理）
- 媒体解码：Rust 端处理（图片缩略图、视频信息提取、EXIF 读取）
- UI 框架：Material 3

---

## 二、必须遵守的开发命令

> **⚠️ 绝对规则：任何需要选择的或在不确定的东西，必须提供方案让用户手动选择，或给出新的设计方案，不允许自动选择方案，不允许用最简单最偷懒的方法，必须严格按照规范进行设计开发。**

这意味着：
1. 当存在多个技术方案时（如状态管理框架选择、数据库访问方式、Rust-Flutter 通信机制），必须列出所有候选方案的优缺点，由用户决策。
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
│   │   ├── video_player_view.dart   # 视频播放器（TextureView 等价实现）
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

## 四、功能需求详细说明

### 4.1 首页（HomePage）

**功能描述**：
- 底部导航栏三标签切换：全部媒体 / 相册 / 标签
- 顶部 AppBar：显示当前位置名称 + 搜索按钮 + 设置按钮
- 全部媒体标签：
  - 顶部 FilterChip 行：全部 / 带标签 / 无标签 / 带相册 / 无相册（5 种过滤模式）
  - 媒体网格（可配置列数 2-6）
  - 支持多选模式（长按进入）
  - 多选底部操作栏：取消 / 添加到相册 / 打标签 / 删除
  - 导入 FAB（浮动操作按钮）
- 相册标签：进入 AlbumPage
- 标签标签：进入 TagPage

**交互细节**：
- 点击媒体项 → 进入 MediaViewerPage（浏览模式）
- 长按媒体项 → 进入多选模式（选中该项）
- 多选模式下点击其他项 → 切换选中状态
- 返回键优先级：文件浏览器 > 设置/搜索覆盖层 > 多选模式 > 系统默认
- 过滤模式切换时清空选择状态，避免跨 filter 选中状态错乱
- 使用 AnimatedContent 实现 Tab 切换淡入淡出动画

**待选择方案**：
- [ ] 状态管理框架：Riverpod vs Bloc（需用户选择）
- [ ] 网格列数配置范围：2-6 列 vs 其他范围
- [ ] 多选模式下是否支持滑动连续选择（参考项目已移除，需确认是否恢复）

---

### 4.2 媒体查看器（MediaViewerPage）

**功能描述**：
- 支持图片、视频、音频三种媒体类型
- 两种模式：浏览模式（默认）/ 详情模式（点击"详情"按钮进入）
- 左右滑动翻页（HorizontalPager）
- 预加载所有可播放媒体到播放器，避免翻页时重复创建解码器

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
- 支持手势：拖动平移（方向随旋转角度修正）
- 返回键拦截：退出详情模式回到浏览模式

**图片变换功能**：
- 缩放：zoomIn（×1.25，最大 4x）、zoomOut（÷1.25）
- 旋转：rotateLeft（-90°）、rotateRight（+90°），使用 Int 度数避免浮点精度问题
- 平移：shiftUp/Down/Left/Right（每次 80px）
- 拖动：detectDragGestures，方向随旋转角度修正（使用 cos/sin 矩阵变换）
- 还原：reset（scale=1, rotation=0, offsetX/Y=0）
- 翻页时重置变换状态（但保持在详情模式）
- 旋转 90°/270° 时自动补偿宽高比（rotComp 计算）

**视频播放功能**：
- 使用 TextureView 后端（非 SurfaceView）
- 视频 fit 到视图中心，保持原始宽高比（防止拉伸）
- 监听 onVideoSizeChanged → 重新计算 fit scale 并应用 setTransform
- 叠加详情模式的用户变换（旋转 + 缩放 + 平移）
- 音频文件显示音乐图标占位（黑色背景 + MusicNote icon）
- Activity 进入后台时暂停 ExoPlayer，避免后台解码消耗 CPU
- 翻页时自动播放当前页视频，暂停其他页

**文件信息对话框**：
- 显示：文件名、文件大小、文件类型、MIME 类型、分辨率、时长、创建时间、文件路径、SHA-256
- 所属相册列表、关联标签列表
- 图片分辨率通过 BitmapFactory.Options.inJustDecodeBounds 读取
- 视频分辨率通过 MediaMetadataRetriever 读取

**导出功能**：
- 导出到 Download/AdvanceMediaKB 目录
- Android Q+ 使用 MediaStore API
- 预 Android Q 直接复制到外部存储 + MediaScannerConnection.scanFile
- 文件名冲突时自动重命名（name_1.ext）
- 导出进度覆盖层（LinearProgressIndicator + "导出中..."文字）

**待选择方案**：
- [ ] 视频播放器实现方案：video_player 插件 vs 自定义 PlatformView（TextureView）
- [ ] 图片查看器实现方案：photo_view 插件 vs 自定义实现
- [ ] 详情模式按钮布局：7 个（当前设计）vs 9 个（九宫格含左右移动）
- [ ] 玻璃透明效果实现方案：BackdropFilter vs Container 渐变

---

### 4.3 相册模块（Album）

**功能描述**：
- 层级结构：支持根相册和子相册（无限嵌套）
- 相册实体字段：id, name, parentId, coverMediaId, sortOrder, createdAt
- 相册卡片展示：封面缩略图 + 渐变蒙层 + 相册名 + 媒体数量 + 子相册指示箭头
- 面包屑导航：Home icon + 各级相册名（AssistChip 样式）
- 空状态提示

**相册操作**：
- 创建相册（FAB）
- 长按相册 → 删除确认对话框
- 点击相册 → 进入子相册或查看媒体
- 相册内媒体网格（与首页 AllMedia 一致）
- 设置相册封面
- 面包屑点击任意一级可快速跳转

**数据模型**：
- AlbumEntity：id, name, parentId, coverMediaId, sortOrder, createdAt
- AlbumWithInfo：album + mediaCount + hasChildren + coverThumbnailPath
- BreadcrumbItem：id, name

**待选择方案**：
- [ ] 相册封面选择策略：第一张媒体 vs 用户指定 vs 最近添加
- [ ] 相册排序方式：创建时间 vs 名称 vs 自定义排序

---

### 4.4 标签模块（Tag）

**功能描述**：
- 层级结构：支持根标签和子标签（无限嵌套）
- 标签实体字段：id, name, color, parentId, createdAt
- 标签卡片展示：封面缩略图 + 渐变蒙层 + 标签名 + 媒体数量 + 子标签指示箭头
- 面包屑导航（与相册一致）
- 空状态提示

**标签操作**：
- 创建标签（FAB，仅输入名称，无颜色选择）
- 长按标签 → 删除确认对话框
- 点击标签 → 进入子标签或查看媒体
- 标签内媒体网格
- 重命名标签

**标签选择器对话框（TagSelectorDialog）**：
- 两种模式：MULTI（多选打标签）/ FILTER（搜索筛选）
- 展示所有标签层级（树形或扁平列表）
- 支持搜索过滤
- 确认/取消按钮

**数据模型**：
- TagEntity：id, name, color, parentId, createdAt
- TagWithInfo：tag + mediaCount + hasChildren + coverThumbnailPath
- TagBreadcrumb：id, name

**待选择方案**：
- [ ] 标签颜色功能：保留（参考项目已移除）vs 彻底移除
- [ ] 标签选择器展示方式：树形展开 vs 扁平列表 + 面包屑

---

### 4.5 笔记模块（Note）

**功能描述**：
- 笔记关联到单个媒体项（一对一）
- 笔记实体字段：id, mediaId, content, createdAt, updatedAt
- 在媒体查看器中查看/编辑笔记
- 笔记列表页（按时间排序）

**数据模型**：
- NoteEntity：id, mediaId, content, createdAt, updatedAt

**待选择方案**：
- [ ] 笔记功能范围：简单文本 vs 富文本 vs Markdown 支持
- [ ] 笔记入口位置：媒体查看器内 vs 独立页面

---

### 4.6 搜索模块（Search）

**功能描述**：
- 搜索输入框（OutlinedTextField，非 SearchBar）
- 实时搜索：文件名匹配 + 标签名匹配（SQL LIKE 查询）
- 搜索结果排序：文件名匹配优先，然后按创建时间倒序
- 搜索结果网格展示（与首页一致）
- 搜索历史记录（最近搜索列表，点击可快速搜索）
- 清空历史记录
- 标签筛选：通过 TagSelectorDialog 选择标签进行筛选
- 活动筛选 Chip 展示（可点击移除）

**搜索界面**：
- 顶部 AppBar：返回按钮 + 标题 + 标签筛选按钮
- 搜索输入框：带搜索图标 + 清除按钮
- 空查询时显示搜索历史
- 有查询时显示结果数量 + 结果网格
- 无结果时显示空状态提示

**待选择方案**：
- [ ] 搜索算法：SQL LIKE vs 全文搜索（FTS5）vs 自定义索引
- [ ] 搜索结果排序策略：相关度 vs 时间 vs 混合

---

### 4.7 设置模块（Settings）

**功能描述**：
- 设置项分类展示（LazyColumn + SectionHeader）

**导入设置**：
- 导入冲突策略：跳过 / 替换 / 保留两者（Dropdown）
- 导入后删除原文件（Switch）

**外观设置**：
- 主题模式：跟随系统 / 浅色 / 深色（Dropdown）
- 首页列数（Slider：2-6）
- 相册列数（Slider：2-6）
- 搜索列数（Slider：2-6）
- 标签列数（Slider：2-6）
- 缩略图质量（Slider：30%-100%）

**交互设置**：
- 预测性返回动画（Switch）
- 显示内容预览（Switch）：关闭后列表仅显示图标+文件名，不加载缩略图

**存储管理**：
- 存储统计：媒体数量、总大小、缩略图缓存大小
- 清理缩略图缓存（ActionButton）
- 查找未引用文件（ActionButton，显示数量和大小）

**数据管理**：
- 备份数据库（备份到下载目录）
- 恢复数据库（从备份恢复）
- 导出数据（导出媒体数据到 AMB 格式文件）
- 删除所有数据（DangerButton，带确认对话框）

**关于**：
- 版本号
- 开源许可（链接到 GitHub）
- 隐私政策（链接到 GitHub）
- 检查更新（链接到 GitHub Releases）

**导入导出对话框**：
- 导入 AMB 文件（系统文件选择器）
- 导出为 AMB 文件（系统保存对话框）

**待选择方案**：
- [ ] 设置持久化方案：SharedPreferences vs Hive vs SQLite
- [ ] 设置数据同步：本地 only vs 云同步

---

### 4.8 导入模块（Import）

**功能描述**：
- 文件浏览器对话框（全屏覆盖，覆盖 BottomBar、TopBar）
- 需要存储权限（Android 11+ 需要 MANAGE_EXTERNAL_STORAGE）
- 支持多选文件
- 导入进度对话框（显示当前进度 / 总数）

**导入流程**：
1. 用户点击 FAB → 打开文件浏览器
2. 用户选择文件 → 调用 importMediaUseCase
3. Rust 端处理：
   - 计算 SHA-256 哈希
   - 检查重复（根据冲突策略：跳过/替换/保留两者）
   - 生成存储文件名（UUID）
   - 复制文件到应用私有目录
   - 生成缩略图
   - 提取 EXIF 信息
   - 插入数据库记录
4. 进度实时推送到 Flutter 端
5. 导入完成后关闭进度对话框

**文件浏览器**：
- 系统级文件选择器观感
- 显示目录列表和文件列表
- 支持进入子目录
- 返回键返回上一级
- 多选文件

**待选择方案**：
- [ ] 文件浏览器实现：系统文件选择器（file_picker）vs 自定义文件浏览器
- [ ] 导入并发策略：串行 vs 并行（限制并发数）
- [ ] 导入事务策略：单文件事务 vs 批量事务

---

### 4.9 数据库模块（Database）

**数据库架构**：
SQLite 数据库，版本 1，包含以下表：

**media_items 表**：
- id (TEXT, PRIMARY KEY, UUID)
- original_name (TEXT)
- storage_name (TEXT)
- file_path (TEXT)
- thumbnail_path (TEXT)
- type (TEXT) — "image", "video", "audio"
- mime_type (TEXT)
- size (INTEGER)
- width (INTEGER, nullable)
- height (INTEGER, nullable)
- duration (INTEGER, nullable) — 视频/音频时长（毫秒）
- sha256_hash (TEXT)
- created_at (INTEGER)
- updated_at (INTEGER)
- 索引：created_at, type, sha256_hash

**albums 表**：
- id (TEXT, PRIMARY KEY, UUID)
- name (TEXT)
- parent_id (TEXT, nullable, FOREIGN KEY → albums.id, CASCADE)
- cover_media_id (TEXT, nullable)
- sort_order (INTEGER)
- created_at (INTEGER)
- 索引：parent_id

**album_media 表**（多对多关联）：
- id (TEXT, PRIMARY KEY, UUID)
- album_id (TEXT, FOREIGN KEY → albums.id)
- media_id (TEXT, FOREIGN KEY → media_items.id)
- created_at (INTEGER)

**tags 表**：
- id (TEXT, PRIMARY KEY, UUID)
- name (TEXT)
- color (TEXT, nullable)
- parent_id (TEXT, nullable, FOREIGN KEY → tags.id, CASCADE)
- created_at (INTEGER)
- 索引：parent_id

**media_tags 表**（多对多关联）：
- id (TEXT, PRIMARY KEY, UUID)
- media_id (TEXT, FOREIGN KEY → media_items.id)
- tag_id (TEXT, FOREIGN KEY → tags.id)
- created_at (INTEGER)

**notes 表**：
- id (TEXT, PRIMARY KEY, UUID)
- media_id (TEXT, FOREIGN KEY → media_items.id, CASCADE)
- content (TEXT)
- created_at (INTEGER)
- updated_at (INTEGER)
- 索引：media_id

**DAO 接口规范**：

MediaItemDao：
- insert(mediaItem) → Long
- insertAll(mediaItems) → List<Long>
- update(mediaItem)
- delete(mediaItem)
- getById(id) → MediaItemEntity?
- observeById(id) → Flow<MediaItemEntity?>
- observeAll() → Flow<List<MediaItemEntity>>
- getAll() → List<MediaItemEntity>
- getByHash(hash) → MediaItemEntity?
- observeByType(type) → Flow<List<MediaItemEntity>>
- deleteById(id)
- deleteAllByIds(ids)
- deleteAll()
- count() → Int
- totalSize() → Long
- searchMedia(query) → Flow<List<MediaItemEntity>>（文件名 LIKE + 标签名 LIKE）
- filterMedia(type, startDate, endDate, albumId, tagIds, tagCount) → Flow<List<MediaItemEntity>>
- observeWithAnyTag() → Flow<List<MediaItemEntity>>
- observeWithAnyAlbum() → Flow<List<MediaItemEntity>>
- observeWithoutAnyTag() → Flow<List<MediaItemEntity>>
- observeWithoutAnyAlbum() → Flow<List<MediaItemEntity>>
- observeByTag(tagId) → Flow<List<MediaItemEntity>>
- getPreviousMedia(mediaId) → Flow<MediaItemEntity?>
- getNextMedia(mediaId) → Flow<MediaItemEntity?>

AlbumDao：
- insert(album) → Long
- update(album)
- deleteById(id)
- getById(id) → AlbumEntity?
- observeById(id) → Flow<AlbumEntity?>
- observeAll() → Flow<List<AlbumEntity>>
- observeRootAlbums() → Flow<List<AlbumWithInfo>>
- observeChildren(parentId) → Flow<List<AlbumWithInfo>>
- observeAllAlbumsWithInfo() → Flow<List<AlbumWithInfo>>
- getBreadcrumbPath(albumId) → List<BreadcrumbItem>
- setCoverMedia(albumId, mediaId)
- getMediaCount(albumId) → Int
- ensureRootAlbum(name) → String

TagDao：
- 类似 AlbumDao 接口

NoteDao：
- insert(note) → Long
- update(note)
- deleteById(id)
- getById(id) → NoteEntity?
- getByMediaId(mediaId) → NoteEntity?
- observeByMediaId(mediaId) → Flow<NoteEntity?>
- observeAll() → Flow<List<NoteEntity>>
- deleteByMediaId(mediaId)

**待选择方案**：
- [ ] 数据库访问库：rusqlite vs sqlx vs diesel
- [ ] 数据库迁移工具：refinery vs diesel_migration vs 手动管理
- [ ] Flow 实现：自定义 Stream 封装 vs rust_stream 库

---

### 4.10 Rust 核心模块

**scanner 模块**：
- 递归扫描指定目录
- 识别媒体文件（图片：jpg, jpeg, png, gif, webp, bmp, heic；视频：mp4, mkv, avi, mov, webm；音频：mp3, wav, flac, aac, ogg, m4a）
- MIME 类型检测（通过文件 magic bytes 或扩展名）
- 跳过隐藏文件和目录
- 异步扫描（支持取消）

**thumbnail 模块**：
- 图片缩略图：使用 image crate，支持缩放、裁剪、质量调整
- 视频缩略图：使用 ffmpeg 提取首帧，或使用系统 MediaMetadataRetriever
- 缩略图缓存：磁盘缓存（LRU 策略），缓存目录管理
- 缩略图尺寸：根据设置质量动态调整（30%-100%）
- 并发控制：限制同时生成的缩略图数量

**exif 模块**：
- 读取图片 EXIF 信息（使用 kamadak-exif 或 rexif）
- 提取：拍摄时间、相机型号、GPS 坐标、方向
- 写入 EXIF（可选）

**duplicate 模块**：
- SHA-256 哈希计算（快速检测完全重复）
- Perceptual Hash（pHash）计算（检测相似图片）
- 哈希缓存（避免重复计算）

**search 模块**：
- 文本搜索：文件名 + 标签名（LIKE 查询）
- 复合筛选：类型、日期范围、相册、标签（多标签交集）
- 搜索结果排序：相关度 + 时间

**待选择方案**：
- [ ] 视频缩略图方案：ffmpeg 绑定 vs 系统 API vs opencv
- [ ] 图片处理库：image crate vs photon-rs vs 系统 API
- [ ] 异步运行时：tokio vs async-std vs smol

---

### 4.11 国际化（i18n）

**支持语言**：
- 简体中文（zh）
- 英文（en）

**实现方式**：
- Flutter 内置国际化（flutter_localizations + intl）
- ARB 文件管理翻译字符串
- 所有用户可见字符串必须通过 localized strings 获取

**待选择方案**：
- [ ] 国际化方案：Flutter 内置 vs easy_localization vs slang

---

### 4.12 主题与样式

**主题配置**：
- Material 3 动态颜色（支持 Android 12+ 动态主题）
- 主题模式：跟随系统 / 浅色 / 深色
- 自定义颜色方案（主色、次色、背景色等）

**样式规范**：
- 圆角：卡片 8.dp，按钮 24.dp，对话框 12.dp
- 间距：遵循 Material 3 规范
- 字体：使用 Material 3 字体比例
- 图标：Material Icons（Outlined / Filled / Rounded）

**待选择方案**：
- [ ] 动态颜色支持：完全支持 vs 固定配色方案
- [ ] 字体方案：系统默认 vs 自定义字体

---

## 五、性能优化需求

### 5.1 启动优化
- 避免白屏闪烁：强制深色模式 + 黑色 windowBackground
- SplashScreen 配置：立即消失，无过渡动画
- 延迟加载非关键资源

### 5.2 列表优化
- 图片懒加载：仅可见区域加载缩略图
- 图片缓存：内存缓存（Coil / cached_network_image）+ 磁盘缓存
- 网格复用：ListView / GridView 的 itemExtent 优化
- 关闭内容预览时：不加载缩略图，仅显示图标+文件名

### 5.3 视频优化
- 后台暂停：应用进入后台时暂停所有视频播放
- 解码器复用：预加载所有可播放媒体，避免重复创建
- 视频 fit 算法：保持原始宽高比，禁止拉伸
- 视频旋转：通过 TextureView.setTransform 真正旋转视频帧

### 5.4 数据库优化
- 索引优化：created_at, type, sha256_hash, parent_id 等字段建立索引
- 查询优化：使用 EXPLAIN QUERY PLAN 分析慢查询
- 批量操作：使用事务批量插入/更新
- 分页加载：大数据集使用 LIMIT/OFFSET 分页

### 5.5 内存优化
- 图片采样：BitmapFactory.Options.inSampleSize 避免 OOM
- 大图限制：最大显示 2048×2048
- 及时释放：页面销毁时释放 ExoPlayer、Bitmap 等资源
- 缓存清理：定期清理过期缩略图缓存

---

## 六、待选择方案汇总（需用户决策）

### 6.1 架构层面
- [ ] **状态管理框架**：Riverpod vs Bloc vs MobX
- [ ] **Rust-Flutter 通信**：flutter_rust_bridge vs 手动 FFI vs ffigen
- [ ] **数据库访问库**：rusqlite vs sqlx vs diesel
- [ ] **异步运行时**：tokio vs async-std

### 6.2 功能层面
- [ ] **视频播放**：video_player 插件 vs 自定义 PlatformView
- [ ] **图片查看**：photo_view 插件 vs 自定义实现
- [ ] **文件选择**：file_picker 插件 vs 自定义文件浏览器
- [ ] **搜索算法**：SQL LIKE vs FTS5 vs 自定义索引

### 6.3 UI 层面
- [ ] **详情模式按钮布局**：7 按钮 vs 9 按钮
- [ ] **玻璃效果实现**：BackdropFilter vs 渐变蒙层
- [ ] **标签颜色功能**：保留 vs 移除
- [ ] **动态主题**：完全支持 vs 固定配色

### 6.4 性能层面
- [ ] **图片处理库**：image crate vs photon-rs
- [ ] **视频缩略图**：ffmpeg vs 系统 API vs opencv
- [ ] **导入并发**：串行 vs 并行（限制并发数）

---

## 七、开发阶段规划

### 阶段 1：基础架构搭建
- [ ] 初始化 Flutter 项目（多平台配置）
- [ ] 初始化 Rust 项目（flutter_rust_bridge 配置）
- [ ] 配置数据库连接和表结构
- [ ] 配置主题和国际化
- [ ] 配置 CI/CD（GitHub Actions）

### 阶段 2：核心功能实现
- [ ] 文件扫描和导入
- [ ] 媒体数据库 CRUD
- [ ] 缩略图生成和缓存
- [ ] 首页媒体网格展示
- [ ] 媒体查看器（图片浏览）

### 阶段 3：高级功能实现
- [ ] 视频播放功能
- [ ] 相册层级管理
- [ ] 标签层级管理
- [ ] 搜索功能
- [ ] 设置页面

### 阶段 4：优化和打磨
- [ ] 性能优化（启动、列表、视频）
- [ ] UI 动画优化
- [ ] 错误处理和日志
- [ ] 单元测试和集成测试
- [ ] 文档完善

### 阶段 5：发布准备
- [ ] 多平台构建测试
- [ ] 应用签名和打包
- [ ] 应用商店准备
- [ ] 用户文档

---

## 八、参考项目已完成功能（迁移参考）

参考项目（Android Kotlin + Jetpack Compose）已实现以下功能，需全部迁移：

1. 媒体查看器 UI 优化（ViewPager、手势优化、视频布局）
2. 六大功能全面升级（Home、Album、Tag、Search、Settings、Import）
3. 性能优化（i18n、缓存、图片采样）
4. 设置页性能优化 + 导出闪退修复
5. 详情模式悬浮窗 + 视频真正旋转 + SplashScreen
6. 多选模式 + 长按动作菜单
7. 文件浏览器全屏覆盖
8. 搜索历史 + 标签筛选
9. 存储统计 + 清理缓存
10. 数据备份/恢复/导出

---

## 九、验收标准

### 9.1 功能验收
- [ ] 所有参考项目功能完整迁移
- [ ] 新增跨平台支持（Windows、iOS、Linux）
- [ ] 所有待选择方案已由用户确认
- [ ] 所有平台构建通过

### 9.2 性能验收
- [ ] 启动时间 < 2 秒
- [ ] 列表滑动帧率 > 55fps
- [ ] 内存占用稳定，无 OOM
- [ ] 视频播放 CPU 占用合理

### 9.3 质量验收
- [ ] 单元测试覆盖率 > 70%
- [ ] 无内存泄漏
- [ ] 无崩溃（Crash-free rate > 99%）
- [ ] 国际化完整（所有用户可见字符串已翻译）

---

## 十、附录

### 10.1 命名规范
- Dart：lowerCamelCase（变量/函数），UpperCamelCase（类/枚举），UPPER_SNAKE_CASE（常量）
- Rust：snake_case（函数/变量），UpperCamelCase（类型/枚举/结构体），SCREAMING_SNAKE_CASE（常量）
- 文件：snake_case.dart / snake_case.rs

### 10.2 代码规范
- 禁止硬编码字符串（必须使用国际化）
- 禁止硬编码颜色（必须使用主题）
- 禁止裸异常捕获（必须记录日志）
- 禁止同步阻塞主线程操作
- 所有数据库操作必须加索引说明
- 所有 API 必须加文档注释

### 10.3 错误处理规范
- Rust：使用 Result<T, E>，禁止 unwrap/expect（测试除外）
- Dart：使用 try-catch + 日志记录，用户可见错误必须显示 Snackbar/Toast
- FFI 边界：Rust 错误必须转换为 Dart 异常，包含错误码和错误信息

---

> 本文档为活文档，随开发进度持续更新。任何变更必须经过用户确认。
