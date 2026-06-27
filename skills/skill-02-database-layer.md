# Skill-02 数据库层

## 目标

定义 Room Database、6 个 DAO 的查询契约、迁移策略、Flow 暴露规范,作为 Repository 的数据访问入口。

## 设计要点

| 项 | 设计 |
|---|------|
| Database | `AppDatabase` 抽象类,位于 `:core-database` 模块的 `com.advancemediakb.core.database` 包 |
| 数据库名 | `advance_media_kb.db` |
| Database 版本 | `version = 1`(目前单版本,后续需显式 `Migration`) |
| 迁移策略 | `.fallbackToDestructiveMigration()`(开发期) |
| DAO 数量 | **6 个**(每个 Entity 一个) |
| 返回类型 | 列表查询返回 `Flow<List<X>>`,单条返回 `Flow<X?>` 或 `suspend` |
| 写入操作 | `suspend fun` + `@Insert/@Update/@Delete` |
| 关系查询 | `@Query` + 多表 `JOIN` + `WITH RECURSIVE` CTE(用于树面包屑) |
| 去重查询 | `WHERE sha256_hash = :hash LIMIT 1` |
| 线程 | Room 主线程不允许写;`viewModelScope` / `repositoryScope` 调用 |

### DAO 关键查询约定(基于实际代码)

#### `MediaItemDao` (table: `media_items`)

- `insert / insertAll` — REPLACE 策略写入,返回 `List<Long>`(rowId,不是自增主键)
- `getById(id: String) / observeById(id: String): Flow<MediaItemEntity?>` — F1/F13 详情页
- `observeAll(): Flow<List<MediaItemEntity>>` — F0 主页全部
- `observeByType(type: String): Flow<List<MediaItemEntity>>` — 主页按 IMAGE/VIDEO 筛选
- `getByHash(hash: String): MediaItemEntity?` — F1 去重
- `searchMedia(query: String): Flow<List<MediaItemEntity>>` — F6 关键字搜索 (匹配 `original_name` 或关联 tag 名)
- `filterMedia(type?, startDate?, endDate?, albumId?, tagIds?, tagCount?): Flow<List<MediaItemEntity>>` — F0 多维过滤
- `observeWithAnyTag() / observeWithoutAnyTag()` — F0 「仅带标签 / 仅不含标签」快捷过滤
- `observeWithAnyAlbum() / observeWithoutAnyAlbum()` — F0 「仅带相册 / 仅不含相册」快捷过滤
- `observeByTag(tagId): Flow<List<MediaItemEntity>>` — 标签详情
- `getPreviousMedia / getNextMedia(mediaId)` — F13/F17 翻页(基于 `created_at` 排序)
- `count() / totalSize()` — F16 统计

#### `AlbumDao` (table: `albums`)

- `insert / update / delete / getById / observeById` — CRUD
- `observeRootAlbums() / observeChildren(parentId)` — F3 树展开
- `findRootByName(name)` — 重名检测
- `getMediaCount(albumId) / getChildCount(albumId)` — 计数徽标
- `getCoverThumbnailPath(coverMediaId)` — 封面图
- `observeAlbumMedia(albumId)` — F3 相册内媒体(JOIN `album_media`)
- `getAllDescendantIds(albumId)` — **递归 CTE**(`WITH RECURSIVE sub_albums`)用于跨级批量
- `getBreadcrumbPath(albumId)` — **递归 CTE** 用于面包屑导航
- `setCoverMedia(albumId, mediaId)` — 设置封面
- `getAlbumsByMediaId(mediaId)` — 反查媒体所属相册

#### `AlbumMediaDao` (table: `album_media`)

- `insert / insertAll` — 媒体入册(REPLACE)
- `observeByAlbum / observeByMedia` — 关系 Flow
- `getMediaIdsByAlbum(albumId): List<String>` — 反查
- `delete(albumId, mediaId) / deleteByAlbum(albumId) / deleteByMedia(mediaId)`
- `countByAlbum(albumId): Int`

#### `TagDao` (table: `tags`)

- CRUD + `observeAll() / getByName(name)`
- `getTagsForMedia(mediaId): Flow<List<TagEntity>>` — JOIN `media_tags`
- `deleteByMediaAndTag(mediaId, tagId)` — 删关联

#### `MediaTagDao` (table: `media_tags`)

- `insert / insertAll` — 打标签(REPLACE)
- `observeByMedia / observeByTag`
- `getTagIdsByMedia / getMediaIdsByTag` — 反查
- `delete / deleteByMedia / deleteByTag`
- `countByTag(tagId)`

#### `NoteDao` (table: `notes`)

- `insert / update / delete / getById / observeById`
- `getByMedia(mediaId) / observeByMedia(mediaId): Flow<NoteEntity?>` — **一对一**关系(每个媒体最多一条笔记)
- `observeAll(): Flow<List<NoteEntity>>` — F14 全部笔记列表
- `deleteByMedia(mediaId)` — 媒体删除时 CASCADE 兜底

### Hilt 注入

- `DatabaseModule`(`@InstallIn(SingletonComponent::class)`)提供:
  - `@Singleton AppDatabase`(通过 `Room.databaseBuilder`)
  - 6 个 DAO(`@Provides fun ... = database.xxxDao()`)

## 代码检查点

- [ ] 所有 DAO 列表查询返回 `Flow<List<X>>`,**不**返回 `List<X>`(失去响应式)。
- [ ] 所有 DAO 字符串 ID 参数使用 `String`(不是 `Long`),与 Entity UUID PK 对齐。
- [ ] `@Query` 中无 N+1:相同样查询应通过 JOIN 一次完成(参考 `observeAlbumMedia`、`getTagsForMedia`)。
- [ ] 删除节点时的级联:删除 `MediaItemEntity` 会 CASCADE 清理 `NoteEntity` / `AlbumMediaEntity` / `MediaTagEntity`(ForeignKey 保证)。
- [ ] Room 写入 suspend 函数没有调用 `runBlocking`。
- [ ] 没有 `allowMainThreadQueries()`。
- [ ] 数据库版本号 + 显式 `Migration` 必须同步修改;目前用 `fallbackToDestructiveMigration()` 仅适合开发期。
- [ ] 所有 DAO 都位于 `com.advancemediakb.core.database.dao` 包,AppDatabase 位于 `com.advancemediakb.core.database` 包。

## 验收标准

- 启动后查询主页响应延迟 < 200ms(冷启动不计)。
- 删除一个 `MediaItemEntity`,其所有 `NoteEntity` / `AlbumMediaEntity` / `MediaTagEntity` 自动消失(CASCADE 验证)。
- 删除一个顶级 `AlbumEntity`,其所有子相册和 `AlbumMediaEntity` 自动消失(CASCADE 验证)。
- 关闭再开 App,F1 导入产生的媒体立即出现在主页(因为 Room 直接返回 Flow)。
- `getAllDescendantIds(rootId)` 包含 root 自身 + 全部后代 ID。
- `getBreadcrumbPath(leafId)` 返回从根到叶的 ID/name 序列(按 level DESC)。

## 相关文件

- `core-database/src/main/java/com/advancemediakb/core/database/AppDatabase.kt`
- `core-database/src/main/java/com/advancemediakb/core/database/dao/MediaItemDao.kt`
- `core-database/src/main/java/com/advancemediakb/core/database/dao/AlbumDao.kt`
- `core-database/src/main/java/com/advancemediakb/core/database/dao/AlbumMediaDao.kt`
- `core-database/src/main/java/com/advancemediakb/core/database/dao/TagDao.kt`
- `core-database/src/main/java/com/advancemediakb/core/database/dao/MediaTagDao.kt`
- `core-database/src/main/java/com/advancemediakb/core/database/dao/NoteDao.kt`
- `core-database/src/main/java/com/advancemediakb/core/database/di/DatabaseModule.kt`
