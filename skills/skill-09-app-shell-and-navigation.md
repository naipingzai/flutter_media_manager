# Skill-09 应用壳与导航 (F0 + F1 入口)

## 目标
定义 App 启动后第一个可见的 UI 结构(主屏壳),包含三个主页、所有覆盖层、顶栏 / 底栏 / 多选底栏。

## 设计要点

| 项 | 设计 |
|---|------|
| 启动 Activity | `MainActivity` (LAUNCHER) |
| 唯一根 Composable | `HomeScreen()` |
| 三个主页 | `AllMediaPage` / `AlbumPage` / `TagPage` |
| 切换方式 | 顶栏 Tab 或底部导航;项目当前用 **顶部 Tab**(由设置决定) |
| 覆盖层 | `SearchOverlay` / `SettingsOverlay` / `ImportOverlay` / `AmbOverlay` |
| 全屏 Activity | `MediaViewerActivity`(独立),通过 Intent 启动 |
| 状态提升 | 主页模式 / 多选集 / 当前覆盖层全部提升到 `HomeScreen` 状态 |

### HomeScreen 内部状态机

```
data class HomeUiState(
  val currentTab: HomeTab,            // ALL_MEDIA / ALBUM / TAG
  val filterMode: HomeFilterMode,
  val multiSelect: MultiSelectState,
  val overlay: HomeOverlay? = null,   // null 表示无覆盖
  val selectedAlbumId: Long? = null,  // ALBUM Tab 下进入某相册
  val selectedTagId: Long? = null,    // TAG Tab 下进入某标签
)
```

### 启动流程(F0)

1. `Application.onCreate` 设置 `MODE_NIGHT_YES`。
2. `MainActivity.onCreate`:
   - `installSplashScreen()`
   - `enableEdgeToEdge()`
   - `setContent { AdvanceMediaKBTheme(themeMode) { HomeScreen() } }`
3. `HomeScreen` 内 `LaunchedEffect` 异步加载 `SettingsDataStore`(主题 / 语言)。
4. 触发 `permissionGate` 校验;未授权弹引导。

## 代码检查点

- [ ] `MainActivity` **不持有任何业务状态**,只委托给 `HomeScreen`。
- [ ] 没有引入 Navigation Compose;**不**使用 `NavHost` / `composable`。
- [ ] `HomeScreen` 接收 `HomeViewModel` 的 `StateFlow<HomeUiState>`,**不**用 `MutableState` 顶层。
- [ ] 顶栏 Tab 切换保持滚动位置(scrolling 状态在 ViewModel / `rememberSaveable`)。
- [ ] 覆盖层进入 / 退出有明确动画(`AnimatedVisibility` 或 `Crossfade`)。
- [ ] `MediaViewerActivity` 启动参数从 `HomeUiState.selectedMediaIds + index` 拿。

## 验收标准

- App 启动到主页可见 < 800ms(冷启动)。
- 切换 Tab / 进入覆盖层,数据不丢失。
- 进入 `MediaViewerActivity`,主页状态保留;返回后仍在原位置。

## 已知问题

- 项目早期有 Navigation Compose 残留,Review 时如发现 `androidx.navigation:*` 依赖应移除。
- `MainActivity` 偶尔会出现 `installSplashScreen` 报错(API 31 兼容),需要 `isAtLeastS` 保护。

## 相关文件

- `app/src/main/java/com/advancemediakb/MainActivity.kt`
- `app/src/main/java/com/advancemediakb/AdvanceMediaKBApplication.kt`
- `feature-home/src/main/java/com/advancemediakb/home/HomeScreen.kt`
- `feature-home/src/main/java/com/advancemediakb/home/HomeViewModel.kt`
- `feature-home/src/main/java/com/advancemediakb/home/HomeUiState.kt`
- `feature-home/src/main/java/com/advancemediakb/home/tab/`
