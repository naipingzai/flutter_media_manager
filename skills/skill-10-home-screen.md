# Skill-10 所有媒体主页 (F2)

## 目标
实现三个主页中的第一个:**所有媒体**,展示所有已导入媒体,支持 5 种 `HomeFilterMode` 筛选、多选、点击进入全屏详情。

## 设计要点

| 项 | 设计 |
|---|------|
| 位置 | `feature-home/.../home/tab/AllMediaPage.kt` |
| 数据源 | `MediaDao.observeAll(filterMode)` 返回 `Flow<List<MediaEntity>>` |
| 布局 | `LazyVerticalGrid(columns = gridColumns)` |
| 列数 | 由 `SettingsDataStore.gridColumns` 决定(2 / 3 / 4) |
| 排序 | 按 `dateTakenSec DESC`(最新的在上) |
| 筛选模式 | `ALL / WITH_TAGS / WITHOUT_TAGS / WITH_ALBUMS / WITHOUT_ALBUMS` |
| 多选 | 长按进入,顶栏出现 `MultiSelectTopBar`,底栏出现 `MultiSelectBottomBar` |
| 点击 | 普通点击 → 跳 `MediaViewerActivity`(传 `mediaIds + startIndex`) |
| 缩略图 | `MediaThumbnail(mediaId)` 由 `:core-ui` 提供 |

### `HomeFilterMode` 详解

| 模式 | SQL 等价 |
|------|---------|
| `ALL` | 无过滤 |
| `WITH_TAGS` | `mediaId IN (SELECT mediaId FROM MediaTagCrossRef)` |
| `WITHOUT_TAGS` | `mediaId NOT IN (SELECT mediaId FROM MediaTagCrossRef)` |
| `WITH_ALBUMS` | `albumId IS NOT NULL` |
| `WITHOUT_ALBUMS` | `albumId IS NULL` |

### 顶栏

- 左侧:App 名 / 当前筛选模式标题。
- 中部:三个 Tab(所有媒体 / 相册 / 标签)。
- 右侧:搜索图标 / 设置图标 / 多选图标。

### 空状态

- 0 个媒体:显示「还没有任何媒体,从导入开始」+ 「导入」按钮。
- 筛选后 0 个:显示「当前筛选下没有媒体」+ 「清除筛选」按钮。

## 代码检查点

- [ ] `observeAll(filterMode)` 接收枚举,**不**接收拼接 SQL 字符串。
- [ ] 多选状态在 `HomeUiState.multiSelect` 里,不在 `AllMediaPage` 内部 `remember`。
- [ ] 点击普通格子跳转 `MediaViewerActivity` 用 `rememberLauncherForActivityResult` / `startActivity`。
- [ ] 网格列数从 DataStore 读,**不**写死。
- [ ] 缩略图组件用 `MediaThumbnail`,**不**直接 `Image(painter = ...)`。
- [ ] 滑动到底自动加载更多(项目当前无分页,所有媒体一次性展示)。

## 验收标准

- 5 种筛选模式切换后,UI 立即更新。
- 长按进入多选,所有页面(所有媒体 / 相册 / 标签)的格子都能选中。
- 1 万个媒体首屏滚动 60fps。

## 已知问题

- 1 万+ 媒体无分页,首次加载稍慢(可加 `LazyGridState.prefetch`)。
- 视频缩略图若未生成,会显示占位黑屏。

## 相关文件

- `feature-home/src/main/java/com/advancemediakb/home/tab/AllMediaPage.kt`
- `feature-home/src/main/java/com/advancemediakb/home/tab/AllMediaViewModel.kt`
- `core-database/src/main/java/com/advancemediakb/db/MediaDao.kt`
- `core-model/src/main/java/com/advancemediakb/model/HomeFilterMode.kt`
