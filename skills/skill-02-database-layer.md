# Skill-02: 数据库层完整规范

## 前置依赖
skill-01

## 目标
定义全部数据库查询、DAO 接口、事务规则、响应式数据流，确保所有数据访问都有明确的规范。

---

## 1. 数据库配置

| 配置项 | 值 | 说明 |
|--------|---|------|
| 数据库名称 | advance_media_kb | 文件名 |
| 版本号 | 1 | 初始版本 |
| 实体列表 | MediaItem, Album, Tag, Note, AlbumMedia, MediaTag | 全部 6 个实体 |
| 导出 schema | 是 | 用于迁移验证 |

---

## 2. DAO 接口清单

共需要 6 个 DAO，每个实体一个：

| DAO | 对应实体 | 职责 |
|-----|---------|------|
| MediaItemDao | MediaItem | 媒体项的增删改查 |
| AlbumDao | Album | 相册的增删改查 |
| TagDao | Tag | 标签的增删改查 |
| NoteDao | Note | 笔记的增删改查 |
| AlbumMediaDao | AlbumMedia | 相册-媒体关联的增删改查 |
| MediaTagDao | MediaTag | 媒体-标签关联的增删改查 |

---

## 3. MediaItemDao — 全部查询

### 3.1 基础 CRUD

| 方法 | 操作 | 说明 |
|------|------|------|
| insert(MediaItem) | INSERT | 插入一条媒体记录 |
| insertAll(List<MediaItem>) | INSERT 批量 | 批量插入媒体记录（在事务中执行） |
| update(MediaItem) | UPDATE | 更新一条媒体记录 |
| delete(MediaItem) | DELETE | 删除一条媒体记录 |
| deleteById(String id) | DELETE | 按 ID 删除 |

### 3.2 查询方法

| 方法 | 返回类型 | SQL 逻辑 | 用途 |
|------|---------|---------|------|
| getById(String id) | MediaItem? | SELECT * WHERE id = ? | 详情页加载单个媒体 |
| observeById(String id) | Flow<MediaItem?> | 同上，响应式 | 详情页实时监听 |
| getAll() | List<MediaItem> | SELECT * ORDER BY createdAt DESC | 批量操作用 |
| observeAll() | Flow<List<MediaItem>> | 同上，响应式 | "所有媒体"Tab 默认列表 |
| getByType(String type) | Flow<List<MediaItem>> | SELECT * WHERE type = ? ORDER BY createdAt DESC | 按类型过滤 |
| getByFilterMode(FilterMode mode) | Flow<List<MediaItem>> | 见下方 3.3 | 过滤器切换 |
| countAll() | Flow<Int> | SELECT COUNT(*) | 统计总数 |
| getBySha256(String hash) | MediaItem? | SELECT * WHERE sha256Hash = ? | 导入时去重检查 |

### 3.3 过滤模式查询（getByFilterMode 详细逻辑）

```
FilterMode.ALL:
    SELECT * FROM media_items ORDER BY createdAt DESC

FilterMode.WITH_TAGS:
    SELECT * FROM media_items
    WHERE EXISTS (
        SELECT 1 FROM media_tags WHERE media_tags.mediaId = media_items.id
    )
    ORDER BY createdAt DESC

FilterMode.WITHOUT_TAGS:
    SELECT * FROM media_items
    WHERE NOT EXISTS (
        SELECT 1 FROM media_tags WHERE media_tags.mediaId = media_items.id
    )
    ORDER BY createdAt DESC

FilterMode.WITH_ALBUMS:
    SELECT * FROM media_items
    WHERE EXISTS (
        SELECT 1 FROM album_media WHERE album_media.mediaId = media_items.id
    )
    ORDER BY createdAt DESC

FilterMode.WITHOUT_ALBUMS:
    SELECT * FROM media_items
    WHERE NOT EXISTS (
        SELECT 1 FROM album_media WHERE album_media.mediaId = media_items.id
    )
    ORDER BY createdAt DESC
```

### 3.4 搜索查询

| 方法 | SQL 逻辑 | 用途 |
|------|---------|------|
| searchByName(String keyword) | SELECT * WHERE originalName LIKE '%' \|\| ? \|\| '%' ORDER BY createdAt DESC | 全局搜索媒体文件名 |

### 3.5 删除方法

| 方法 | SQL 逻辑 | 说明 |
|------|---------|------|
| deleteByIds(List<String> ids) | DELETE FROM media_items WHERE id IN (?) | 批量删除（在事务中执行） |

---

## 4. AlbumDao — 全部查询

### 4.1 基础 CRUD

| 方法 | 操作 | 说明 |
|------|------|------|
| insert(Album) | INSERT | 创建相册 |
| update(Album) | UPDATE | 更新相册 |
| delete(Album) | DELETE | 删除相册（级联删除子相册） |
| deleteById(String id) | DELETE | 按 ID 删除 |

### 4.2 查询方法

| 方法 | 返回类型 | SQL 逻辑 | 用途 |
|------|---------|---------|------|
| getById(String id) | Album? | SELECT * WHERE id = ? | 加载单个相册 |
| observeById(String id) | Flow<Album?> | 同上，响应式 | 相册详情实时监听 |
| getTopLevel() | List<Album> | SELECT * WHERE parentId IS NULL ORDER BY sortOrder ASC, createdAt ASC | 顶层相册列表 |
| observeTopLevel() | Flow<List<Album>> | 同上，响应式 | 相册 Tab 展示 |
| getChildren(String parentId) | List<Album> | SELECT * WHERE parentId = ? ORDER BY sortOrder ASC, createdAt ASC | 子相册列表 |
| observeChildren(String parentId) | Flow<List<Album>> | 同上，响应式 | 相册详情页子相册区 |
| getAll() | List<Album> | SELECT * ORDER BY sortOrder ASC, createdAt ASC | 添加到相册对话框（显示全部相册含子相册） |
| observeAll() | Flow<List<Album>> | 同上，响应式 | — |
| countMediaInAlbum(String albumId) | Flow<Int> | SELECT COUNT(*) FROM album_media WHERE albumId = ? | 相册卡片显示媒体数量 |
| getAllWithMediaCount() | Flow<List<AlbumWithCount>> | 见下方 SQL | 相册列表带媒体数量 |

### 4.3 相册带媒体数量的查询

```
SELECT a.*,
    (SELECT COUNT(*) FROM album_media am WHERE am.albumId = a.id) AS mediaCount
FROM albums a
ORDER BY a.sortOrder ASC, a.createdAt ASC
```

返回的数据类 AlbumWithCount：
- album: Album
- mediaCount: Int

### 4.4 相册带封面和数量的查询

```
SELECT a.*,
    (SELECT COUNT(*) FROM album_media am WHERE am.albumId = a.id) AS mediaCount,
    (SELECT mi.thumbnailPath FROM media_items mi WHERE mi.id = a.coverMediaId) AS coverThumbnailPath
FROM albums a
WHERE a.parentId IS NULL
ORDER BY a.sortOrder ASC, a.createdAt ASC
```

返回的数据类 AlbumDisplayInfo：
- album: Album
- mediaCount: Int
- coverThumbnailPath: String?

---

## 5. TagDao — 全部查询

### 5.1 基础 CRUD

| 方法 | 操作 | 说明 |
|------|------|------|
| insert(Tag) | INSERT | 创建标签 |
| update(Tag) | UPDATE | 更新标签 |
| delete(Tag) | DELETE | 删除标签（级联删除子标签） |
| deleteById(String id) | DELETE | 按 ID 删除 |

### 5.2 查询方法

| 方法 | 返回类型 | SQL 逻辑 | 用途 |
|------|---------|---------|------|
| getById(String id) | Tag? | SELECT * WHERE id = ? | 加载单个标签 |
| observeById(String id) | Flow<Tag?> | 同上，响应式 | — |
| getAll() | List<Tag> | SELECT * ORDER BY name ASC | 标签选择器 |
| observeAll() | Flow<List<Tag>> | 同上，响应式 | 标签 Tab 展示 |
| getChildren(String parentId) | List<Tag> | SELECT * WHERE parentId = ? ORDER BY name ASC | 子标签列表 |
| observeChildren(String parentId) | Flow<List<Tag>> | 同上，响应式 | — |
| getTagsForMedia(String mediaId) | Flow<List<Tag>> | 见下方 SQL | 详情页标签面板 |
| getMediaCountForTag(String tagId) | Flow<Int> | SELECT COUNT(*) FROM media_tags WHERE tagId = ? | 标签列表显示数量 |
| getAllWithMediaCount() | Flow<List<TagWithCount>> | 见下方 SQL | 标签 Tab 带数量 |
| searchByName(String keyword) | Flow<List<Tag>> | SELECT * WHERE name LIKE '%' \|\| ? \|\| '%' ORDER BY name ASC | 标签搜索 |

### 5.3 查询媒体的所有标签

```
SELECT t.*
FROM tags t
INNER JOIN media_tags mt ON mt.tagId = t.id
WHERE mt.mediaId = ?
ORDER BY t.name ASC
```

### 5.4 标签带媒体数量的查询

```
SELECT t.*,
    (SELECT COUNT(*) FROM media_tags mt WHERE mt.tagId = t.id) AS mediaCount
FROM tags t
ORDER BY t.name ASC
```

返回的数据类 TagWithCount：
- tag: Tag
- mediaCount: Int

---

## 6. NoteDao — 全部查询

### 6.1 基础 CRUD

| 方法 | 操作 | 说明 |
|------|------|------|
| insert(Note) | INSERT | 创建笔记 |
| update(Note) | UPDATE | 更新笔记 |
| delete(Note) | DELETE | 删除笔记 |
| deleteById(String id) | DELETE | 按 ID 删除 |

### 6.2 查询方法

| 方法 | 返回类型 | SQL 逻辑 | 用途 |
|------|---------|---------|------|
| getById(String id) | Note? | SELECT * WHERE id = ? | 笔记编辑页加载 |
| observeById(String id) | Flow<Note?> | 同上，响应式 | — |
| getForMedia(String mediaId) | Flow<List<Note>> | SELECT * WHERE mediaId = ? ORDER BY updatedAt DESC | 详情页笔记面板 |
| getIndependent() | Flow<List<Note>> | SELECT * WHERE mediaId IS NULL ORDER BY updatedAt DESC | 独立笔记列表 |
| observeAll() | Flow<List<Note>> | SELECT * ORDER BY updatedAt DESC | 笔记列表页 |
| searchByTitleAndContent(String keyword) | Flow<List<Note>> | SELECT * WHERE title LIKE '%' \|\| ? \|\| '%' OR content LIKE '%' \|\| ? \|\| '%' ORDER BY updatedAt DESC | 全局搜索笔记 |

---

## 7. AlbumMediaDao — 全部查询

### 7.1 基础操作

| 方法 | 操作 | 说明 |
|------|------|------|
| insert(AlbumMedia) | INSERT | 将媒体加入相册 |
| insertAll(List<AlbumMedia>) | INSERT 批量 | 批量将多个媒体加入相册 |
| delete(AlbumMedia) | DELETE | 将媒体移出相册 |
| deleteByAlbumAndMediaIds(String albumId, List<String> mediaIds) | DELETE | 批量将多个媒体移出相册 |
| deleteByAlbumId(String albumId) | DELETE | 删除相册时清理所有关联 |
| deleteByMediaId(String mediaId) | DELETE | 删除媒体时清理所有关联 |

### 7.2 查询方法

| 方法 | 返回类型 | SQL 逻辑 | 用途 |
|------|---------|---------|------|
| getMediaForAlbum(String albumId) | Flow<List<MediaItem>> | 见下方 SQL | 相册详情页媒体网格 |
| getAlbumsForMedia(String mediaId) | Flow<List<Album>> | 见下方 SQL | 查询媒体属于哪些相册 |
| isInAlbum(String mediaId, String albumId) | Flow<Boolean> | SELECT EXISTS(SELECT 1 FROM album_media WHERE mediaId=? AND albumId=?) | 检查关联是否存在 |

### 7.3 查询相册内所有媒体

```
SELECT mi.*
FROM media_items mi
INNER JOIN album_media am ON am.mediaId = mi.id
WHERE am.albumId = ?
ORDER BY am.addedAt DESC
```

### 7.4 查询媒体所属的所有相册

```
SELECT a.*
FROM albums a
INNER JOIN album_media am ON am.albumId = a.id
WHERE am.mediaId = ?
ORDER BY a.name ASC
```

---

## 8. MediaTagDao — 全部查询

### 8.1 基础操作

| 方法 | 操作 | 说明 |
|------|------|------|
| insert(MediaTag) | INSERT | 给媒体打标签 |
| insertAll(List<MediaTag>) | INSERT 批量 | 批量给多个媒体打同一个标签 |
| delete(MediaTag) | DELETE | 移除媒体的标签 |
| deleteByMediaAndTagId(String mediaId, String tagId) | DELETE | 按 ID 移除 |
| deleteByMediaId(String mediaId) | DELETE | 删除媒体时清理所有关联 |
| deleteByTagId(String tagId) | DELETE | 删除标签时清理所有关联 |

### 8.2 查询方法

| 方法 | 返回类型 | SQL 逻辑 | 用途 |
|------|---------|---------|------|
| getTagsForMedia(String mediaId) | Flow<List<Tag>> | 见 Skill-02 §5.3 | 详情页标签面板 |
| getMediaForTag(String tagId) | Flow<List<MediaItem>> | 见下方 SQL | 标签媒体列表页 |
| getTagIdsForMedia(String mediaId) | List<String> | SELECT tagId FROM media_tags WHERE mediaId = ? | 标签选择器判断已关联状态 |
| isTagged(String mediaId, String tagId) | Flow<Boolean> | SELECT EXISTS(SELECT 1 FROM media_tags WHERE mediaId=? AND tagId=?) | 检查关联是否存在 |

### 8.3 查询标签下所有媒体

```
SELECT mi.*
FROM media_items mi
INNER JOIN media_tags mt ON mt.mediaId = mi.id
WHERE mt.tagId = ?
ORDER BY mi.createdAt DESC
```

---

## 9. 事务规则

以下操作必须在数据库事务中执行（全部成功或全部回滚）：

| 操作 | 涉及的 DAO | 说明 |
|------|-----------|------|
| 批量导入媒体 | MediaItemDao.insertAll | 一条失败则全部回滚 |
| 批量删除媒体 | MediaItemDao.deleteByIds + AlbumMediaDao.deleteByMediaId + MediaTagDao.deleteByMediaId + NoteDao (按mediaId) | 级联清理在事务中 |
| 批量添加到相册 | AlbumMediaDao.insertAll | 一条失败则全部回滚 |
| 批量移出相册 | AlbumMediaDao.deleteByAlbumAndMediaIds | 一条失败则全部回滚 |
| 批量打标签 | MediaTagDao.insertAll | 一条失败则全部回滚 |
| 删除相册 | AlbumDao.delete + AlbumMediaDao.deleteByAlbumId + AlbumDao (删除子相册) | 级联清理在事务中 |
| 删除标签 | TagDao.delete + MediaTagDao.deleteByTagId + TagDao (删除子标签) | 级联清理在事务中 |

---

## 10. 响应式数据流规则

- 所有以 `observe` 开头的方法返回 `Flow<T>` 或 `Flow<List<T>>`
- Flow 必须是 Room 自动生成的响应式查询 Flow（数据库变化时自动发出新值）
- 不允许手动轮询或定时刷新
- ViewModel 层将 Flow 转换为 StateFlow 供 UI 层消费
- UI 层使用 collectAsState 触发自动重组

**数据流链路**：
```
数据库 INSERT/UPDATE/DELETE
    → Room DAO 的 Flow 自动发出新值
    → Repository 透传
    → ViewModel 的 StateFlow 更新
    → UI 的 collectAsState 触发重组
    → 所有观察该数据的页面同时自动刷新
```

---

## 11. DI 提供规则

数据库和 DAO 必须通过依赖注入容器提供：
- 数据库实例：单例作用域
- 每个 DAO 实例：从数据库实例获取，单例作用域
- 所有 DAO 通过接口暴露，实现类在 core-database 模块中

---

## 12. 验证标准

完成本 skill 后，必须满足以下全部条件：

- [ ] 6 个 DAO 接口全部定义完成
- [ ] 每个 DAO 的所有查询方法（observe + 一次性查询）全部实现
- [ ] 所有 observe 方法返回 Flow 类型
- [ ] 过滤模式查询（5 种）的 SQL 全部正确
- [ ] 事务规则全部正确标注
- [ ] 级联删除在事务中正确执行
- [ ] 数据库实例为单例
- [ ] 所有 DAO 通过 DI 正确提供
- [ ] 数据库可正常创建和打开
- [ ] 所有 Flow 查询在数据变化时能自动发出新值
