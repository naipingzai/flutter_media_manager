## 四、功能需求详细说明（续 3）

### 4.9 数据库模块（Database）- 续

**DAO 接口规范（续）**：

MediaItemDao（续）：
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

**已选择方案**：
- [x] 数据库访问库：**sqlx** 0.7
- [x] 数据库迁移工具：**refinery** 0.8
- [ ] Flow 实现：自定义 Stream 封装 vs rust_stream 库（待确认）

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

**已选择方案**：
- [ ] 视频缩略图方案：ffmpeg 绑定 vs 系统 API vs opencv（待确认）
- [x] 图片处理库：**image** crate 0.24
- [x] 异步运行时：**tokio** 1.x

---

### 4.11 国际化（i18n）

**支持语言**：
- 简体中文（zh）
- 英文（en）

**实现方式**：
- Flutter 内置国际化（flutter_localizations + intl）
- ARB 文件管理翻译字符串
- 所有用户可见字符串必须通过 localized strings 获取

**已选择方案**：
- [x] 国际化方案：**Flutter 内置**（flutter_localizations + intl）

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

**已选择方案**：
- [ ] 动态颜色支持：完全支持 vs 固定配色方案（待确认）
- [ ] 字体方案：系统默认 vs 自定义字体（待确认）

---

## 五、性能优化需求

### 5.1 启动优化
- 避免白屏闪烁：强制深色模式 + 黑色 windowBackground
- SplashScreen 配置：立即消失，无过渡动画
- 延迟加载非关键资源

### 5.2 列表优化
- 图片懒加载：仅可见区域加载缩略图
- 图片缓存：内存缓存 + 磁盘缓存
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
- 图片采样：避免 OOM
- 大图限制：最大显示 2048×2048
- 及时释放：页面销毁时释放播放器、图片等资源
- 缓存清理：定期清理过期缩略图缓存

---

## 六、待选择方案汇总（需用户决策）

### 6.1 架构层面（已确定）
- [x] **状态管理框架**：**Bloc**（flutter_bloc 8.1.6）
- [x] **Rust-Flutter 通信**：**flutter_rust_bridge** 2.12.0
- [x] **数据库访问库**：**sqlx** 0.7
- [x] **异步运行时**：**tokio** 1.x

### 6.2 功能层面（已确定）
- [x] **视频播放**：**video_player** 2.9.1 + **chewie** 1.8.5
- [x] **图片查看**：**photo_view** 0.15.0
- [x] **文件选择**：**file_picker** 8.0.7
- [x] **搜索算法**：**SQL LIKE**（当前实现）

### 6.3 UI 层面
- [ ] **详情模式按钮布局**：7 按钮 vs 9 按钮（待确认）
- [ ] **玻璃效果实现**：BackdropFilter vs 渐变蒙层（待确认）
- [x] **标签颜色功能**：**保留**
- [ ] **动态主题**：完全支持 vs 固定配色（待确认）

### 6.4 性能层面
- [x] **图片处理库**：**image** crate 0.24
- [ ] **视频缩略图**：ffmpeg vs 系统 API vs opencv（待确认）
- [ ] **导入并发**：串行 vs 并行（限制并发数）（待确认）

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
