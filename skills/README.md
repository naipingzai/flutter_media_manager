# AdvanceMediaKB Skills 执行手册

## 使用说明

本目录包含 AdvanceMediaKB 项目的全部实现技能（Skills），按执行顺序编号。

**执行规则（强制）**：
1. 必须从 skill-00 开始，按编号顺序依次执行
2. 每个 skill 中的每一项都必须完整实现，**禁止跳过、简化、预留、不实现**
3. 每个 skill 完成后必须通过该 skill 中列出的验证标准
4. 如果某个 skill 依赖其他 skill，必须先完成依赖项
5. 本文档只描述**流程、规范和行为**，不预设技术栈。实现者自行选择合适的技术方案

## Skills 清单

| Skill | 文件 | 依赖 | 说明 |
|-------|------|------|------|
| skill-00 | skill-00-project-architecture.md | 无 | 项目架构与模块划分规范 |
| skill-01 | skill-01-data-model.md | 00 | 数据模型：全部实体、字段、约束、索引 |
| skill-02 | skill-02-database-layer.md | 01 | 数据库层：全部查询、事务、响应式数据流 |
| skill-03 | skill-03-design-system.md | 00 | 设计系统：颜色、字体、间距、动画完整规范 |
| skill-04 | skill-04-permission-management.md | 00 | 权限管理：全部权限申请流程与降级策略 |
| skill-05 | skill-05-file-scanner.md | 04 | 文件扫描器：目录扫描、文件过滤、面包屑导航 |
| skill-06 | skill-06-media-import-pipeline.md | 01, 05 | 媒体导入管线：6步处理、去重、进度、结果报告 |
| skill-07 | skill-07-thumbnail-generator.md | 00 | 缩略图生成器：图片缩放、视频帧提取、缓存策略 |
| skill-08 | skill-08-settings-storage.md | 00 | 设置存储：全部设置项、持久化、默认值 |
| skill-09 | skill-09-app-shell-and-navigation.md | 00 | 应用壳与导航：Activity、路由、覆盖层、返回栈 |
| skill-10 | skill-10-home-screen.md | 03, 09 | 首页：媒体网格、过滤器、多选、导入触发 |
| skill-11 | skill-11-album-module.md | 03, 09 | 相册模块：列表、详情、无限层级、CRUD |
| skill-12 | skill-12-tag-module.md | 03, 09 | 标签模块：列表、层级、颜色、CRUD |
| skill-13 | skill-13-detail-screen.md | 03, 09 | 详情页：媒体预览、信息面板、标签面板、笔记面板 |
| skill-14 | skill-14-note-module.md | 03, 09 | 笔记模块：列表、编辑器、关联/独立笔记 |
| skill-15 | skill-15-search-module.md | 03, 09 | 搜索模块：实时搜索、媒体结果、笔记结果 |
| skill-16 | skill-16-settings-screen.md | 03, 08, 09 | 设置页面：主题、语言、网格列数、内容预览 |
| skill-17 | skill-17-fullscreen-viewer.md | 00 | 全屏查看器：翻页、缩放、视频播放、沉浸式 |
| skill-18 | skill-18-internationalization.md | 00, 08 | 国际化：中英文全部字符串、语言切换 |
| skill-19 | skill-19-state-machine.md | 00, 01, 06, 08 | 状态机与异常处理：全部状态转换、异常场景、恢复策略 |
| skill-20 | skill-20-testing.md | 00~19 | 测试验证：验收标准、手动测试场景、边界测试 |

---

## 全局约束与禁止行为

以下是贯穿所有 skill 的硬性约束，**任何 skill 实现中都不得违反**：

### UI/UX 约束
- **所有用户可见字符串必须使用字符串资源**（`@string/xxx`），禁止硬编码中文/英文
- **所有 UI 必须支持 RTL 布局**（阿拉伯语等从右到左语言）
- **所有可交互元素必须有最小触摸区域 48dp × 48dp**
- **所有列表必须使用 RecyclerView 或 LazyColumn**（Compose），禁止使用 ScrollView 嵌套列表
- **所有对话框必须支持返回键关闭**
- **所有覆盖层（BottomSheet/覆盖层）必须支持下滑关闭**

### 数据约束
- **所有数据库操作必须在后台线程执行**，禁止在主线程执行数据库读写
- **所有数据库写操作必须使用事务**
- **删除媒体文件时必须级联清理**：数据库记录 + 文件 + 缩略图 + 标签关联 + 相册关联 + 笔记
- **所有 Flow 查询必须使用 `Dispatchers.IO`**

### 架构约束
- **UI 层不得直接依赖数据库层**，必须通过 ViewModel + Repository
- **ViewModel 不得持有 Activity/Fragment 引用**
- **覆盖层使用 BackStack 管理**，不使用嵌套 NavHost
- **Compose 和 View 系统可混用**，但单个页面内应保持一致

### 性能约束
- **图片加载必须使用 Coil**，禁止直接使用 BitmapFactory
- **缩略图必须使用独立的缩略文件**，禁止在列表中加载原图
- **视频缩略图提取必须在 IO 线程执行**
- **列表项点击必须防抖（300ms）**，防止重复跳转

### 安全约束
- **删除操作必须有确认对话框**，禁止一键直接删除
- **清除全部数据必须有双重确认**
- **文件路径必须验证**，防止路径遍历攻击
