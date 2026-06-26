# Skill-03: 设计系统完整规范

## 前置依赖
skill-00

## 目标
定义完整的视觉设计规范，包括颜色、字体、间距、动画，确保整个应用视觉一致。

---

## 1. 颜色系统

### 1.1 浅色主题色板

| 角色名称 | 色值 | 用途 |
|---------|------|------|
| Primary | #2196F3 | 主色调：选中边框、图标高亮、FAB、按钮 |
| OnPrimary | #FFFFFF | 主色上的文字/图标 |
| PrimaryContainer | #BBDEFB | 多选底栏背景、Chip 选中背景 |
| OnPrimaryContainer | #0D47A1 | 多选底栏文字/图标 |
| Secondary | #03DAC5 | 次要操作色 |
| OnSecondary | #000000 | 次要色上的文字 |
| Surface | #FFFFFF | 页面背景、卡片背景 |
| SurfaceVariant | #E3F2FD | 缩略图占位背景、Chip 未选中背景 |
| OnSurface | #212121 | 正文文字 |
| OnSurfaceVariant | #757575 | 次要文字、辅助信息 |
| Error | #B00020 | 删除按钮、错误提示 |
| OnError | #FFFFFF | 错误色上的文字 |
| Outline | #BDBDBD | 分割线、边框 |
| Scrim | #52000000 | 对话框背景遮罩（黑色 32% 透明度） |

### 1.2 深色主题色板

| 角色名称 | 色值 | 用途 |
|---------|------|------|
| Primary | #90CAF9 | 主色调 |
| OnPrimary | #003258 | 主色上的文字/图标 |
| PrimaryContainer | #1565C0 | 多选底栏背景 |
| OnPrimaryContainer | #E3F2FD | 多选底栏文字/图标 |
| Secondary | #03DAC5 | 次要操作色 |
| OnSecondary | #000000 | 次要色上的文字 |
| Surface | #121212 | 页面背景 |
| SurfaceVariant | #1E1E1E | 缩略图占位背景 |
| OnSurface | #E0E0E0 | 正文文字 |
| OnSurfaceVariant | #9E9E9E | 次要文字 |
| Error | #CF6679 | 删除按钮、错误提示 |
| OnError | #000000 | 错误色上的文字 |
| Outline | #424242 | 分割线、边框 |
| Scrim | #52000000 | 对话框背景遮罩 |

### 1.3 动态颜色（Android 12+）

- 如果设备支持 Material You（Android 12+），可选择使用系统动态取色
- 动态颜色仅影响 Primary/Secondary 色系，不影响 Surface/OnSurface 等基础色
- 用户可在设置中选择是否启用动态颜色

---

## 2. 字体排版系统

### 2.1 字体层级定义

| 层级 | 字号 | 字重 | 行高 | 用途 |
|------|------|------|------|------|
| Display Large | 57sp | Normal | 64sp | 不使用 |
| Display Medium | 45sp | Normal | 52sp | 不使用 |
| Display Small | 36sp | Normal | 44sp | 不使用 |
| Headline Large | 32sp | Normal | 40sp | 不使用 |
| Headline Medium | 28sp | Normal | 36sp | 不使用 |
| Headline Small | 24sp | Normal | 32sp | 不使用 |
| Title Large | 22sp | Normal | 28sp | 页面标题（TopAppBar） |
| Title Medium | 16sp | Medium | 24sp | 选中计数文本、卡片标题 |
| Title Small | 14sp | Medium | 20sp | 对话框标题、面板标题 |
| Body Large | 16sp | Normal | 24sp | 空状态提示、大段正文 |
| Body Medium | 14sp | Normal | 20sp | 笔记内容预览、列表项正文 |
| Body Small | 12sp | Normal | 16sp | 缩略图文件名、标签名、辅助信息 |
| Label Large | 14sp | Medium | 20sp | 按钮文字 |
| Label Medium | 12sp | Medium | 16sp | FilterChip 文字、Badge |
| Label Small | 11sp | Medium | 16sp | 文件大小、时间戳 |

### 2.2 字体家族

- 默认使用系统字体（sans-serif）
- 不引入自定义字体文件
- 所有文字默认允许自动换行

---

## 3. 间距与尺寸系统

### 3.1 间距常量

| 名称 | 值 | 用途 |
|------|---|------|
| SpacingXxs | 2dp | 网格项间距、缩略图内边距 |
| SpacingXs | 4dp | 图标与文字间距、紧凑元素间距 |
| SpacingSm | 8dp | 组件内部间距、Chip 间距 |
| SpacingMd | 12dp | 列表项间距、卡片内边距 |
| SpacingLg | 16dp | 页面水平边距、组件间距 |
| SpacingXl | 24dp | 大块内容间距、子标签缩进 |
| SpacingXxl | 32dp | 章节间距 |

### 3.2 尺寸常量

| 名称 | 值 | 用途 |
|------|---|------|
| IconSizeSmall | 14dp | 视频播放图标 |
| IconSizeMedium | 24dp | 导航栏图标、操作按钮图标 |
| IconSizeLarge | 36dp | 非预览模式占位图标 |
| IconSizeXLarge | 48dp | 相册封面占位图标 |
| IconSizeXxl | 64dp | 空状态图标 |
| TouchTargetMin | 48dp × 48dp | 最小触控区域（Material Design 规范） |
| ThumbnailSize | 256px × 256px | 缩略图生成尺寸 |
| CornerRadiusSm | 4dp | 缩略图圆角、小卡片圆角 |
| CornerRadiusMd | 8dp | 卡片圆角、按钮圆角 |
| CornerRadiusLg | 12dp | 相册卡片圆角 |
| CornerRadiusXl | 28dp | 对话框圆角（Material3 默认） |
| CornerRadiusFull | 50% | 胶囊形（搜索栏） |
| BottomBarHeight | 56dp | 多选底栏高度 |
| TopBarHeight | 64dp | TopAppBar 高度（Material3 默认） |
| BottomNavHeight | 80dp | 底部导航栏高度（Material3 默认） |
| FabSize | 56dp × 56dp | FAB 尺寸 |
| CheckCircleSize | 24dp | 选中勾选图标尺寸 |
| BorderWidthSelected | 3dp | 选中态边框宽度 |
| OverlayOpacity | 0.3f | 选中态覆盖层透明度（30%） |

---

## 4. 动画系统

### 4.1 动画常量

| 名称 | 时长 | 缓动曲线 | 用途 |
|------|------|---------|------|
| TabSwitchFadeIn | 250ms | EaseInOut | Tab 切换淡入 |
| TabSwitchFadeOut | 200ms | EaseInOut | Tab 切换淡出 |
| FilterSwitchFadeIn | 220ms | EaseInOut | 过滤器切换淡入 |
| FilterSwitchFadeOut | 180ms | EaseInOut | 过滤器切换淡出 |
| OverlaySlideIn | 280ms | EaseOut | 覆盖层滑入（从右，位移 1/4 屏幕宽度） |
| OverlaySlideOut | 220ms | EaseIn | 覆盖层滑出（向左，位移 1/4 屏幕宽度） |
| OverlayFadeIn | 220ms | EaseOut | 覆盖层内容淡入 |
| OverlayFadeOut | 180ms | EaseIn | 覆盖层内容淡出 |
| FabShow | 220ms | EaseOut | FAB 出现（缩放 0→1 + 淡入） |
| FabHide | 180ms | EaseIn | FAB 消失（缩放 1→0 + 淡出） |
| BottomBarShow | 200ms | EaseOut | 多选底栏出现（淡入） |
| BottomBarHide | 150ms | EaseIn | 多选底栏消失（淡出） |
| ThumbnailCrossfade | 200ms | Linear | 缩略图交叉淡入 |
| ThumbnailScaleIn | 150ms | EaseOut | 缩略图选中缩放反馈 |

### 4.2 手势动画

| 手势 | 动画行为 |
|------|---------|
| Tab 切换 | 当前内容淡出 → 新内容淡入 |
| 过滤器切换 | 当前网格淡出 → 新网格淡入 |
| 覆盖层进入 | 整体从右侧滑入（1/4 屏幕宽度位移）+ 内容淡入 |
| 覆盖层退出 | 整体向左侧滑出 + 内容淡出 |
| FAB 出现/消失 | 缩放 + 淡入淡出 |
| 多选底栏出现/消失 | 淡入淡出 |
| 缩略图加载完成 | 交叉淡入（从占位色到实际图片） |

---

## 5. 通用组件样式规范

### 5.1 FilterChip 样式

| 状态 | 背景色 | 文字色 | 边框 |
|------|--------|--------|------|
| 未选中 | SurfaceVariant | OnSurface | 无 |
| 选中 | Primary | OnPrimary | 无 |

### 5.2 按钮样式

| 类型 | 背景色 | 文字色 | 圆角 | 用途 |
|------|--------|--------|------|------|
| FilledButton | Primary | OnPrimary | 8dp | 主操作（导入、保存） |
| TextButton | 透明 | Primary | 8dp | 次要操作（取消） |
| IconButton | 透明 | OnSurface | — | 操作栏按钮 |

### 5.3 对话框样式

| 项目 | 规范 |
|------|------|
| 圆角 | 28dp |
| 宽度 | 屏幕宽度 - 48dp（两侧各 24dp 边距） |
| 最大高度 | 屏幕高度的 80% |
| 背景遮罩 | 黑色 32% 透明度 |
| 内边距 | 24dp |

---

## 6. 全屏查看器专用样式

| 项目 | 规范 |
|------|------|
| 背景色 | 纯黑 #000000 |
| 操作栏背景 | 顶部渐变黑色遮罩（60% → 0%） |
| 指示器文字色 | 白色，带文字阴影 |
| 图标色 | 白色 |
| 指示器字号 | BodyMedium（14sp） |

---

## 7. 验证标准

完成本 skill 后，必须满足以下全部条件：

- [ ] 浅色主题色板全部定义（14 个角色色）
- [ ] 深色主题色板全部定义（14 个角色色）
- [ ] 字体排版系统全部定义（15 个层级）
- [ ] 间距常量全部定义（7 个级别）
- [ ] 尺寸常量全部定义（20 个常量）
- [ ] 动画常量全部定义（14 个动画）
- [ ] 通用组件样式全部定义
- [ ] 主题可在浅色/深色之间切换
- [ ] 所有颜色值在浅色和深色主题下均有良好对比度（WCAG AA 标准）
- [ ] 设计系统模块不依赖任何其他模块
