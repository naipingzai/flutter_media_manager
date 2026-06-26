# Skill-00: 项目架构与模块划分规范

## 前置依赖
无

## 目标
建立完整的多模块项目结构，确保分层清晰、模块职责单一、依赖方向正确。

---

## 1. 分层架构

项目采用 6 层分层架构，依赖方向严格单向（上层依赖下层，下层不得依赖上层）：

```
第1层 应用壳层    → app
第2层 功能模块层  → feature-home, feature-album, feature-tag, feature-detail, feature-note, feature-search, feature-settings
第3层 UI组件层    → core-ui, core-designsystem
第4层 领域层      → domain
第5层 数据层      → data
第6层 公共基础层  → core-model, core-database, core-common, core-image
```

## 2. 模块清单与职责

每个模块必须存在，每个模块必须有完整的源码目录结构。

### 2.1 app（应用壳模块）

**职责**：
- 应用入口 Activity（主 Activity）
- 全屏查看器 Activity（独立 Activity）
- 全局导航路由定义
- 依赖注入容器初始化入口
- 所有 feature 模块的聚合点

**必须包含的组件**：
- Application 类：标注为依赖注入根节点，初始化数据库和设置存储
- 主 Activity：承载导航宿主，处理系统返回键
- 全屏查看器 Activity：独立于主 Activity，接受媒体路径/ID/索引等参数
- 导航图/路由定义：定义所有页面的路由路径和参数

**模块依赖**：
- 依赖所有 feature 模块
- 依赖 core-common, core-database, domain, data

### 2.2 core-model（数据模型模块）

**职责**：
- 定义所有实体类（Entity）
- 定义所有枚举类（Enum）
- 定义所有数据传输对象（DTO）

**模块依赖**：
- 不依赖任何其他模块（最底层）

### 2.3 core-database（数据库模块）

**职责**：
- 数据库定义（版本号、实体列表）
- 所有 DAO 接口定义
- 数据库迁移脚本
- 数据库 DI 提供

**模块依赖**：
- 依赖 core-model

### 2.4 core-designsystem（设计系统模块）

**职责**：
- 主题定义（浅色/深色/动态颜色）
- 颜色体系
- 字体排版体系
- 间距/尺寸常量
- 动画常量
- 通用 Compose 组件（如果有 UI 组件库性质的通用组件）

**模块依赖**：
- 不依赖任何其他模块

### 2.5 core-common（公共基础模块）

**职责**：
- 权限管理器
- 文件扫描器
- 设置存储（键值对持久化）
- 全屏查看器启动器接口

**模块依赖**：
- 依赖 core-model

### 2.6 core-image（图片处理模块）

**职责**：
- 图片缩放/裁切
- 视频帧提取
- 缩略图生成
- 图片缓存管理

**模块依赖**：
- 依赖 core-model

### 2.7 core-ui（UI 组件模块）

**职责**：
- 通用 UI 组件（多选底栏、过滤器行等跨 feature 复用的组件）
- 通用对话框模板

**模块依赖**：
- 依赖 core-designsystem
- 依赖 core-model

### 2.8 domain（领域层模块）

**职责**：
- Repository 接口定义（纯接口，无实现）
- UseCase 接口定义
- 领域模型（如果与 core-model 不同）

**模块依赖**：
- 依赖 core-model

### 2.9 data（数据层模块）

**职责**：
- Repository 接口的实现类
- UseCase 接口的实现类
- 数据层 DI 绑定（将实现绑定到接口）

**模块依赖**：
- 依赖 domain（实现接口）
- 依赖 core-database（访问数据库）
- 依赖 core-common（访问文件系统、设置存储）
- 依赖 core-image（缩略图生成）

### 2.10 feature-home（首页功能模块）

**职责**：
- 主页面框架（TopAppBar + 底部导航栏 + 内容区域）
- "所有媒体" Tab（媒体网格 + 过滤器 + 多选模式）
- 文件浏览器（全屏覆盖层）
- 媒体导入流程触发
- "相册" Tab（相册网格列表）
- "标签" Tab（标签列表）

**模块依赖**：
- 依赖 domain（使用 Repository 接口和 UseCase）
- 依赖 core-ui（使用通用组件）
- 依赖 core-designsystem（使用主题）
- 依赖 core-common（使用权限管理器、文件扫描器、设置存储）
- 依赖 core-model（使用实体类）
- 依赖 core-image（使用缩略图生成）

### 2.11 feature-album（相册功能模块）

**职责**：
- 相册详情页（子相册列表 + 媒体网格）
- 面包屑导航
- 创建/编辑/删除相册对话框
- 移出相册操作

**模块依赖**：
- 依赖 domain
- 依赖 core-ui
- 依赖 core-designsystem
- 依赖 core-model

### 2.12 feature-tag（标签功能模块）

**职责**：
- 标签媒体列表页（某标签下的所有媒体）
- 创建/编辑/删除标签对话框
- 标签选择器对话框（单媒体模式 + 多选模式）

**模块依赖**：
- 依赖 domain
- 依赖 core-ui
- 依赖 core-designsystem
- 依赖 core-model

### 2.13 feature-detail（详情功能模块）

**职责**：
- 媒体详情页（媒体预览 + 信息面板 + 笔记面板 + 标签面板）
- 媒体预览区
- 媒体信息面板
- 笔记面板（关联笔记列表 + 新建入口）
- 标签面板（标签 Chip 列表 + 添加/移除）

**模块依赖**：
- 依赖 domain
- 依赖 core-ui
- 依赖 core-designsystem
- 依赖 core-model
- 依赖 core-image

### 2.14 feature-note（笔记功能模块）

**职责**：
- 独立笔记列表页
- 笔记编辑页（新建/编辑）
- 未保存离开确认

**模块依赖**：
- 依赖 domain
- 依赖 core-designsystem
- 依赖 core-model

### 2.15 feature-search（搜索功能模块）

**职责**：
- 搜索页面（覆盖层）
- 搜索栏（输入框 + 防抖 + 清空）
- 媒体结果区（网格）
- 笔记结果区（列表）

**模块依赖**：
- 依赖 domain
- 依赖 core-ui
- 依赖 core-designsystem
- 依赖 core-model

### 2.16 feature-settings（设置功能模块）

**职责**：
- 设置页面（覆盖层）
- 主题模式切换
- 语言切换
- 网格列数设置
- 内容预览开关

**模块依赖**：
- 依赖 domain
- 依赖 core-designsystem
- 依赖 core-common（使用设置存储）
- 依赖 core-model

---

## 3. 模块依赖规则（强制）

### 3.1 允许的依赖方向

```
feature-* → domain → core-model ← core-database
feature-* → core-ui → core-designsystem
feature-* → core-common → core-model
feature-* → core-image → core-model
data → domain → core-model
data → core-database
data → core-common
data → core-image
app → 所有模块
```

### 3.2 禁止的依赖

- feature 模块之间**禁止直接依赖**（如 feature-home 不得 import feature-detail）
- feature 模块**禁止依赖 data 模块**（必须通过 domain 接口）
- core 层**禁止依赖 feature 层**
- domain 层**禁止依赖 data 层**
- core-designsystem **禁止依赖**任何其他模块

### 3.3 数据流向规则

- 数据从 data 层流向 domain 层（data 实现 domain 接口）
- domain 层定义接口，data 层提供实现
- feature 层只依赖 domain 接口，不直接访问 data 实现
- 依赖注入容器在 app 层配置，将 data 实现绑定到 domain 接口

---

## 4. 包命名规范

每个模块的源码根包统一为 `com.advancemediakb`，子包按模块名区分：

| 模块 | 源码根包 |
|------|---------|
| app | com.advancemediakb |
| core-model | com.advancemediakb.core.model |
| core-database | com.advancemediakb.core.database |
| core-designsystem | com.advancemediakb.designsystem |
| core-common | com.advancemediakb.common |
| core-image | com.advancemediakb.image |
| core-ui | com.advancemediakb.core.ui |
| domain | com.advancemediakb.domain |
| data | com.advancemediakb.data |
| feature-home | com.advancemediakb.feature.home |
| feature-album | com.advancemediakb.feature.album |
| feature-tag | com.advancemediakb.feature.tag |
| feature-detail | com.advancemediakb.feature.detail |
| feature-note | com.advancemediakb.feature.note |
| feature-search | com.advancemediakb.feature.search |
| feature-settings | com.advancemediakb.feature.settings |

---

## 5. 每个模块的标准目录结构

每个 Android 库模块必须包含以下目录：

```
<module>/
├── build.gradle.kts           # 模块构建脚本
└── src/
    └── main/
        ├── AndroidManifest.xml  # 清单文件（库模块通常为空或仅声明包名）
        └── java/
            └── com/
                └── advancemediakb/
                    └── <module-subpackage>/
                        └── *.kt  # 源码文件
```

app 模块额外包含：

```
app/
├── build.gradle.kts
├── proguard-rules.pro
└── src/
    └── main/
        ├── AndroidManifest.xml  # 必须声明两个 Activity
        ├── java/
        │   └── com/
        │       └── advancemediakb/
        │           ├── AdvanceMediaKBApplication.kt
        │           ├── MainActivity.kt
        │           ├── MediaViewerActivity.kt
        │           └── navigation/
        │               └── AppNavigation.kt
        └── res/
            ├── mipmap-*/        # 应用图标（全部密度）
            ├── values/          # 默认语言资源
            ├── values-en/       # 英文资源
            ├── values-zh/       # 中文资源（可选）
            └── xml/             # 配置文件
```

---

## 6. 禁止行为（反模式）

以下行为**严格禁止**，实现者不得以任何理由违反：

### 6.1 架构违反
- **禁止** feature 模块之间直接 import（如 feature-home 中出现 `import com.advancemediakb.feature.detail.*`）
- **禁止** feature 模块直接 import data 模块的实现类（必须通过 domain 接口）
- **禁止** core 层 import feature 层的任何类
- **禁止** domain 层 import data 层的任何类
- **禁止** 在 feature 层直接创建数据库实例或 DAO 实例
- **禁止** 在 UI 层（Composable 函数中）直接调用 Repository，必须通过 ViewModel

### 6.2 代码规范违反
- **禁止** 在任何文件中硬编码用户可见的文本字符串（必须使用资源文件）
- **禁止** 在代码中硬编码颜色值（必须使用 DesignSystem 中定义的常量）
- **禁止** 在代码中硬编码尺寸值（必须使用 DesignSystem 中定义的常量，仅 Compose 的 `Modifier` 布局参数除外）
- **禁止** 使用 `TODO("not implemented")` 或 `FIXME` 标记跳过功能实现
- **禁止** 空实现（空函数体、空类）——每个函数/类必须有完整实现或明确注释说明为何留空
- **禁止** 使用 `Thread.sleep()` 或阻塞主线程的操作
- **禁止** 在 ViewModel 中持有 Activity/Fragment/Context 引用

### 6.3 设计违反
- **禁止** 修改设计方案文档中定义的页面结构和布局
- **禁止** 添加设计方案中未定义的新功能、新页面、新设置项
- **禁止** 省略设计方案中定义的任何功能（即使认为不重要）
- **禁止** 修改默认设置值（如默认列数必须为 3，默认主题必须为"跟随系统"）
- **禁止** 修改缩略图尺寸（必须为 256×256）

### 6.4 依赖违反
- **禁止** 引入设计方案中未提及的第三方库（核心功能所需的标准库除外，如 Hilt、Room、Coroutines、Coil 等主流库可使用）
- **禁止** 引入自定义 View 或自定义 ViewGroup（优先使用 Compose 原生组件）
- **禁止** 使用已废弃的 API（如 `startActivityForResult`、`AsyncTask`）

---

## 7. 验证标准

完成本 skill 后，必须满足以下全部条件：

- [ ] 15 个模块目录全部存在（app + 6 core + domain + data + 7 feature 中的 5 个 feature，共 15 个。注意：feature-home 包含了主页面框架和相册/标签 Tab 的入口，feature-album/feature-tag 是独立的相册详情/标签详情模块）
- [ ] 每个模块目录下有 build.gradle.kts
- [ ] 每个模块目录下有 src/main/java/com/advancemediakb/ 子目录
- [ ] app 模块的 AndroidManifest.xml 声明了 MainActivity 和 MediaViewerActivity
- [ ] settings.gradle.kts 注册了所有模块
- [ ] 根 build.gradle.kts 声明了所有插件
- [ ] 版本目录 (libs.versions.toml) 包含全部依赖版本
- [ ] 项目可以成功编译（空模块也能通过构建）
