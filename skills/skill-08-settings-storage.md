# Skill-08: 设置存储规范

## 前置依赖
skill-00

## 目标
定义全部设置项、持久化方式、默认值、变更通知机制。

---

## 1. 设置项清单

共 6 个设置项，全部必须实现：

| # | 设置项 | 类型 | 默认值 | 可选值 | 说明 |
|---|--------|------|--------|--------|------|
| 1 | themeMode | Enum | SYSTEM | SYSTEM, LIGHT, DARK | 主题模式 |
| 2 | dynamicColor | Boolean | false | true, false | 是否启用 Material You 动态颜色 |
| 3 | language | Enum | SYSTEM | SYSTEM, ZH, EN | 语言偏好 |
| 4 | gridColumns | Int | 3 | 2, 3, 4, 5 | 媒体网格列数 |
| 5 | showContentPreview | Boolean | true | true, false | 是否显示内容预览 |
| 6 | lastScanPath | String? | null | 任意路径 | 上次扫描的目录路径（记忆功能） |

---

## 2. ThemeMode 枚举

| 值 | 说明 | 系统行为 |
|----|------|---------|
| SYSTEM | 跟随系统 | 读取系统深色模式设置 |
| LIGHT | 始终浅色 | 强制浅色主题 |
| DARK | 始终深色 | 强制深色主题 |

---

## 3. Language 枚举

| 值 | 说明 | 系统行为 |
|----|------|---------|
| SYSTEM | 跟随系统 | 使用系统语言设置 |
| ZH | 中文 | 强制中文（简体） |
| EN | English | 强制英文 |

---

## 4. 持久化方式

| 规则 | 说明 |
|------|------|
| 存储方式 | 键值对持久化（类似 SharedPreferences / DataStore） |
| 存储位置 | 应用私有目录 |
| 线程安全 | 读写操作必须线程安全 |
| 初始化 | 应用启动时从持久化存储加载全部设置到内存 |
| 写入时机 | 设置变更时立即持久化 |

---

## 5. 默认值规则

| 设置项 | 首次安装默认值 | 说明 |
|--------|--------------|------|
| themeMode | SYSTEM | 跟随系统主题 |
| dynamicColor | false | 默认不启用动态颜色 |
| language | SYSTEM | 跟随系统语言 |
| gridColumns | 3 | 3 列网格 |
| showContentPreview | true | 默认显示预览 |
| lastScanPath | null | 无记忆路径 |

---

## 6. 设置变更通知

设置变更时必须通知所有观察者：

| 机制 | 说明 |
|------|------|
| 观察模式 | 响应式数据流（Flow/StateFlow） |
| 通知时机 | 值变更后立即通知 |
| 通知范围 | 所有正在观察该设置项的组件 |
| 初始值 | 订阅时立即发出当前值 |

**各设置项的生效范围**：

| 设置项 | 即时生效范围 | 需要重建的组件 |
|--------|------------|--------------|
| themeMode | 全局主题切换 | 无（Compose 自动重组） |
| dynamicColor | 全局颜色切换 | 无（Compose 自动重组） |
| language | 需要重建 Activity | 当前 Activity |
| gridColumns | 媒体网格重新布局 | 无（Compose 自动重组） |
| showContentPreview | 网格项切换预览/非预览 | 无（Compose 自动重组） |
| lastScanPath | 文件浏览器初始路径 | 无 |

---

## 7. 设置存储接口

设置存储器需要提供以下能力：

| 能力 | 方法签名模式 | 说明 |
|------|------------|------|
| 读取单个设置 | getXxx(): Type | 同步读取当前值 |
| 观察单个设置 | observeXxx(): Flow<Type> | 响应式观察变化 |
| 写入单个设置 | setXxx(value: Type) | 同步写入 |
| 读取全部设置 | getAll(): SettingsData | 一次性读取所有设置 |

---

## 8. 验证标准

完成本 skill 后，必须满足以下全部条件：

- [ ] 6 个设置项全部定义和实现
- [ ] 每个设置项有正确的默认值
- [ ] 设置变更后持久化正确
- [ ] 应用重启后设置正确恢复
- [ ] 每个设置项支持响应式观察
- [ ] 设置变更能正确通知 UI 层
- [ ] 线程安全
- [ ] 设置存储通过 DI 正确提供
