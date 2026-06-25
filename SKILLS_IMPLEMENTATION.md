# AdvanceMediaKB-FR 项目实施状态文档

> 本文档记录实际开发中已选择的技术方案和实现状态。
> 更新日期：2026-06-24

---

## 一、已确定的技术方案

### 1.1 架构层面

| 方案 | 选择 | 状态 |
|------|------|------|
| 状态管理框架 | **Bloc** (flutter_bloc 8.1.6) | ✅ 已实现 |
| Rust-Flutter 通信 | **flutter_rust_bridge** 2.12.0 | ✅ 已实现 |
| 数据库访问库 | **sqlx** 0.7 + SQLite | ✅ 已实现 |
| 异步运行时 | **tokio** 1.x | ✅ 已实现 |
| 数据库迁移 | **refinery** 0.8 | ✅ 已实现 |

### 1.2 功能层面

| 方案 | 选择 | 状态 |
|------|------|------|
| 视频播放 | **video_player** 2.9.1 + **chewie** 1.8.5 | ✅ 已实现 |
| 图片查看 | **photo_view** 0.15.0 | ✅ 已实现 |
| 文件选择 | **file_picker** 8.0.7 | ✅ 已实现 |
| 搜索算法 | **SQL LIKE** 查询 | ✅ 已实现 |
| 图片处理 | **image** crate 0.24 | ✅ 已实现 |
| EXIF 读取 | **kamadak-exif** 0.5 | ✅ 已实现 |

### 1.3 UI 层面

| 方案 | 选择 | 状态 |
|------|------|------|
| 主题框架 | **Material 3** + dynamic_color | ✅ 已实现 |
| 主题模式 | 跟随系统 / 浅色 / 深色 | ✅ 已实现 |
| 图标 | Material Symbols Icons | ✅ 已实现 |

### 1.4 其他依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| path_provider | 2.1.4 | 路径管理 |
| permission_handler | 11.3.1 | 权限管理 |
| shared_preferences | 2.3.2 | 设置持久化 |
| cached_network_image | 3.4.1 | 图片缓存 |
| logger | 2.4.0 | 日志记录 |
| equatable | 2.0.7 | 状态比较 |

---

## 二、实际目录结构

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
│   │   ├── home_screen.dart       # 首页（底部导航三标签）
│   │   ├── media_screen.dart      # 媒体浏览页
│   │   ├── media_detail_screen.dart # 媒体详情查看器
│   │   ├── album_screen.dart      # 相册浏览页
│   │   ├── tag_screen.dart        # 标签浏览页
│   │   └── settings_screen.dart   # 设置页
│   ├── widgets/                   # 可复用组件
│   │   ├── media_grid.dart        # 媒体网格展示
│   │   └── search_bar.dart        # 搜索栏
│   └── src/rust/                  # FFI 生成代码
│       ├── frb_generated.dart     # 桥接代码（已手动修复）
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
└── test/                          # 测试目录
```

---

## 三、已实现功能

### 3.1 数据库模块（Rust）
- [x] SQLite 数据库连接池（全局单例）
- [x] 所有表结构创建（media_items, albums, tags, media_albums, media_tags, notes, app_settings）
- [x] 索引优化（created_at, type, sha256_hash, parent_id 等）
- [x] 媒体项 CRUD
- [x] 相册 CRUD（无限嵌套）
- [x] 标签 CRUD（无限嵌套）
- [x] 笔记 CRUD（UPSERT 模式）
- [x] 搜索功能（SQL LIKE + 内存过滤）
- [x] 设置持久化
- [x] 文件扫描和导入
- [x] 导入导出功能

### 3.2 Flutter 前端
- [x] 应用主题（Material 3，支持浅色/深色/跟随系统）
- [x] 首页底部导航（全部媒体 / 相册 / 标签）
- [x] 媒体网格展示
- [x] 媒体详情查看器（图片浏览、视频播放、音频播放）
- [x] 相册浏览（面包屑导航、层级管理）
- [x] 标签浏览（面包屑导航、层级管理）
- [x] 搜索功能（实时搜索、防抖）
- [x] 设置页面（主题、网格列数、导入导出、数据清理）
- [x] 文件扫描导入
- [x] 多选模式（基础框架）

### 3.3 FFI 桥接
- [x] flutter_rust_bridge 集成
- [x] 所有 API 函数 Dart 绑定（手动修复）
- [x] 类型映射（枚举、结构体、Option、Vec）

---

## 四、待实现功能（与参考项目差距）

### 4.1 高优先级
- [ ] 多选模式完整实现（底部操作栏、批量操作）
- [ ] 媒体详情模式的图片变换（缩放、旋转、平移）
- [ ] 视频详情模式播放控件
- [ ] 文件信息对话框（完整 EXIF 显示）
- [ ] 导出到 Download 目录功能
- [ ] 搜索历史记录
- [ ] 标签筛选器（AND/OR 模式）
- [ ] 存储统计和缓存清理
- [ ] 未引用文件查找

### 4.2 中优先级
- [ ] 相册封面设置
- [ ] 添加到相册对话框
- [ ] 标签选择器对话框（多选/筛选模式）
  - [x] 文件浏览器对话框（全屏，支持多选，目录导航）
  - [ ] 导入进度对话框
  - [ ] 冲突处理策略（跳过/替换/保留两者）
  - [ ] 缩略图质量设置
  - [ ] 网格列数按页面独立设置
  - [ ] 预测性返回动画

### 4.3 低优先级
- [ ] 国际化完整实现（ARB 文件）
- [ ] 动态颜色支持（Android 12+）
- [ ] 富文本笔记
- [ ] 分享功能
- [ ] 检查更新
- [ ] 隐私政策页面
- [ ] 开源许可页面

---

## 五、已解决问题

### 5.1 已修复的关键问题
- ✅ APP 白屏问题：Rust 动态库未打包到 APK → 手动创建 jniLibs 目录结构并复制 Rust 库
- ✅ 数据库初始化失败：error code 14 (unable to open database file) → 使用 `SqliteConnectOptions::from_str()` 直接创建连接 + `libsqlite3-sys` bundled 特性
- ✅ FFI bool 类型映射错误：Dart `bool` 不能直接映射到 C `bool` → 手动修复为 `ffi.Int8`（1字节有符号整数）
- ✅ Android Scoped Storage 限制：导出到系统 Download 目录失败 → 改为导出到应用外部存储目录
- ✅ Java 21 与 Gradle/AGP 兼容性问题 → 降级到 Java 17

## 六、已知问题

### 6.1 环境问题
- VirtualBox 共享文件夹不支持符号链接，导致编译器链接器崩溃
- 磁盘配额限制导致 `/tmp` 也无法编译
- `flutter_rust_bridge_codegen generate` 无法运行（cargo expand 失败）

### 6.2 代码问题
- `frb_generated.dart` 为手动修复版本，非自动生成
- 部分 FFI 函数签名可能与最新 codegen 不兼容
- 缺少完整的单元测试

### 6.3 功能限制
- 视频缩略图生成未实现（需要 ffmpeg 或系统 API）
- 重复文件检测未实现（pHash）
- 后台任务处理未实现

### 6.4 近期修复
- ✅ 导入文件后无显示问题：改用 await importSingleFile() + 导入后刷新列表
- ✅ 文件浏览器：新增全屏 FileBrowserDialog，支持浏览所有文件并选择导入
- ✅ 文档整合：SKILLS.md/PART2/PART3 已合并为统一设计文档
- ✅ 文档清理：SKILLS_PART2.md 和 SKILLS_PART3.md 已删除

---

## 七、开发阶段状态

| 阶段 | 状态 |
|------|------|
| 阶段 1：基础架构搭建 | ✅ 完成 |
| 阶段 2：核心功能实现 | ✅ 完成 |
| 阶段 3：高级功能实现 | 🔄 部分完成 |
| 阶段 4：Android 构建与 FFI 测试 | ✅ 完成（APK 47.5MB，8/8 API 通过） |
| 阶段 5：优化和打磨 | ⏳ 未开始 |
| 阶段 6：发布准备 | ⏳ 未开始 |

---

## 八、验收标准状态

### 7.1 功能验收
- [ ] 所有参考项目功能完整迁移（部分完成）
- [x] 新增跨平台支持（代码层面支持 Windows/iOS/Android/Linux）
- [x] 所有待选择方案已确认
- [x] Android 平台构建通过（APK 47.5MB，Rust 动态库正确加载）
- [x] 所有 Rust FFI 接口测试通过（8/8）
- [ ] 其他平台构建通过（环境问题阻塞）

### 7.2 性能验收
- [ ] 启动时间 < 2 秒
- [ ] 列表滑动帧率 > 55fps
- [ ] 内存占用稳定，无 OOM
- [ ] 视频播放 CPU 占用合理

### 7.3 质量验收
- [ ] 单元测试覆盖率 > 70%
- [ ] 无内存泄漏
- [ ] 无崩溃（Crash-free rate > 99%）
- [ ] 国际化完整

---

## 九、下一步建议

1. **解决编译环境问题**：将项目复制到本地非共享目录进行编译验证
2. **完善高优先级功能**：多选模式、图片变换、搜索历史
3. **补充单元测试**：Rust 侧 DAO 测试、Flutter 侧 Bloc 测试
4. **性能优化**：图片懒加载、列表复用、缩略图缓存
5. **国际化**：创建 ARB 文件，替换所有硬编码字符串
6. **其他平台构建**：iOS、Windows、Linux 构建验证

---

> 本文档为活文档，随开发进度持续更新。
> 最后更新：2026-06-25 - 修复导入问题，添加文件浏览器，合并设计文档
