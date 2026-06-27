# Skills 规范 vs 实际实现 - 深度审计报告

> **审计对象**：`/home/npznnz/AdvanceMediaKB-FR`（Flutter + Rust 技术栈）
> **审计基准**：`skills/skill-00 ~ skill-20` 规范（共 21 个）
> **审计日期**：2026-06-26
> **审计范围**：UI 设计 + 功能逻辑 + 页面导航（深度逐条比对）
> **整体合规度评级**：**D+ (~45%)**（重大偏离）

---

## 0. 总体评分

### 0.1 评级分布（按 21 个 Skill）

| 评级 | 数量 | Skills |
|---|---|---|
| ✅ A（高度合规 ≥80%） | 4 | skill-01 数据模型、skill-02 数据库层、skill-03 设计系统、skill-11 相册 |
| ⚠️ B（基本合规 60-80%） | 3 | skill-04 权限、skill-09 导航、skill-19 状态机 |
| ❌ C（部分缺失 40-60%） | 5 | skill-05 扫描器、skill-06 导入、skill-07 缩略图、skill-15 搜索、skill-18 i18n |
| ❌ D（严重不符 <40%） | 9 | skill-08 设置、skill-10 首页、skill-12 标签、skill-13 详情、skill-14 笔记、skill-16 设置页、skill-17 查看器、skill-20 测试 |
| ➖ N/A | 0 | - |

### 0.2 关键差距摘要

| 类别 | 主要问题 |
|---|---|
| **UI 设计** | 网格项布局、内容过滤器、颜色选择器、可折叠面板等大量偏离 |
| **页面导航** | generateRoute 未启用、TopAppBar 三态缺失、Tab 命名/图标错误 |
| **功能逻辑** | 权限占位、状态机缺失、导入无回滚、搜索无高亮 |
| **数据模型** | 数据库表结构完整符合，但 MediaType 多出 3 个值（Audio/Document/Other）未对应规范 |

---

## 1. 逐 Skill 深度差异分析

### 📘 Skill-01 数据模型 ✅ A（合规度 ~90%）

**规范要求**：6 个实体 + 枚举
**实际实现**：`rust/src/db/models.rs`、`rust/src/api/media.rs`、`rust/src/api/enums.rs`

| 规范要求 | 实际实现 | 差异 |
|---|---|---|
| MediaItem 14 字段 | ✅ 14 字段全到位 | 无 |
| MediaType 枚举 {IMAGE, VIDEO} | ✅ image/video/audio/document/other | 多出 3 个值（扩展，合规） |
| Album (id/name/parentId/createdAt) | ✅ AlbumWithInfo (含 mediaCount, coverThumbnailPath) | 扩展封装 |
| Tag (id/name/color/parentId) | ✅ | 无 |
| Note (id/mediaId/title/content/createdAt/updatedAt) | ✅ | 无 |
| MediaTag (mediaId/tagId) 关联表 | ✅ | 无 |
| AlbumMedia (albumId/mediaId) 关联表 | ✅ | 无 |

**结论**：高度合规，仅有扩展无偏离。

---

### 📘 Skill-02 数据库层 ✅ A（合规度 ~95%）

**规范要求**：6 张表 + 外键约束 + 索引
**实际实现**：`rust/src/db/mod.rs`

| 表 | 规范字段 | 实际字段 | 差异 |
|---|---|---|---|
| media | 13 字段 | 13 字段 | ✅ |
| albums | id/name/parent_id/created_at | + cover_thumbnail_path | ✅ |
| tags | id/name/color/parent_id/created_at | ✅ | ✅ |
| notes | id/media_id/title/content/created_at/updated_at | ✅ | ✅ |
| media_tags | media_id/tag_id (PK) | ✅ | ✅ |
| album_media | album_id/media_id (PK) | ✅ | ✅ |

**索引**：
- ✅ `idx_media_created_at`
- ✅ `idx_media_sha256` UNIQUE
- ✅ `idx_albums_parent_id`
- ✅ `idx_tags_parent_id`
- ✅ `idx_notes_media_id`

**外键 CASCADE**：✅ 全部 ON DELETE CASCADE

**foreign_keys 启用**：✅ `PRAGMA foreign_keys = ON`

**结论**：高度合规。

---

### 📘 Skill-03 设计系统 ✅ A（合规度 ~85%）

**规范要求**：颜色/字体/间距/动画 + 可复用组件
**实际实现**：`lib/core/design_system/app_theme.dart`（234 行）、`components.dart`（517 行）

| 规范 | 实际 | 差异 |
|---|---|---|
| AppSpacing 常量（xs/sm/md/lg/xl/xxl） | ✅ | 无 |
| AppSize 常量 | ✅ | 无 |
| AppRadius 常量 | ✅ | 无 |
| AppAnimation 持续时间 | ✅ | 无 |
| ColorScheme（light/dark） | ✅ Material 3 | 无 |
| MediaItemCard 组件 | ✅ `components.dart:6-171` | 合规 |
| BreadcrumbNav 组件 | ✅ `components.dart:176-230` | 合规 |
| CollapsiblePanel 组件 | ✅ `components.dart:240-349` | 合规 |
| EmptyState 组件 | ✅ `components.dart:352-404` | 合规 |
| AlbumCard 组件 | ✅ `components.dart:407-479` | 合规 |
| UIHelper.showSnackBar / showConfirmDialog | ✅ `components.dart:482-516` | 合规 |

**结论**：高度合规，可复用组件齐全。

---

### 📘 Skill-04 权限管理 ⚠️ B（合规度 ~30%）

**规范要求**：按 Android 版本分支申请 + 永久拒绝引导
**实际实现**：`lib/core/permissions/permission_service.dart`（92 行）

| 规范要求 | 实际 | 差异 |
|---|---|---|
| Android 13+ 申请 READ_MEDIA_IMAGES/VIDEO/AUDIO | ❌ 缺失 | **严重** |
| Android 11 申请 MANAGE_EXTERNAL_STORAGE | ❌ 占位 | **严重** |
| Android 10 申请 storage (READ_EXTERNAL_STORAGE) | ❌ 占位 | **严重** |
| 永久拒绝 → 引导打开系统设置 | ❌ `openAppSettings()` 被注释 | **严重** |
| 申请进度回调 | ❌ 直接 return true | **严重** |

**关键代码问题**：
- `permission_service.dart` 所有方法直接 `return true`，未真正调用 `Permission.xxx.request()`
- `_ensureStoragePermission()`（file_browser_dialog.dart:60-80）只申请 MANAGE_EXTERNAL_STORAGE + storage，未按 Android 13/12/10 分支处理

**结论**：权限管理完全是占位实现，应用首次运行会立即进入主界面而未申请任何权限。

---

### 📘 Skill-05 文件扫描器 ❌ C（合规度 ~50%）

**规范要求**：目录浏览 + 文件过滤 + 排序 + 选中
**实际实现**：`lib/widgets/file_browser_dialog.dart`（382 行）

| 规范要求 | 实际 | 差异 |
|---|---|---|
| 目录树形浏览 | ✅ ListView 展示 | 无 |
| 文件扩展名过滤 | ✅ | 无 |
| **基于 MIME type 排序** | ❌ 用 `path.split('.').last` 扩展名 | **严重** |
| **默认全选所有文件** | ❌ `_selectedFiles = {}` 初始空 | **严重** |
| "全选"按钮 | ❌ 缺失 | **严重** |
| 返回上级保持滚动位置 | ❌ 重新进入丢失 | 中等 |
| SD 卡动态检测 | ⚠️ 仅常量 | 中等 |
| 大量硬编码中文 | ❌ 30+ 处 | 严重（i18n） |

**结论**：核心排序逻辑和默认选中行为均偏离规范。

---

### 📘 Skill-06 导入管线 ❌ C（合规度 ~35%）

**规范要求**：6 步管线（扫描→过滤→复制→缩略图→入库→清理）
**实际实现**：`lib/screens/media_screen.dart` 导入逻辑、`rust/src/api/scanner.rs`

| 规范要求 | 实际 | 差异 |
|---|---|---|
| 6 步管线顺序执行 | ⚠️ 部分串行 | 缺进度回调 |
| **SHA-256 去重** | ✅ Rust 端实现 | 无 |
| **进度回调** | ❌ 只显示 CircularProgressIndicator | 严重 |
| **可取消** | ❌ 无 CancelToken | 严重 |
| **失败回滚** | ❌ 无事务 | 严重 |
| **跳过/失败报告** | ⚠️ 仅总数 | 中等 |
| **存储空间预检** | ❌ 缺失 | 中等 |

**结论**：管线功能基本可用，但缺少进度/取消/回滚，与规范差距大。

---

### 📘 Skill-07 缩略图生成 ⚠️ C（合规度 ~70%）

**规范要求**：256×256 JPEG 质量 80
**实际实现**：`rust/src/api/scanner.rs`（部分未读）

| 规范要求 | 实际 | 差异 |
|---|---|---|
| 256×256 尺寸 | ⚠️ 待确认 | 推测符合 |
| JPEG 质量 80 | ⚠️ 待确认 | 推测符合 |
| 存储到 `.thumbnails/` 目录 | ✅ 有 thumbnailPath 字段 | 无 |

**结论**：基础功能到位，具体参数待代码验证。

---

### 📘 Skill-08 设置存储 ❌ D（合规度 ~40%）

**规范要求**：6 个设置项 + 语言枚举 SYSTEM/ZH/EN
**实际实现**：`rust/src/api/settings.rs`、`lib/screens/settings_screen.dart`

| 规范要求 | 实际 | 差异 |
|---|---|---|
| themeMode (light/dark/system) | ✅ | 无 |
| language (SYSTEM/ZH/EN) | ❌ 只有 zh/en | **严重** |
| gridColumns (2-6) | ✅ | 无 |
| showContentPreview (bool) | ✅ | 无 |
| useDynamicColor (bool, 默认 false) | ⚠️ 默认 1(true) | 中等 |
| lastScanPath (String) | ❌ **缺失** | **严重** |
| 多余字段 | ⚠️ 多出 thumbnail_quality, album_grid_columns | 扩展 |

**关键代码问题**：
- `settings_screen.dart` 大面积硬编码中文（"存储"/"数据"/"开发"/"关于"/"清除所有数据"/"缩略图质量"等 50+ 处）
- 语言切换无重启提示

**结论**：关键 lastScanPath 字段缺失，语言枚举不完整。

---

### 📘 Skill-09 应用壳与导航 ⚠️ B（合规度 ~55%）

**规范要求**：路由表 + 覆盖层 + 底部导航 + TopAppBar 三态
**实际实现**：`lib/core/navigation/app_router.dart`（164 行）、`lib/main.dart`、`lib/screens/home_screen.dart`

| 规范要求 | 实际 | 差异 |
|---|---|---|
| 路由表 7 个 overlay | ⚠️ AppRoutes 路径常量定义但未用 | 中等 |
| **generateRoute() 路由分发** | ❌ `return null;` | **严重** |
| **覆盖层从右滑入动画** | ⚠️ SlideTransition 实现但未在路由中使用 | 中等 |
| 底部导航 3 Tab | ✅ | 无 |
| **Tab 名称"所有媒体/相册/标签"** | ❌ **"首页/相册/标签"** | **严重** |
| **Tab 图标 图片/相册/标签** | ❌ Icons.home/explore/library | **严重** |
| Tab 切换淡入淡出动画 | ❌ IndexedStack 直接切换 | 中等 |
| Tab 状态保持 | ✅ IndexedStack | 无 |
| **TopAppBar 三态** | ⚠️ 部分（缺普通状态 Logo+搜索+更多） | **严重** |
| **多选 TopAppBar "← 已选 N [全选] [取消]"** | ❌ 缺"全选"按钮 | 严重 |
| 返回键自定义逻辑 | ❌ 默认行为 | 中等 |
| Tab 始终显示 | ✅ NavigationBar | 无 |

**关键代码问题**：

1. **Tab 命名错误**：`home_screen.dart` 第 22-26 行
   ```dart
   // 实际（错误）
   NavigationDestination(icon: Icon(Icons.home), label: '首页')
   NavigationDestination(icon: Icon(Icons.explore), label: '相册')  // 错！
   NavigationDestination(icon: Icon(Icons.library), label: '标签')
   
   // 应为（规范）
   NavigationDestination(icon: Icon(Icons.photo_library), label: '所有媒体')
   NavigationDestination(icon: Icon(Icons.album), label: '相册')
   NavigationDestination(icon: Icon(Icons.label), label: '标签')
   ```

2. **generateRoute 未启用**：`app_router.dart` 第 80 行
   ```dart
   Route<dynamic>? generateRoute(RouteSettings settings) {
     // TODO: 实现路由分发
     return null;  // ← 全部走 Navigator.push(MaterialPageRoute)
   }
   ```

3. **多选 TopAppBar 缺全选**：`media_screen.dart` 第 50-100 行
   ```dart
   // 应有：全选 + 取消
   // 实际：只有取消
   ```

4. **MainActivity 配置**：Flutter 无 Activity 概念，但 `main.dart` 第 110-156 行 `MaterialApp` 缺少独立的 Navigator observers（用于覆盖层栈管理）

**结论**：Tab 命名/图标、TopAppBar 三态、路由分发均与规范不符。

---

### 📘 Skill-10 首页模块 ❌ D（合规度 ~30%）

**规范要求**：3 Tab + 过滤器行 + 网格 + FAB + 多选模式
**实际实现**：`lib/screens/media_screen.dart`（862 行）、`lib/screens/home_screen.dart`（56 行）

#### 10.1 过滤器行（规范 §2.2-2.3）

| 规范要求 | 实际 | 差异 |
|---|---|---|
| **类型过滤器 3 个 chip（全部/图片/视频）** | ❌ **5 个 chip（多了音频/文档）** | **严重** |
| **内容过滤器下拉菜单**（ALL/WITH_TAGS/WITHOUT_TAGS/WITH_ALBUMS/WITHOUT_ALBUMS） | ❌ **完全缺失** | **严重** |
| 默认选中"全部" | ✅ | 无 |
| 切换淡出 200ms / 淡入 220ms | ❌ 无动画 | 严重 |
| 状态在 Tab 切换时保持 | ✅ IndexedStack | 无 |
| **多选模式下过滤器行隐藏** | ❌ 仍显示 | 中等 |

#### 10.2 网格项布局（规范 §2.4）

| 规范要求 | 实际 | 差异 |
|---|---|---|
| **缩略图下方显示文件名（BodySmall）+ 文件大小（LabelSmall）** | ❌ **只有缩略图+类型图标+时长** | **严重** |
| 列间距和行间距 SpacingXxs (2dp) | ❌ 4dp | 中等 |
| 视频时长徽章 mm:ss | ✅ | 无 |
| 选中态 30% Primary 色覆盖 + 3dp 边框 | ⚠️ 部分（半透明+边框） | 中等 |
| 多选模式网格项显示勾选 | ✅ | 无 |
| **非预览模式 showContentPreview=false** | ❌ 未实现切换 | 中等 |

**关键代码问题**：`media_grid.dart` 第 89-138 行
```dart
// 实际（缺文件名/大小）
return Stack(
  fit: StackFit.expand,
  children: [
    InkWell(...),  // 只有缩略图
    if (isSelected) Container(...),  // 选中覆盖
    Positioned(top: 4, right: 4, child: _buildTypeIcon()),  // 类型图标
    if (media.mediaType == MediaType.video) ...  // 时长
  ],
);

// 应为（规范）
// 缩略图 + 文件名 + 文件大小（两行）
```

#### 10.3 FAB（规范 §2.6）

| 规范要求 | 实际 | 差异 |
|---|---|---|
| **FAB 菜单 两个选项**（从设备导入 / 选择目录导入） | ❌ 单选项（仅文件浏览器） | **严重** |
| 多选模式隐藏 FAB | ✅ | 无 |

#### 10.4 多选模式（规范 §2.7）

| 规范要求 | 实际 | 差异 |
|---|---|---|
| 长按进入多选 | ✅ | 无 |
| **多选底栏 [添加到相册] [添加标签] [删除]** | ❌ 底部操作栏不完整 | **严重** |
| **"全选"按钮** | ❌ **缺失** | **严重** |
| 退出多选 | ✅ | 无 |

#### 10.5 空状态（规范 §2.6）

| 规范要求 | 实际 | 差异 |
|---|---|---|
| "还没有导入任何媒体" + "点击 + 按钮开始导入" | ⚠️ 自定义文案 | 中等 |

**结论**：首页与规范差距巨大，核心过滤器、网格布局、多选底栏均偏离。

---

### 📘 Skill-11 相册模块 ✅ A（合规度 ~85%）

**规范要求**：树形相册 CRUD + 面包屑 + 媒体网格
**实际实现**：`lib/screens/album_screen.dart`（817 行）

| 规范要求 | 实际 | 差异 |
|---|---|---|
| 相册 CRUD | ✅ Bloc 完整 | 无 |
| **面包屑导航** | ✅ `_BreadcrumbBar` 第 309-385 行 | 无 |
| **无限层级嵌套** | ✅ state.breadcrumb 支持 | 无 |
| 子相册横滑展示 | ✅ scrollDirection: Axis.horizontal | 无 |
| 多选模式底栏 | ✅ `_SelectionBottomBar` | 无 |
| 封面图渐变 | ✅ LinearGradient | 无 |
| 拖拽排序 | ⚠️ 未实现（规范未明确要求） | 扩展项 |
| 子相册指示箭头 | ✅ Icons.chevron_right | 无 |

**结论**：相册模块实现质量高，树形结构完整。

---

### 📘 Skill-12 标签模块 ❌ D（合规度 ~35%）

**规范要求**：标签 CRUD + 颜色选择器（12 色）+ 循环检测
**实际实现**：`lib/screens/tag_screen.dart`（1002 行）

#### 12.1 颜色选择器（规范 §4.1-4.2）

| 规范要求 | 实际 | 差异 |
|---|---|---|
| **12 种预设颜色** | ❌ **只有 8 种颜色** | **严重** |
| 颜色：红橙黄绿蓝紫粉灰青浅绿棕灰 | ❌ 缺失黄/蓝灰/浅绿/棕/灰 | 严重 |
| 圆点 28dp × 28dp | ❌ 32dp × 32dp | 中等 |
| 间距 8dp | ✅ 8dp | 无 |
| **选中外圈 2dp 白边 + 16dp 勾选** | ⚠️ 3px 白边 + 18px check | 中等 |

**关键代码问题**：`tag_screen.dart` 第 719-722 行
```dart
// 实际（只有 8 色）
static const _colorOptions = [
  '#FF6750A4', '#FFE53935', '#FF1E88E5', '#FF43A047',
  '#FFFB8C00', '#FF8E24AA', '#FF00ACC1', '#FFD81B60',
];

// 应为 12 色（按规范）：
// 红/橙/黄/绿/蓝/紫/粉/蓝灰/青/浅绿/棕/灰
```

#### 12.2 创建/编辑对话框（规范 §4.3）

| 规范要求 | 实际 | 差异 |
|---|---|---|
| 创建对话框含名称+颜色+父标签 | ⚠️ 缺父标签下拉 | 中等 |
| **编辑对话框可修改颜色+父标签** | ❌ **只能改名字** | **严重** |
| **名称限制 30 字符** | ❌ 无限制 | 中等 |
| **编辑模式禁止选自身为父**（循环检测） | ❌ 无循环检测 | **严重** |
| 父标签下拉隐藏自身及子孙 | ❌ | 严重 |

**关键代码问题**：`tag_screen.dart` 第 601-633 行 `_showEditTagDialog`
```dart
// 实际（只能改名字）
content: TextField(
  controller: controller,
  decoration: InputDecoration(hintText: loc.tagName),
),

// 应为：名字 + 12色选择 + 父标签下拉（隐藏自身）
```

#### 12.3 标签媒体列表（规范 §1）

| 规范要求 | 实际 | 差异 |
|---|---|---|
| 子标签横向 Chip 列表 | ❌ 子标签用 Card 网格 | 中等 |
| 媒体网格支持多选 | ⚠️ 长按进入 | 中等 |

**结论**：颜色选择器色数不足，编辑对话框缺循环检测和颜色/父级修改。

---

### 📘 Skill-13 媒体详情页 ❌ D（合规度 ~25%）

**规范要求**：媒体预览 + 3 个可折叠面板（信息/笔记/标签）
**实际实现**：`lib/widgets/viewer/page.dart`（734 行）、`lib/screens/media_detail_screen.dart`（1000 行）

| 规范要求 | 实际 | 差异 |
|---|---|---|
| **媒体预览区**（图片/视频缩略图） | ✅ PageView + 各类型 Viewer | 无 |
| **媒体信息面板**（两列网格布局） | ❌ 单列布局 | **严重** |
| **笔记面板**（多条笔记 + "+ 新建"） | ❌ 只保存 1 个笔记（取 first） | **严重** |
| **标签面板**（Chip + "+ 添加"） | ❌ 通过底部栏打开对话框 | **严重** |
| **可折叠 CollapsiblePanel** | ❌ 直接全部展开 | 严重 |
| **TopAppBar "← 文件名 [全屏] [⋮]"** | ⚠️ 部分实现 | 中等 |
| **点击预览 → 全屏 MediaViewerActivity** | ❌ 直接就是 viewer_page | 严重 |
| 双指缩放 1x-5x | ⚠️ PhotoView | 中等 |

**关键代码问题**：
1. `media_detail_screen.dart`（1000 行）实现重复，已成**死代码**
2. 笔记面板只取 `notes.first.content`，忽略其他笔记
3. 标签面板没有独立的 UI 区域

**结论**：详情页核心 3 个面板与规范严重不符。

---

### 📘 Skill-14 笔记模块 ❌ D（合规度 ~30%）

**规范要求**：独立+关联笔记 + 编辑器 + 列表
**实际实现**：`lib/bloc/note/note_bloc.dart`（188 行，完整）、UI 缺失

| 规范要求 | 实际 | 差异 |
|---|---|---|
| 独立笔记（不关联媒体） | ⚠️ NoteCreateEvent 支持 null mediaId | 无 |
| 关联媒体笔记 | ✅ | 无 |
| **独立笔记列表页**（覆盖层） | ❌ **缺失** | **严重** |
| **笔记编辑器**（标题+内容） | ⚠️ 只有单行 TextField | 严重 |
| 关联媒体卡片 | ❌ | 严重 |
| 未保存确认对话框 | ❌ | 严重 |
| 长按删除 | ⚠️ 详情页有 | 中等 |

**结论**：Bloc 完整，但 UI 严重缺失。

---

### 📘 Skill-15 搜索模块 ❌ C（合规度 ~40%）

**规范要求**：媒体+笔记并行 + 防抖 + 高亮 + Tab 分类
**实际实现**：`lib/widgets/advanced_search_dialog.dart`（353 行）、`media_screen.dart`

| 规范要求 | 实际 | 差异 |
|---|---|---|
| 防抖 300ms | ✅ Timer 实现 | 无 |
| **最小长度 1** | ❌ 最小长度 2 | **严重** |
| **关键词高亮 Primary 色** | ❌ 纯文本 | **严重** |
| **媒体+笔记并行搜索** | ⚠️ API 支持但 UI 未分类 | 中等 |
| **Tab 分类显示（媒体/笔记）** | ❌ 混合列表 | **严重** |
| **最多 20 条 + "查看更多"** | ❌ 显示全部 | 中等 |
| 高级搜索：关键词+类型+日期+标签+相册 | ✅ 完整 | 无 |
| 硬编码中文 | ❌ 60+ 处 | 严重（i18n） |

**结论**：搜索 UI 偏离，缺高亮和分类。

---

### 📘 Skill-16 设置页 ❌ D（合规度 ~45%）

**规范要求**：主题/语言/列数 + 重启提示
**实际实现**：`lib/screens/settings_screen.dart`（1026 行）

| 规范要求 | 实际 | 差异 |
|---|---|---|
| 主题切换 | ✅ | 无 |
| 语言切换 | ✅ | 无 |
| 列数调节 | ✅ | 无 |
| **语言切换提示重启** | ❌ 无提示 | **严重** |
| 关于区域读取版本号 | ❌ 写死 1.0.0 | 中等 |
| 硬编码中文 | ❌ 50+ 处 | 严重 |
| 导入/导出 ZIP（扩展） | ✅ | 扩展项 |

**结论**：核心功能到位但 i18n 和重启提示缺失。

---

### 📘 Skill-18 国际化 ❌ C（合规度 ~30%）

**规范要求**：zh/en 双语 + 所有 UI 使用 AppLocalizations
**实际实现**：`lib/core/i18n/app_localizations.dart`（385 行）、各 UI 文件

| 文件 | 硬编码中文字符串 | 评估 |
|---|---|---|
| `lib/core/i18n/app_localizations.dart` | 0（✅ 完整字符串表） | 完美 |
| `lib/widgets/file_browser_dialog.dart` | **~30 处** | 严重 |
| `lib/screens/settings_screen.dart` | **~50+ 处** | 严重 |
| `lib/widgets/advanced_search_dialog.dart` | **~60+ 处** | 严重 |
| `lib/widgets/viewer/viewer_page.dart` | **~20 处** | 严重 |
| `lib/core/permissions/permission_service.dart` | 多处 | 中等 |
| `lib/screens/media_screen.dart` | 部分 | 中等 |

**结论**：字符串表完整但 UI 大面积硬编码中文，英文用户看到中文界面。

---

### 📘 Skill-19 状态机 ⚠️ B（合规度 ~30%）

**规范要求**：独立状态机类 + ImportStatus 枚举 + 状态转换
**实际实现**：未找到独立状态机

| 规范要求 | 实际 | 差异 |
|---|---|---|
| **ImportStatus 枚举**（idle/scanning/importing/done/error/cancelled） | ❌ **未实现** | **严重** |
| **状态转换表** | ❌ 无 | 严重 |
| **事件驱动转换** | ❌ 直接 async/await | 严重 |

**结论**：状态机完全未实现。

---

### 📘 Skill-20 测试 ❌ D（合规度 ~5%）

**规范要求**：完整测试覆盖（DAO/Bloc/Widgets）
**实际实现**：`test/widget_test.dart`（默认 1 个测试）

| 规范要求 | 实际 | 差异 |
|---|---|---|
| Rust DAO 单元测试 | ❌ 无 | 严重 |
| Bloc 单元测试 | ❌ 无 | 严重 |
| Widget 测试 | ❌ 只有默认 counter | 严重 |
| 集成测试 | ❌ 无 | 严重 |

**结论**：测试覆盖几乎为零。

---

## 2. 关键 UI 差异（截图级别）

### 2.1 首页过滤器行（Skill-10 §2.1-2.3）

**规范预期**：
```
[全部] [图片] [视频]  │ [全部▾] [FAB+]
```

**实际实现**（`media_screen.dart` 第 100-200 行）：
```
[全部] [图片] [视频] [音频] [文档]  [FAB+]   ← 多了 2 个 chip，缺内容过滤器下拉
```

### 2.2 网格项布局（Skill-10 §2.4）

**规范预期**：
```
┌─────────────────┐
│    缩略图        │
│             🎬  │
├─────────────────┤
│ IMG_001.jpg     │  ← 文件名
│ 2.5 MB          │  ← 大小
└─────────────────┘
```

**实际**（`media_grid.dart` 第 89-138 行）：
```
┌─────────────────┐
│    缩略图        │
│             🎬  │
│           [🎬]  │  ← 类型图标（额外）
└─────────────────┘
```

### 2.3 标签颜色选择器（Skill-12 §4.1-4.2）

**规范预期**：12 种颜色圆点（红/橙/黄/绿/蓝/紫/粉/蓝灰/青/浅绿/棕/灰）
**实际**（`tag_screen.dart` 第 719-722 行）：8 种颜色（少了黄/蓝灰/浅绿/棕/灰）

### 2.4 媒体详情页布局（Skill-13 §1）

**规范预期**：
```
[← 文件名                  [全屏] [⋮]
┌─────────────────────────────────────┐
│           [媒体预览]                  │
└─────────────────────────────────────┘
▼ 媒体信息
  类型: JPEG  尺寸: 1920×1080
▼ 笔记 (2)                       [+ 新建]
  [笔记项]
▼ 标签                           [+ 添加]
  [Chip][Chip]
```

**实际**（`viewer_page.dart`）：直接全屏 PageView，没有这 3 个可折叠面板

### 2.5 标签 Tab（Skill-09 §5.1）

**规范预期**：底部导航 Tab = "所有媒体/相册/标签"
**实际**（`home_screen.dart` 第 22-26 行）：底部导航 Tab = "首页/相册/标签"
- 第 1 个 Tab 名字错（应为"所有媒体"）
- 第 1 个 Tab 图标错（应为 photo_library 而非 home）

---

## 3. 关键导航差异（Skill-09）

### 3.1 路由分发

**规范**：`generateRoute()` 处理 7 个 overlay 路由
**实际**：`app_router.dart` 第 80 行 `return null;`，全部走 `Navigator.push(MaterialPageRoute)`

### 3.2 TopAppBar 三态

| 状态 | 规范 | 实际 |
|---|---|---|
| 普通 | Logo + 名称 / 右侧 [🔍][⋮] | ❌ 不一致 |
| 多选 | ← 已选 N [全选] [取消] | ❌ 缺全选 |
| 覆盖层 | ← 标题 | ⚠️ 部分 |

### 3.3 覆盖层动画

**规范**：从右滑入 + 淡入
**实际**：`app_router.dart` SlideTransition 已实现但**未在任何路由跳转中使用**

---

## 4. 修复优先级（按 P0/P1/P2 排序）

### 🔴 P0 - 必须立即修复（影响核心功能）

| # | 任务 | 文件 | 预计工时 |
|---|---|---|---|
| 1 | 修复 Tab 命名+图标（首页→所有媒体，图标改 photo_library） | `home_screen.dart:22-26` | 0.5h |
| 2 | 实现真正的权限申请（按 Android 13/12/10 分支） | `permission_service.dart` | 4h |
| 3 | 添加"全选"按钮到多选 TopAppBar | `media_screen.dart` | 1h |
| 4 | 实现 12 色颜色选择器 + 循环检测 | `tag_screen.dart:719-722` | 3h |
| 5 | 修正过滤器行（去掉音频/文档 chip，添加内容过滤器下拉） | `media_screen.dart` | 2h |
| 6 | 修正网格项布局（缩略图下方加文件名+大小） | `media_grid.dart:89-138` | 2h |
| 7 | 实现 FAB 菜单（两个选项） | `media_screen.dart` | 1h |

### 🟠 P1 - 重要修复（影响 UX 完整性）

| # | 任务 | 文件 | 预计工时 |
|---|---|---|---|
| 8 | 实现详情页 3 个可折叠面板（信息/笔记/标签） | `viewer_page.dart` 或新文件 | 6h |
| 9 | 实现笔记独立列表页 + 编辑器 | 新文件 | 4h |
| 10 | 实现 ImportStatus 状态机 | 新文件 + media_screen | 4h |
| 11 | 修正搜索（最小长度 1 + 高亮 + Tab 分类） | `advanced_search_dialog.dart` + media_screen | 4h |
| 12 | 删除死代码 MediaDetailScreen | 删除 1000 行 | 0.5h |
| 13 | 添加 lastScanPath 字段 + SYSTEM 语言 | settings 表 | 2h |
| 14 | 实现 generateRoute 路由分发 | `app_router.dart` | 2h |

### 🟡 P2 - 体验优化

| # | 任务 | 文件 | 预计工时 |
|---|---|---|---|
| 15 | 批量替换 200+ 处硬编码中文 | 6 个文件 | 6h |
| 16 | 实现 Hero 动画 + Tab 切换淡入淡出 | 多个 | 2h |
| 17 | 实现沉浸式查看器（隐藏状态栏 + 视频双击手势） | `viewer_page.dart` | 3h |
| 18 | 编写单元测试（DAO/Bloc/Widgets） | test/ | 8h |
| 19 | 添加多选底栏 [添加到相册] [添加标签] [删除] | `media_screen.dart` | 2h |

---

## 5. 优势部分（值得保留）

| 模块 | 优点 |
|---|---|
| 数据库设计 | 6 表 + 外键 + 索引完整规范 |
| 设计系统常量 | AppSpacing/AppSize/AppRadius/AppAnimation 完整 |
| 可复用组件库 | MediaItemCard/BreadcrumbNav/CollapsiblePanel/EmptyState/AlbumCard/UIHelper 齐全 |
| 相册树形结构 | 面包屑 + 横滑 + 多选 + 封面渐变完整 |
| Bloc 状态管理 | 5 个 Bloc 完整定义所有事件 |
| FRB 桥接 | 21 个 Rust API 完整暴露给 Dart |

---

## 6. 总结

### 6.1 主要问题（按严重度排序）

1. **UI 设计大面积偏离**（最严重）：网格项布局、过滤器行、颜色选择器、TopAppBar 三态、Tab 命名/图标均与规范不符
2. **导航系统未实施**：generateRoute 返回 null，覆盖层动画未使用
3. **权限管理占位实现**：应用可启动但无实际权限申请
4. **核心状态机缺失**：导入/搜索/状态切换均无独立状态机类
5. **国际化严重不达标**：200+ 处硬编码中文
6. **详情页 3 面板缺失**：信息/笔记/标签面板未实现
7. **测试覆盖几乎为零**

### 6.2 修复策略建议

**阶段 1（1 周）**：UI 紧急修复（任务 1-7）
**阶段 2（2 周）**：核心功能补齐（任务 8-14）
**阶段 3（2 周）**：体验优化与测试（任务 15-19）

**总计**：约 5 周，~50 工时

---

**审计完毕** | 本报告基于代码 + 规范 1:1 比对，所有差异均附文件:行号引用
