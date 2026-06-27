# Skill-01 数据模型

## 目标

定义 6 个 Room Entity 的字段、主键、关系(自引用树、外键),作为后续 DAO 和 Repository 的数据契约。

## 设计要点

| Entity | 包 | 主键 | 关键字段 | 关系 |
|--------|----|----|---------|-----|
| `MediaItemEntity` | `:core-model` | `id: String` UUID | `originalName, storageName, filePath, thumbnailPath, type, mimeType, size, width?, height?, duration?, sha256Hash, createdAt, updatedAt` | 多对多 → `AlbumEntity` / `TagEntity` |
| `AlbumEntity` | `:core-model` | `id: String` UUID | `name, parentId?, coverMediaId?, sortOrder, createdAt` | 自引用树 `parentId → id` |
| `TagEntity` | `:core-model` | `id: String` UUID | `name, color?, parentId?, createdAt` | 自引用树 `parentId → id` |
| `AlbumMediaEntity` | `:core-model` | 联合 `(albumId, mediaId)` | `addedAt` | 连接表 (多对多 媒体↔相册) |
| `MediaTagEntity` | `:core-model` | 联合 `(mediaId, tagId)` | `addedAt` | 连接表 (多对多 媒体↔标签) |
| `NoteEntity` | `:core-model` | `id: String` UUID | `mediaId, content, createdAt, updatedAt` | 多对一 → `MediaItemEntity` |

> 详细字段定义见主设计文档「第二部分 数据模型」。

### 关键约束

- **主键**:`@PrimaryKey val id: String = java.util.UUID.randomUUID().toString()`,默认 UUID 自动生成。
- **外键策略**:**全部** 使用 `ForeignKey.CASCADE`(删除父记录 → 子记录一并删除)。
  - `AlbumEntity.parentId` → `albums.id` (CASCADE)
  - `TagEntity.parentId` → `tags.id` (CASCADE)
  - `AlbumMediaEntity.albumId` → `albums.id` (CASCADE)
  - `AlbumMediaEntity.mediaId` → `media_items.id` (CASCADE)
  - `MediaTagEntity.mediaId` → `media_items.id` (CASCADE)
  - `MediaTagEntity.tagId` → `tags.id` (CASCADE)
  - `NoteEntity.mediaId` → `media_items.id` (CASCADE)
- **索引**:`created_at`、`type`、`sha256_hash`、`parent_id`、`media_id`、`tag_id` 等高频查询字段均有 `@Index`。

### 树结构约束

- `AlbumEntity.parentId` 和 `TagEntity.parentId` 允许 `null`(顶级节点)。
- 自引用通过外键 + `ForeignKey.CASCADE` 实现(删除父节点 → **所有子树一起删除**,**不**升级为顶级)。
- **不限制深度**(无限级树),UI 通过折叠展开递归渲染。
- 排序字段 `AlbumEntity.sortOrder` 为用户手动排序,默认按 `createdAt ASC`。

### 媒体-标签 / 媒体-相册

- **媒体 ↔ 标签**:`MediaTagEntity` 连接表,支持多对多。
- **媒体 ↔ 相册**:`AlbumMediaEntity` 连接表,支持多对多(**不是** FK 列)。
- 同名标签/相册在不同父节点下**允许重名**(因为是树)。

### 媒体文件存储 (F1 写入)

- `MediaItemEntity.filePath`:**入库后的相对路径** (例如 `media/2025/06/abc.mp4`),不含根目录。
- `MediaItemEntity.storageName`:**入库后的磁盘文件名**(通常 = UUID + 扩展名,用于去重检测)。
- `MediaItemEntity.thumbnailPath`:**缩略图相对路径** (例如 `thumbnails/abc.jpg`)。
- `MediaItemEntity.sha256Hash`:**文件内容哈希**,用于跨设备/跨路径去重。

## 代码检查点

- [ ] 6 个 Entity 类均位于 `com.advancemediakb.core.model` 包下,且表名/字段名与主设计文档一致。
- [ ] 所有 `@PrimaryKey` 都是 `String` UUID(默认 `UUID.randomUUID().toString()`)。
- [ ] **所有** 自引用外键都是 `ForeignKey.CASCADE`(包括 Album/Tag 的 parent_id 自引用)。
- [ ] `AlbumMediaEntity` 必须有 `@Entity(primaryKeys = ["album_id", "media_id"])`。
- [ ] `MediaTagEntity` 必须有 `@Entity(primaryKeys = ["media_id", "tag_id"])`。
- [ ] `MediaItemEntity` 必含 `sha256_hash` 字段且有 `@Index`(用于 F1 去重)。
- [ ] `MediaItemEntity.thumbnail_path` 必含(本地缩略图缓存路径,F1 写入)。
- [ ] `TagEntity.color` 字段名是 `color`(不是 `colorHex`),类型 `String?`(可空)。
- [ ] 任何新增 Entity 都应在主设计文档「第二部分」追加表格行,不能静默加表。

## 验收标准

- 通过 `./gradlew :core-model:compileDebugKotlin` 不报缺少字段警告。
- 删除某个顶级 `AlbumEntity`,其所有子孙节点和对应的 `AlbumMediaEntity` 记录必须**一并删除**。
- 删除某个 `MediaItemEntity`,其所有 `NoteEntity` / `AlbumMediaEntity` / `MediaTagEntity` 关联记录必须**一并删除**。
- 同名媒体(不同 `originalName` 同一 `sha256Hash`)由 `sha256_hash` 去重查询(`MediaItemDao.getByHash`)。

## 相关文件

- `core-model/src/main/java/com/advancemediakb/core/model/MediaItemEntity.kt`
- `core-model/src/main/java/com/advancemediakb/core/model/AlbumEntity.kt`
- `core-model/src/main/java/com/advancemediakb/core/model/TagEntity.kt`
- `core-model/src/main/java/com/advancemediakb/core/model/AlbumMediaEntity.kt`
- `core-model/src/main/java/com/advancemediakb/core/model/MediaTagEntity.kt`
- `core-model/src/main/java/com/advancemediakb/core/model/NoteEntity.kt`
