# Skill-03 设计系统

## 目标
定义 Material3 主题、颜色(强制深色)、字号、形状、间距,所有 UI 必须通过 `:core-designsystem` 的 `AdvanceMediaKBTheme` 包裹。

## 设计要点

| 项 | 设计 |
|---|------|
| 主题函数 | `AdvanceMediaKBTheme(themeMode: ThemeMode)` |
| 主题模式 | `SYSTEM` / `LIGHT` / `DARK`;App 启动时强制 `MODE_NIGHT_YES` |
| 主题来源 | Material3 `colorScheme` 自定义;不依赖 Material You 动态取色 |
| 颜色 | 深色为主,主色 / 辅色 / 背景 / 表面 / 错误,具体色值见 `:core-designsystem/Theme.kt` |
| 字体 | 系统默认 + 通过 `MaterialTheme.typography` 提供 5 级标题 + Body |
| 形状 | 圆角统一 12dp(CornerSize);按钮 / Card / Dialog 一致 |
| 间距 | 4 / 8 / 12 / 16 / 24 dp 网格 |
| 暗色策略 | 强制 `AppCompatDelegate.setDefaultNightMode(MODE_NIGHT_YES)`,避开白闪 |
| 启动屏 | `installSplashScreen()` + 自定义图标 |

### 通用 UI 元素(由 `:core-ui` 提供)

- `MediaThumbnail` — 缩略图(图/视频帧),统一 3:4 占位 + 圆角。
- `MultiSelectBottomBar` — 多选时的底部操作条。
- `EmptyState` — 空状态插画 + 提示文案。
- `LoadingIndicator` — 居中 `CircularProgressIndicator`。
- `SectionHeader` — 分区标题(粗体,左对齐,12dp 间距)。

## 代码检查点

- [ ] 所有 Composable **必须**包含在 `AdvanceMediaKBTheme { ... }` 内(Preview 也要)。
- [ ] 没有写死颜色 `Color(0xFF...)`,只能通过 `MaterialTheme.colorScheme.xxx` 访问。
- [ ] 字号不能写死 `16.sp`,必须用 `MaterialTheme.typography.xxx`。
- [ ] 圆角不能写死 `RoundedCornerShape(12.dp)`,应使用 `Shapes.medium` 等。
- [ ] `AppCompatDelegate.setDefaultNightMode` 在 `Application.onCreate` 调用,不是 Activity。
- [ ] 启动屏图标不依赖系统默认,使用 `:core-designsystem` 自定义。

## 验收标准

- 切换系统主题(Light/Dark),App 始终保持深色。
- 启动 App 看不到白闪。
- 任何新增 Screen 不需要单独声明颜色 / 字号 / 圆角,直接用 Theme。

## 已知问题

- 无强制夜间模式开关,用户不能切到浅色(产品决策)。

## 相关文件

- `core-designsystem/src/main/java/com/advancemediakb/designsystem/theme/Theme.kt`
- `core-designsystem/src/main/java/com/advancemediakb/designsystem/theme/Color.kt`
- `core-designsystem/src/main/java/com/advancemediakb/designsystem/theme/Typography.kt`
- `core-designsystem/src/main/java/com/advancemediakb/designsystem/theme/Shapes.kt`
- `core-ui/src/main/java/com/advancemediakb/ui/components/`
