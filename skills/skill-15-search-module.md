# Skill-15 搜索模块 (F6)

## 目标
实现关键字搜索 + 标签筛选,搜索结果显示为媒体网格,带搜索历史。

## 设计要点

| 项 | 设计 |
|---|------|
| 入口 | 主页顶栏搜索图标 → `SearchOverlay` 全屏覆盖层 |
| 关键字 | 匹配 `displayName` LIKE / `relativePath` LIKE / `dateTakenSec` 解析的日期串 |
| 标签筛选 | 多选标签,组合关系「OR」(任一命中) |
| 历史 | `SearchHistoryEntity` 持久化,最多展示 20 条 |
| 去抖 | 输入框 `debounce(300ms)` 后触发查询 |
| 结果布局 | `LazyVerticalGrid` 复用主页缩略图组件 |
| 空状态 | 无结果时显示「试试其他关键字」+ 清除筛选 |
| 取消 | 顶栏返回按钮 / 系统返回键 |

### 数据流

```
SearchViewModel.query(keyword, tagIds)
  ↓ (debounce 300ms + flatMapLatest)
MediaDao.searchByKeyword(keyword, tagIds) : Flow<List<MediaEntity>>
  ↓
SearchResultsGrid(media)
```

### 关键字匹配规则

| 字段 | 匹配方式 |
|------|---------|
| `displayName` | `LIKE '%keyword%'`(不区分大小写) |
| `relativePath` | `LIKE '%keyword%'` |
| `dateTakenSec` | 若 keyword 是 `yyyy-MM-dd` / `yyyyMMdd` / `yyyy` 格式,匹配该日期 / 年份 |
| `tag.name` | 通过 JOIN `MediaTagCrossRef + Tag` 也参与 LIKE |

### SQL 示例

```sql
SELECT DISTINCT m.* FROM media m
LEFT JOIN media_tag_cross_ref mc ON m.id = mc.mediaId
LEFT JOIN tag t ON mc.tagId = t.id
WHERE
  (:keyword IS NULL OR m.displayName LIKE :kwPattern OR m.relativePath LIKE :kwPattern
   OR t.name LIKE :kwPattern
   OR strftime('%Y-%m-%d', m.dateTakenSec, 'unixepoch') = :keyword)
  AND (:hasTagFilter = 0 OR m.id IN (SELECT mediaId FROM media_tag_cross_ref WHERE tagId IN (:tagIds)))
ORDER BY m.dateTakenSec DESC
LIMIT 1000
```

## 代码检查点

- [ ] 搜索输入框用 `OutlinedTextField`,有清除按钮。
- [ ] 查询走 `flatMapLatest`,旧查询自动取消。
- [ ] debounce 至少 250ms,避免每个按键触发查询。
- [ ] 关键字 trim 后非空才查询。
- [ ] 搜索历史去重(`upsert`),相同 keyword `useCount++`。
- [ ] 进入搜索页时,自动 focus 输入框(`FocusRequester`)。

## 验收标准

- 输入「2024」能搜到 2024 年所有媒体(按 `dateTakenSec`)。
- 多选标签筛选结果为「OR」组合。
- 杀进程重启,搜索历史仍在。
- 搜索结果点击 → 进入 `MediaViewerActivity`,列表是搜索结果列表(不是全量)。

## 已知问题

- 大表全 LIKE 较慢,可考虑 FTS4 / FTS5(后续优化)。
- 搜索结果超过 1000 条不展示更多(限制)。

## 相关文件

- `feature-search/src/main/java/com/advancemediakb/search/SearchOverlay.kt`
- `feature-search/src/main/java/com/advancemediakb/search/SearchViewModel.kt`
- `feature-search/src/main/java/com/advancemediakb/search/SearchHistoryPanel.kt`
- `core-database/src/main/java/com/advancemediakb/db/MediaDao.kt`(`searchByKeyword` 方法)
