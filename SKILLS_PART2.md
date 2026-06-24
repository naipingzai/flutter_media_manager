## 四、功能需求详细说明（续）

### 4.3 相册模块（Album）- 续

**相册操作**：
- 创建相册（FAB）：输入名称，可选在当前相册内创建
- 长按相册 → 删除确认对话框（显示相册名称）
- 点击相册 → 进入子相册或查看媒体
- 相册内媒体网格（与首页 AllMedia 一致，支持多选）
- 设置相册封面
- 面包屑点击任意一级可快速跳转
- 添加媒体到相册：弹出对话框显示所有未添加媒体，支持多选

**待选择方案**：
- [ ] 相册封面选择策略：第一张媒体 vs 用户指定 vs 最近添加
- [ ] 相册排序方式：创建时间 vs 名称 vs 自定义排序

---

### 4.4 标签模块（Tag）

**参考文件**：`feature-tag/TagScreen.kt`（729行）、`feature-tag/TagViewModel.kt`（291行）

**功能描述**：
- 层级结构：支持根标签和子标签（无限嵌套）
- 标签实体字段：id, name, color, parentId, createdAt
- 标签卡片展示：封面缩略图 + 渐变蒙层 + 标签名 + 媒体数量 + 子标签指示箭头
- 面包屑导航（与相册一致）
- 空状态提示

**参考代码关键片段**：

```kotlin
// Kotlin: TagEntity 数据类
@Entity(
    tableName = "tags",
    foreignKeys = [ForeignKey(
        entity = TagEntity::class,
        parentColumns = ["id"],
        childColumns = ["parent_id"],
        onDelete = ForeignKey.CASCADE
    )],
    indices = [Index(value = ["parent_id"])]
)
data class TagEntity(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val name: String,
    val color: String?,
    @ColumnInfo(name = "parent_id") val parentId: String?,
    @ColumnInfo(name = "created_at") val createdAt: Long = System.currentTimeMillis()
)

// Kotlin: TagWithInfo 展示用数据类
data class TagWithInfo(
    val tag: TagEntity,
    val mediaCount: Int,
    val coverThumbnailPath: String?,
    val hasChildren: Boolean
)

// Kotlin: TagViewModel 面包屑构建（防环保护）
suspend fun buildBreadcrumb(tagId: String): List<TagBreadcrumb> {
    val result = mutableListOf<TagBreadcrumb>()
    var currentId: String? = tagId
    var guard = 0
    while (currentId != null && guard < 64) {
        val tag = tagRepository.getById(currentId) ?: break
        result.add(0, TagBreadcrumb(tag.id, tag.name))
        currentId = tag.parentId
        guard++
    }
    return result
}

// Kotlin: 批量打标签（差集计算）
fun applyTagsToMedia(mediaIds: List<String>, selectedTagIds: Set<String>) {
    viewModelScope.launch {
        mediaIds.forEach { mediaId ->
            val currentTags = tagRepository.getTagIdsForMedia(mediaId).toSet()
            val toAdd = selectedTagIds - currentTags
            val toRemove = currentTags - selectedTagIds
            toAdd.forEach { tagRepository.addTagToMedia(mediaId, it) }
            toRemove.forEach { tagRepository.removeTagFromMedia(mediaId, it) }
        }
    }
}
```

**标签操作**：
- 创建标签（FAB）：仅输入名称，无颜色选择（参考项目已移除颜色功能）
- 长按标签 → 删除确认对话框
- 点击标签 → 进入子标签或查看媒体
- 标签内媒体网格（支持多选）
- 重命名标签
- 批量打标签：通过 TagSelectorDialog 选择标签，差集计算添加/移除

**标签选择器对话框（TagSelectorDialog）**：
- 两种模式：MULTI（多选打标签）/ FILTER（搜索筛选）
- 展示所有标签层级（树形或扁平列表）
- 支持搜索过滤
- 确认/取消按钮

**标签与媒体关联（AND/OR 筛选）**：
```kotlin
// Kotlin: TagRepository 多标签筛选
override fun observeMediaByTagsAnd(tagIds: List<String>): Flow<List<MediaItemEntity>> {
    if (tagIds.isEmpty()) return flowOf(emptyList())
    return combine(tagIds.map { tagId ->
        mediaTagDao.observeByTag(tagId).map { it.map { mt -> mt.mediaId }.toSet() }
    }) { sets ->
        sets.reduce { acc, set -> acc.intersect(set) }
    }.map { mediaIds -> mediaIds.mapNotNull { id -> mediaItemDao.getById(id) } }
}

override fun observeMediaByTagsOr(tagIds: List<String>): Flow<List<MediaItemEntity>> {
    if (tagIds.isEmpty()) return flowOf(emptyList())
    return combine(tagIds.map { tagId ->
        mediaTagDao.observeByTag(tagId).map { it.map { mt -> mt.mediaId } }
    }) { lists ->
        lists.flatMap { it }.distinct()
    }.map { mediaIds -> mediaIds.mapNotNull { id -> mediaItemDao.getById(id) } }
}
```

**待选择方案**：
- [ ] 标签颜色功能：保留（参考项目字段存在但 UI 已移除）vs 彻底移除
- [ ] 标签选择器展示方式：树形展开 vs 扁平列表 + 面包屑
- [ ] 多标签筛选模式：AND（交集）vs OR（并集）vs 用户切换

---

### 4.5 笔记模块（Note）

**参考文件**：`core-model/NoteEntity.kt`

**功能描述**：
- 笔记关联到单个媒体项（一对一）
- 笔记实体字段：id, mediaId, content, createdAt, updatedAt
- 在媒体查看器中查看/编辑笔记
- 笔记列表页（按时间排序）

**数据模型**：
```kotlin
// Kotlin: NoteEntity
@Entity(
    tableName = "notes",
    indices = [Index(value = ["media_id"])],
    foreignKeys = [ForeignKey(
        entity = MediaItemEntity::class,
        parentColumns = ["id"],
        childColumns = ["media_id"],
        onDelete = ForeignKey.CASCADE
    )]
)
data class NoteEntity(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    @ColumnInfo(name = "media_id") val mediaId: String,
    val content: String,
    @ColumnInfo(name = "created_at") val createdAt: Long = System.currentTimeMillis(),
    @ColumnInfo(name = "updated_at") val updatedAt: Long = System.currentTimeMillis()
)
```

**NoteDao 接口**：
- insert(note) → Long
- update(note)
- deleteById(id)
- getById(id) → NoteEntity?
- getByMediaId(mediaId) → NoteEntity?
- observeByMediaId(mediaId) → Flow<NoteEntity?>
- observeAll() → Flow<List<NoteEntity>>
- deleteByMediaId(mediaId)

**待选择方案**：
- [ ] 笔记功能范围：简单文本 vs 富文本 vs Markdown 支持
- [ ] 笔记入口位置：媒体查看器内 vs 独立页面

---

### 4.6 搜索模块（Search）

**参考文件**：`feature-search/SearchScreen.kt`（428行）、`feature-search/SearchViewModel.kt`

**功能描述**：
- 搜索输入框（OutlinedTextField，非 SearchBar）
- 实时搜索：文件名匹配 + 标签名匹配（SQL LIKE 查询）
- 搜索结果排序：文件名匹配优先，然后按创建时间倒序
- 搜索结果网格展示（与首页一致）
- 搜索历史记录（最近搜索列表，点击可快速搜索）
- 清空历史记录
- 标签筛选：通过 TagSelectorDialog 选择标签进行筛选
- 活动筛选 Chip 展示（可点击移除）

**参考代码关键片段**：

```kotlin
// Kotlin: SearchScreen.kt 搜索输入框
OutlinedTextField(
    value = query,
    onValueChange = { viewModel.setQuery(it) },
    placeholder = { Text("搜索文件名或标签...") },
    leadingIcon = { Icon(Icons.Default.Search, null) },
    trailingIcon = {
        if (query.isNotEmpty()) {
            IconButton(onClick = { viewModel.setQuery("") }) {
                Icon(Icons.Default.Clear, null)
            }
        }
    },
    singleLine = true
)

// Kotlin: SearchViewModel.kt 搜索逻辑（debounce + flatMapLatest）
val query = MutableStateFlow("")
val filterState = MutableStateFlow<FilterState>(FilterState.None)

val searchResults = combine(
    query.debounce(300),
    filterState.debounce(100)
) { q, filter -> q to filter }
    .flatMapLatest { (q, filter) ->
        if (q.isBlank() && filter is FilterState.None) {
            flowOf(emptyList())
        } else {
            mediaRepository.searchMedia(q, filter)
        }
    }
    .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

// Kotlin: 搜索 SQL（MediaItemDao.kt）
@Query("""
    SELECT * FROM media_items 
    WHERE original_name LIKE '%' || :query || '%'
       OR id IN (
           SELECT media_id FROM media_tags 
           WHERE tag_id IN (SELECT id FROM tags WHERE name LIKE '%' || :query || '%')
       )
    ORDER BY 
        CASE WHEN original_name LIKE '%' || :query || '%' THEN 0 ELSE 1 END,
        created_at DESC
""")
fun searchMedia(query: String): Flow<List<MediaItemEntity>>
```

**搜索界面**：
- 顶部 AppBar：返回按钮 + 标题 + 标签筛选按钮
- 搜索输入框：带搜索图标 + 清除按钮
- 空查询时显示搜索历史（最近搜索列表，点击可快速搜索，可清空）
- 有查询时显示结果数量 + 结果网格
- 无结果时显示空状态提示

**待选择方案**：
- [ ] 搜索算法：SQL LIKE vs 全文搜索（FTS5）vs 自定义索引
- [ ] 搜索结果排序策略：相关度 vs 时间 vs 混合

---

### 4.7 设置模块（Settings）

**参考文件**：`feature-settings/SettingsScreen.kt`（668行）、`feature-settings/SettingsViewModel.kt`（421行）

**功能描述**：
- 设置项分类展示（LazyColumn + SectionHeader）

**设置项分类**：

**导入设置**：
- 导入冲突策略：跳过 / 替换 / 保留两者（Dropdown）
- 导入后删除原文件（Switch）

**外观设置**：
- 主题模式：跟随系统 / 浅色 / 深色（Dropdown）
- 首页列数（Slider：2-6）
- 相册列数（Slider：2-6）
- 搜索列数（Slider：2-6）
- 标签列数（Slider：2-6）
- 缩略图质量（Slider：30%-100%）

**交互设置**：
- 预测性返回动画（Switch）
- 显示内容预览（Switch）：关闭后列表仅显示图标+文件名，不加载缩略图

**存储管理**：
- 存储统计：媒体数量、总大小、缩略图缓存大小
- 清理缩略图缓存（ActionButton）
- 查找未引用文件（ActionButton，显示数量和大小）

**数据管理**：
- 备份数据库（备份到下载目录）
- 恢复数据库（从备份恢复）
- 导出数据（导出媒体数据到 AMB 格式文件）
- 删除所有数据（DangerButton，带确认对话框）

**关于**：
- 版本号
- 开源许可（链接到 GitHub）
- 隐私政策（链接到 GitHub）
- 检查更新（链接到 GitHub Releases）

**参考代码关键片段**：

```kotlin
// Kotlin: SettingsViewModel.kt 独立 StateFlow 每个设置项
val importConflictStrategy: StateFlow<String> = settingsDataStore.importConflictStrategy
    .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), "skip")

val deleteOriginalAfterImport: StateFlow<Boolean> = settingsDataStore.deleteOriginalAfterImport
    .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), false)

val themeMode: StateFlow<String> = settingsDataStore.themeMode
    .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), "system")

val homeGridColumns: StateFlow<Int> = settingsDataStore.homeGridColumns
    .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), 3)

// Kotlin: 存储统计
data class StorageStats(
    val totalMediaCount: Int = 0,
    val totalSize: Long = 0,
    val thumbnailCacheSize: Long = 0,
    val unreferencedCount: Int = 0,
    val unreferencedSize: Long = 0
)

// Kotlin: 备份数据库
fun backupDatabase() {
    viewModelScope.launch {
        _isWorking.value = true
        try {
            val backupFile = withContext(Dispatchers.IO) {
                val dbFile = context.getDatabasePath("advance_media_kb.db")
                val targetDir = File(
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                    "advance_media_kb_backups"
                ).apply { if (!exists()) mkdirs() }
                val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
                val target = File(targetDir, "advance_media_kb_$timestamp.db")
                dbFile.inputStream().use { input ->
                    target.outputStream().use { output -> input.copyTo(output) }
                }
                target
            }
            _uiEvent.emit(UiEvent.Toast("已备份到 ${backupFile.absolutePath}"))
        } catch (e: Exception) {
            _uiEvent.emit(UiEvent.Error("备份失败：${e.message}"))
        } finally {
            _isWorking.value = false
        }
    }
}
```

**待选择方案**：
- [ ] 设置持久化方案：SharedPreferences vs Hive vs SQLite
- [ ] 设置数据同步：本地 only vs 云同步

---

### 4.8 导入模块（Import）

**参考文件**：`feature-home/FileBrowserDialog.kt`（443行）、`feature-home/FileBrowserViewModel.kt`（207行）

**功能描述**：
- 文件浏览器对话框（全屏覆盖，覆盖 BottomBar、TopBar）
- 需要存储权限（Android 11+ 需要 MANAGE_EXTERNAL_STORAGE）
- 支持多选文件
- 导入进度对话框（显示当前进度 / 总数）

**导入流程**：
1. 用户点击 FAB → 打开文件浏览器
2. 用户选择文件 → 调用 Rust 端 importMedia
3. Rust 端处理：
   - 计算 SHA-256 哈希
   - 检查重复（根据冲突策略：跳过/替换/保留两者）
   - 生成存储文件名（UUID）
   - 复制文件到应用私有目录
   - 生成缩略图
   - 提取 EXIF 信息
   - 插入数据库记录
4. 进度实时推送到 Flutter 端
5. 导入完成后关闭进度对话框

**文件浏览器**：
- 系统级文件选择器观感
- 显示目录列表和文件列表
- 支持进入子目录
- 返回键返回上一级
- 多选文件

**待选择方案**：
- [ ] 文件浏览器实现：系统文件选择器（file_picker）vs 自定义文件浏览器
- [ ] 导入并发策略：串行 vs 并行（限制并发数）
- [ ] 导入事务策略：单文件事务 vs 批量事务

---

### 4.9 数据库模块（Database）

**参考文件**：`core-database/AppDatabase.kt`、`core-database/dao/MediaItemDao.kt`（167行）

**数据库架构**：
SQLite 数据库，版本 1，包含以下表：

**media_items 表**：
- id (TEXT, PRIMARY KEY, UUID)
- original_name (TEXT)
- storage_name (TEXT)
- file_path (TEXT)
- thumbnail_path (TEXT)
- type (TEXT) — "image", "video", "audio"
- mime_type (TEXT)
- size (INTEGER)
- width (INTEGER, nullable)
- height (INTEGER, nullable)
- duration (INTEGER, nullable) — 视频/音频时长（毫秒）
- sha256_hash (TEXT)
- created_at (INTEGER)
- updated_at (INTEGER)
- 索引：created_at, type, sha256_hash

**albums 表**：
- id (TEXT, PRIMARY KEY, UUID)
- name (TEXT)
- parent_id (TEXT, nullable, FOREIGN KEY → albums.id, CASCADE)
- cover_media_id (TEXT, nullable)
- sort_order (INTEGER)
- created_at (INTEGER)
- 索引：parent_id

**album_media 表**（多对多关联）：
- id (TEXT, PRIMARY KEY, UUID)
- album_id (TEXT, FOREIGN KEY → albums.id)
- media_id (TEXT, FOREIGN KEY → media_items.id)
- created_at (INTEGER)

**tags 表**：
- id (TEXT, PRIMARY KEY, UUID)
- name (TEXT)
- color (TEXT, nullable)
- parent_id (TEXT, nullable, FOREIGN KEY → tags.id, CASCADE)
- created_at (INTEGER)
- 索引：parent_id

**media_tags 表**（多对多关联）：
- id (TEXT, PRIMARY KEY, UUID)
- media_id (TEXT, FOREIGN KEY → media_items.id)
- tag_id (TEXT, FOREIGN KEY → tags.id)
- created_at (INTEGER)

**notes 表**：
- id (TEXT, PRIMARY KEY, UUID)
- media_id (TEXT, FOREIGN KEY → media_items.id, CASCADE)
- content (TEXT)
- created_at (INTEGER)
- updated_at (INTEGER)
- 索引：media_id

**DAO 接口规范**：

MediaItemDao：
- insert(mediaItem) → Long
- insertAll(mediaItems) → List<Long>
- update(mediaItem)
- delete(mediaItem)
- getById(id) → MediaItemEntity?
- observeById(id) → Flow<MediaItemEntity?>
- observeAll() → Flow<List<MediaItemEntity>>
- getAll() → List<MediaItemEntity>
- getByHash(hash) → MediaItemEntity?
- observeByType(type) → Flow<List<MediaItemEntity>>
- deleteById(id)
- deleteAllByIds(ids)
- deleteAll()
- count() →
