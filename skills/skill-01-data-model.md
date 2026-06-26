# Skill-01: 数据模型完整规范

## 前置依赖
skill-00

## 目标
定义全部实体、枚举、数据传输对象，确保数据库层和业务层有统一的数据结构。

---

## 1. 实体清单

共 6 个实体 + 2 个枚举，全部必须实现，一个不能少：

| # | 实体名 | 说明 | 关系类型 |
|---|--------|------|---------|
| 1 | MediaItem | 媒体项（图片/视频） | 主实体 |
| 2 | Album | 相册 | 自引用（树形） |
| 3 | Tag | 标签 | 自引用（树形） |
| 4 | Note | 笔记 | 外键→MediaItem |
| 5 | AlbumMedia | 相册-媒体关联 | 多对多关联表 |
| 6 | MediaTag | 媒体-标签关联 | 多对多关联表 |

| # | 枚举名 | 说明 |
|---|--------|------|
| 1 | MediaType | 媒体类型：IMAGE, VIDEO |
| 2 | FilterMode | 过滤模式：ALL, WITH_TAGS, WITHOUT_TAGS, WITH_ALBUMS, WITHOUT_ALBUMS |

---

## 2. MediaItem（媒体项）

**用途**：表示一个已导入的媒体文件（图片或视频）。

**字段定义**：

| 字段名 | 类型 | 可空 | 默认值 | 约束 | 说明 |
|--------|------|------|--------|------|------|
| id | String（UUID） | 否 | 自动生成 | 主键 | 唯一标识 |
| originalName | String | 否 | — | 非空 | 原始文件名（如 "IMG_20240101.jpg"） |
| storageName | String | 否 | — | 非空 | 内部存储文件名（去重处理后） |
| filePath | String | 否 | — | 非空 | 应用私有存储中的完整文件路径 |
| thumbnailPath | String | 否 | — | 非空 | 缩略图路径（不允许为 null，即使生成失败也必须指向默认占位图） |
| type | MediaType | 否 | — | 非空 | IMAGE 或 VIDEO |
| mimeType | String | 否 | — | 非空 | 如 "image/jpeg"、"video/mp4" |
| size | Long | 否 | — | ≥ 0 | 文件大小（字节） |
| width | Int? | 是 | null | — | 图片/视频宽度（像素），无法获取时为 null |
| height | Int? | 是 | null | — | 图片/视频高度（像素），无法获取时为 null |
| duration | Long? | 是 | null | — | 视频时长（毫秒），图片为 null |
| sha256Hash | String | 否 | — | 非空 | 文件 SHA256 哈希值，用于防重复导入 |
| createdAt | Long（时间戳） | 否 | 当前时间 | 非空 | 导入时间（毫秒级 Unix 时间戳） |
| updatedAt | Long（时间戳） | 否 | 当前时间 | 非空 | 最后修改时间（毫秒级 Unix 时间戳） |

**索引要求**：
- 主键索引：id
- 普通索引：createdAt（用于按时间排序查询）
- 普通索引：type（用于按类型过滤）
- 唯一索引：sha256Hash（用于去重检查）

**级联规则**：
- 删除 MediaItem 时，级联删除所有关联的 Note（通过 mediaId 外键）
- 删除 MediaItem 时，级联删除所有关联的 AlbumMedia 记录
- 删除 MediaItem 时，级联删除所有关联的 MediaTag 记录

---

## 3. Album（相册）

**用途**：表示一个相册，支持无限层级的树形目录结构。

**字段定义**：

| 字段名 | 类型 | 可空 | 默认值 | 约束 | 说明 |
|--------|------|------|--------|------|------|
| id | String（UUID） | 否 | 自动生成 | 主键 | 唯一标识 |
| name | String | 否 | — | 非空 | 相册名称 |
| parentId | String? | 是 | null | 外键→Album.id | 父相册 ID（null = 顶层相册） |
| coverMediaId | String? | 是 | null | 外键→MediaItem.id | 封面媒体 ID |
| sortOrder | Int | 否 | 0 | ≥ 0 | 排序序号（支持拖拽排序） |
| createdAt | Long（时间戳） | 否 | 当前时间 | 非空 | 创建时间 |

**索引要求**：
- 主键索引：id
- 普通索引：parentId（用于查询子相册）
- 普通索引：sortOrder（用于排序）

**级联规则**：
- 删除 Album 时，级联删除所有子相册（通过 parentId 自引用外键的 CASCADE）
- 删除 Album 时，级联删除所有 AlbumMedia 关联记录
- 删除 Album 时，不删除 MediaItem 本身（媒体文件保留在"所有媒体"中）

**树形结构规则**：
- parentId 为 null 的是顶层相册
- 理论上支持无限层级嵌套
- 实际建议限制 8 层（在 UI 层面限制，数据层不做硬限制）

---

## 4. Tag（标签）

**用途**：表示一个标签，支持层级结构。

**字段定义**：

| 字段名 | 类型 | 可空 | 默认值 | 约束 | 说明 |
|--------|------|------|--------|------|------|
| id | String（UUID） | 否 | 自动生成 | 主键 | 唯一标识 |
| name | String | 否 | — | 非空 | 标签名称 |
| color | String? | 是 | null | — | 标签颜色（十六进制色值，如 "#FF5722"） |
| parentId | String? | 是 | null | 外键→Tag.id | 父标签 ID（null = 顶层标签） |
| createdAt | Long（时间戳） | 否 | 当前时间 | 非空 | 创建时间 |

**索引要求**：
- 主键索引：id
- 普通索引：parentId（用于查询子标签）

**级联规则**：
- 删除 Tag 时，级联删除所有子标签
- 删除 Tag 时，级联删除所有 MediaTag 关联记录
- 删除 Tag 时，不删除 MediaItem 本身

---

## 5. Note（笔记）

**用途**：表示一条笔记，可以关联到某个媒体，也可以是独立笔记。

**字段定义**：

| 字段名 | 类型 | 可空 | 默认值 | 约束 | 说明 |
|--------|------|------|--------|------|------|
| id | String（UUID） | 否 | 自动生成 | 主键 | 唯一标识 |
| mediaId | String? | 是 | null | 外键→MediaItem.id | 关联的媒体 ID（null = 独立笔记） |
| title | String | 否 | "" | 非空 | 笔记标题，默认空字符串 |
| content | String | 否 | "" | 非空 | 笔记内容，默认空字符串 |
| createdAt | Long（时间戳） | 否 | 当前时间 | 非空 | 创建时间 |
| updatedAt | Long（时间戳） | 否 | 当前时间 | 非空 | 最后修改时间 |

**索引要求**：
- 主键索引：id
- 普通索引：mediaId（用于查询关联笔记）

**级联规则**：
- 删除 MediaItem 时，级联删除所有关联的 Note（mediaId 外键 CASCADE）

---

## 6. AlbumMedia（相册-媒体关联表）

**用途**：多对多关联表，记录哪个媒体属于哪个相册。

**字段定义**：

| 字段名 | 类型 | 可空 | 默认值 | 约束 | 说明 |
|--------|------|------|--------|------|------|
| albumId | String | 否 | — | 联合主键之一，外键→Album.id | 相册 ID |
| mediaId | String | 否 | — | 联合主键之一，外键→MediaItem.id | 媒体 ID |
| addedAt | Long（时间戳） | 否 | 当前时间 | 非空 | 加入相册的时间 |

**索引要求**：
- 联合主键：(albumId, mediaId)
- 普通索引：mediaId（用于查询媒体属于哪些相册）
- 普通索引：albumId（用于查询相册内所有媒体）

**级联规则**：
- 删除 Album 时，级联删除关联记录
- 删除 MediaItem 时，级联删除关联记录

---

## 7. MediaTag（媒体-标签关联表）

**用途**：多对多关联表，记录哪个媒体拥有哪个标签。

**字段定义**：

| 字段名 | 类型 | 可空 | 默认值 | 约束 | 说明 |
|--------|------|------|--------|------|------|
| mediaId | String | 否 | — | 联合主键之一，外键→MediaItem.id | 媒体 ID |
| tagId | String | 否 | — | 联合主键之一，外键→Tag.id | 标签 ID |
| createdAt | Long（时间戳） | 否 | 当前时间 | 非空 | 关联创建时间 |

**索引要求**：
- 联合主键：(mediaId, tagId)
- 普通索引：mediaId（用于查询媒体的所有标签）
- 普通索引：tagId（用于查询标签的所有媒体）

**级联规则**：
- 删除 MediaItem 时，级联删除关联记录
- 删除 Tag 时，级联删除关联记录

---

## 8. MediaType 枚举

| 值 | 字符串表示 | 说明 |
|----|-----------|------|
| IMAGE | "image" | 图片类型 |
| VIDEO | "video" | 视频类型 |

---

## 9. FilterMode 枚举

| 值 | 说明 | 数据源 |
|----|------|--------|
| ALL | 全部媒体 | 查询全部媒体 |
| WITH_TAGS | 有标签的媒体 | EXISTS (media_tags) |
| WITHOUT_TAGS | 无标签的媒体 | NOT EXISTS (media_tags) |
| WITH_ALBUMS | 有相册的媒体 | EXISTS (album_media) |
| WITHOUT_ALBUMS | 无相册的媒体 | NOT EXISTS (album_media) |

---

## 10. ID 生成规则

- 所有实体的 ID 使用 UUID v4 格式
- 格式示例："550e8400-e29b-41d4-a716-446655440000"
- 在创建实体时自动生成，不依赖数据库自增

---

## 11. 时间戳规则

- 所有时间字段使用毫秒级 Unix 时间戳（Long 类型）
- 创建时：createdAt 和 updatedAt 都设为当前时间
- 更新时：仅更新 updatedAt 为当前时间，createdAt 保持不变

---

## 12. 验证标准

完成本 skill 后，必须满足以下全部条件：

- [ ] 6 个实体类全部定义完成，字段完整
- [ ] 2 个枚举类全部定义完成
- [ ] 每个实体的主键、索引、外键约束正确定义
- [ ] 级联删除规则在关联表上正确定义
- [ ] 自引用外键（Album.parentId, Tag.parentId）正确定义
- [ ] 所有 ID 字段使用 UUID 字符串类型
- [ ] 所有时间字段使用 Long 类型（毫秒时间戳）
- [ ] MediaItem.thumbnailPath 字段不允许为 null
- [ ] Note.title 和 Note.content 有默认值（空字符串）
- [ ] 所有实体类可正常实例化和序列化
