# Skill-14 笔记模块

## 目标

为每个媒体绑定一条文本笔记(一对一关系),通过 `feature-detail` 的笔记 Tab 编写,通过 `feature-note` 的"全部笔记"列表查看全部笔记。

## 设计要点

| 项 | 设计 |
|---|------|
| 数据表 | `notes` (`NoteEntity` 在 `:core-model`,`NoteDao` 在 `:core-database`) |
| 关系 | **一对一**(`NoteDao.getByMedia(mediaId) LIMIT 1`),每个媒体最多 1 条笔记 |
| 级联 | `ForeignKey.CASCADE` on `media_id`,删除媒体 → 笔记自动删除 |
| UI 模块 | `:feature-note`(独立模块),但**当前为空目录**(尚未实现) |
| 笔记 Tab | 位于 `:feature-detail` 的 Tab(尚未实现,见 skill-13) |
| 字段 | `id (UUID), mediaId, content, createdAt, updatedAt` |
| 排序 | `observeAll()` 按 `updated_at DESC`(最近编辑在前) |

### 数据契约 (基于实际代码)

- `NoteEntity`:定义见 `core-model/.../NoteEntity.kt`
- `NoteDao`:提供 `insert/update/delete/getById/observeById/getByMedia/observeByMedia/observeAll/deleteById/deleteByMedia/count`
- `AppDatabase.noteDao()` 已注册
- `DatabaseModule.provideNoteDao` 已注入 Hilt

### UI 实现状态

- **数据层已完成**:Entity + DAO + DI 全在位。
- **UI 层未实现**:`feature-note/` 目录为空;`:feature-detail` 尚未集成笔记 Tab。
- AI 实现笔记 UI 时应:
  1. 在 `feature-note/` 创建 Composable + ViewModel + Navigation 入口
  2. 在 `feature-detail/` 的详情页 Tab 中接入笔记编辑面板
  3. 入口在「全部笔记」列表中按 `updated_at DESC` 展示
  4. 内容使用 Markdown 渲染(`core-designsystem` 提供 MarkdownText)

### Markdown 支持

- 笔记内容以纯文本存储,渲染时通过 `MarkdownText(content)` 解析。
- 支持标题、列表、链接、代码块。
- 不支持附件(图片/文件)内嵌。

## 代码检查点

- [ ] `:feature-note` 模块的 `build.gradle.kts` 已声明,但 Kotlin 代码为空(或仅有 README)。
- [ ] `:feature-detail` 详情页 Tab 列表(参考 skill-13)中包含「笔记」Tab 占位。
- [ ] `NoteDao.observeByMedia(mediaId): Flow<NoteEntity?>` 是一对一(`LIMIT 1`),不是多对一。
- [ ] 删除媒体时,对应笔记由 `ForeignKey.CASCADE` 自动删除,**不**需要额外 DAO 调用。
- [ ] 笔记内容字段 `content` 是 `String`(非 `String?`),空笔记内容应为空字符串 `""`。
- [ ] 任何新增笔记相关字段(优先级、附件、颜色)都应同步更新 `NoteEntity` 和 Room 迁移。
- [ ] 不在 Note 中存储 `originalName` / `thumbnailPath` 等冗余媒体信息(通过 `mediaId` 关联查询即可)。

## 验收标准

- 编辑笔记 → 关闭 App → 重新打开 → 笔记内容保留(`updatedAt` 已持久化)。
- 删除一条媒体 → 对应笔记从 `notes` 表消失(级联验证)。
- `NoteDao.count()` 等于「有笔记的媒体数」(因为一对一)。
- 「全部笔记」列表按 `updated_at DESC` 排序,最近编辑的笔记置顶。

## 相关文件

- `core-model/src/main/java/com/advancemediakb/core/model/NoteEntity.kt`
- `core-database/src/main/java/com/advancemediakb/core/database/dao/NoteDao.kt`
- `core-database/src/main/java/com/advancemediakb/core/database/di/DatabaseModule.kt`
- `feature-note/` (待实现,目前为空)
- `feature-note/build.gradle.kts` (已声明)
