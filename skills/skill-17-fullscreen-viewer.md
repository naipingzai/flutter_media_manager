# Skill-17 全屏预览详细行为 (F5 补充)

## 目标
skill-13 的 Activity 层补充:Activity 生命周期、Intent 参数、退出动画、与主页的交互。

## 设计要点

| 项 | 设计 |
|---|------|
| Activity | `MediaViewerActivity : ComponentActivity` |
| 主题 | `@AndroidEntryPoint` + `AdvanceMediaKBTheme(themeMode)` |
| Intent 参数 | `EXTRA_MEDIA_IDS: LongArray`、`EXTRA_START_INDEX: Int`、`EXTRA_LIST_TITLE: String?` |
| 返回 | `onBackPressedDispatcher` + 顶栏返回按钮 |
| 退出动画 | 共享元素动画(`SharedTransitionLayout` 或 `Modifier.animateBoundsAsState`) |
| 进程模型 | 独立进程?否,与主进程同进程,共享 Room 实例 |

### Intent 传递

```kotlin
val intent = Intent(context, MediaViewerActivity::class.java).apply {
  putExtra("EXTRA_MEDIA_IDS", mediaIds.toLongArray())
  putExtra("EXTRA_START_INDEX", startIndex)
  putExtra("EXTRA_LIST_TITLE", listTitle)
}
context.startActivity(intent)
```

### 生命周期

| 阶段 | 行为 |
|------|------|
| onCreate | 读 Intent → `MediaViewerViewModel.init` → `setContent { ViewerScreen() }` |
| onStart | 请求 `WindowInsetsController` 显示状态栏 |
| onResume | 视频页 `player.play()`(若自动播放设置) |
| onPause | 视频页 `player.pause()`,保存当前播放位置到 ViewModel |
| onStop | 不释放 player(快速回到 App 仍能继续) |
| onDestroy | 释放 player,ViewModel.onCleared |

### 与主页的交互

- 进入 `MediaViewerActivity` 时,主页 `HomeScreen` **不**销毁,只是 onPause。
- `HomeUiState` 保留当前 Tab / 多选状态 / 筛选模式。
- 用户在 `MediaViewerActivity` 改了标签 / 删了媒体,返回主页后通过 Room Flow 自动刷新。

### 退出动画

- 共享元素:从主页缩略图 → 详情页大图,使用 `Modifier.sharedBounds` + `AnimatedContent`。
- 若实现复杂,可简化为「淡入淡出」过渡。

## 代码检查点

- [ ] `MediaViewerActivity` 在 `AndroidManifest.xml` 注册 `parentActivityName=".MainActivity"`。
- [ ] Intent 参数解析空安全(`getLongArrayExtra(EXTRA_MEDIA_IDS)` 为 null 时退出)。
- [ ] ViewModel 持有 player 引用,Activity 不能持有(配置变更存活)。
- [ ] 进程不分离(避免 Room 实例不同步)。
- [ ] `onNewIntent` 处理(单 Task 复用时,新 intent 替换旧内容)。

## 验收标准

- 从主页缩略图点击,详情页平滑出现。
- 按返回,详情页平滑消失,主页原位置。
- 在详情页删除媒体,返回主页,对应格子消失。
- 旋转屏幕不重建 Activity(`configChanges` 或依赖 ViewModel)。

## 已知问题

- 共享元素动画在 Compose 1.6 之前不稳定,可能闪烁。
- 单 Task 复用需自定义 `launchMode="singleTask"`,否则多次启动会重叠。

## 相关文件

- `app/src/main/java/com/advancemediakb/MediaViewerActivity.kt`
- `feature-detail/src/main/java/com/advancemediakb/detail/MediaViewerScreen.kt`
- `feature-detail/src/main/java/com/advancemediakb/detail/MediaViewerViewModel.kt`
- `app/src/main/AndroidManifest.xml`
