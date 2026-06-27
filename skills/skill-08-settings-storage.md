# Skill-08 设置存储

## 目标

用 DataStore Preferences 持久化用户设置;所有写操作走 `SettingsDataStore`,UI 通过 Flow 订阅。

## 设计要点

### 实际代码的 11 个设置项

| Key (PreferencesKey) | 类型 | 默认值 | 含义 | Flow 暴露 | setter |
|----------------------|------|--------|------|-----------|--------|
| `default_import_tags` | StringSet | `setOf("默认")` | 导入时自动打的标签 | `defaultImportTags: Flow<Set<String>>` | `setDefaultImportTags(Set<String>)` |
| `import_conflict_strategy` | String | `"skip"` | 导入冲突策略 | `importConflictStrategy: Flow<String>` | `setImportConflictStrategy(String)` |
| `delete_original_after_import` | Boolean | `false` | 导入后删除原文件 | `deleteOriginalAfterImport: Flow<Boolean>` | `setDeleteOriginalAfterImport(Boolean)` |
| `theme_mode` | String | `"system"` | 主题模式(system/light/dark) | `themeMode: Flow<String>` | `setThemeMode(String)` |
| `thumbnail_quality` | Int | `80` | 缩略图 JPEG 质量 | `thumbnailQuality: Flow<Int>` | `setThumbnailQuality(Int)` |
| `home_grid_columns` | Int | `DEFAULT_GRID_COLUMNS(3)` | 主页网格列数 | `homeGridColumns: Flow<Int>` | `setHomeGridColumns(Int)` |
| `album_grid_columns` | Int | `3` | 相册 Tab 网格列数 | `albumGridColumns: Flow<Int>` | `setAlbumGridColumns(Int)` |
| `search_grid_columns` | Int | `3` | 搜索 Tab 网格列数 | `searchGridColumns: Flow<Int>` | `setSearchGridColumns(Int)` |
| `tag_grid_columns` | Int | `3` | 标签 Tab 网格列数 | `tagGridColumns: Flow<Int>` | `setTagGridColumns(Int)` |
| `predictive_back_enabled` | Boolean | `true` | 是否启用预测式返回手势 | `predictiveBackEnabled: Flow<Boolean>` | `setPredictiveBackEnabled(Boolean)` |
| `show_content_previews` | Boolean | `true` | Album/Tag Tab 是否展示内容预览 | `showContentPreviews: Flow<Boolean>` | `setShowContentPreviews(Boolean)` |

> **注意**:v4 之前 skill-08 列了 10 项(`import_concurrency`、`default_home_filter`、`show_video_in_home`、`language_override`、`viewer_auto_play`、`backup_reminder`、`import_root_paths`、`last_seen_changelog`),但**实际代码中不存在这些 key**。实际代码只有上述 11 项。

### 包路径修正

- 实际包名:`com.advancemediakb.core.common.settings`(非 `com.advancemediakb.common.settings`)
- DataStore name: `"settings"`
- 注入:`@Singleton class SettingsDataStore @Inject constructor(@ApplicationContext context: Context)`

### API 形态

```kotlin
@Singleton
class SettingsDataStore @Inject constructor(
    @ApplicationContext private val context: Context
) {
    val themeMode: Flow<String> = context.dataStore.data
        .map { it[THEME_MODE] ?: "system" }

    suspend fun setThemeMode(mode: String) {
        context.dataStore.edit { it[THEME_MODE] = mode }
    }
    // ... 其余 10 项同模式
}
```

### 未实现的设置项(v4 设想 vs 实际)

| 设想 key | 状态 | 说明 |
|----------|------|------|
| `import_concurrency` | ❌ 不存在 | 导入并发数未持久化 |
| `default_home_filter` | ❌ 不存在 | 主页默认筛选未持久化 |
| `show_video_in_home` | ❌ 不存在 | 主页视频可见性未持久化 |
| `language_override` | ❌ 不存在 | 语言切换未走 DataStore |
| `viewer_auto_play` | ❌ 不存在 | 视频自动播放未持久化 |
| `backup_reminder` | ❌ 不存在 | 备份提醒未持久化 |
| `import_root_paths` | ❌ 不存在 | SAF 树 URI 未持久化 |
| `last_seen_changelog` | ❌ 不存在 | Changelog 版本未持久化 |
| `ThemeMode.kt` / `HomeFilterMode.kt` | ❌ 不存在 | 无枚举类,直接用 String |

## 代码检查点

- [x] 所有设置**没有**使用 SharedPreferences,只走 DataStore Preferences(`preferencesDataStore(name = "settings")`)。
- [x] DataStore 写入 `suspend fun`,**不**阻塞主线程。
- [ ] 每个 `Flow<X>` 是否有 `distinctUntilChanged` — **实际代码未加**,建议补上。
- [x] 没有把整个 DataStore 暴露成单例可变 Map,只暴露具体字段的 Flow + suspend setter。
- [x] `@Singleton` + `@Inject` 构造器注入,符合 Hilt 规范。
- [x] 包路径 `com.advancemediakb.core.common.settings`。
- [ ] `themeMode` 用 String 而非枚举 — 建议未来引入 `ThemeMode` 枚举类。
- [ ] 4 个独立的 grid columns(Home/Album/Search/Tag)— v4 设想只有 1 个 `grid_columns`。

## 验收标准

- 修改设置后,杀进程重启仍生效。
- 多个 Composable 订阅同一个设置,一处修改,其他处立刻收到新值。
- DataStore 损坏时不崩溃,有默认值兜底(`?: 默认值`)。
- `DEFAULT_GRID_COLUMNS = 3` 常量定义在 companion object。

## 已知问题

- DataStore 第一次读是异步的,UI 需要在 `Loading` 状态等待。
- `themeMode` 等 String 值直接持久化,无类型安全(建议未来引入枚举)。
- 实际代码的 Flow 未加 `distinctUntilChanged`,可能产生多余重组。
- 8 项 v4 设想的设置未实现(language/backup/viewer 等)。

## 相关文件

- `core-common/src/main/java/com/advancemediakb/core/common/settings/SettingsDataStore.kt` (125 行)
