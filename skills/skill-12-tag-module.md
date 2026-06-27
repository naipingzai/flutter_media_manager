# Skill-12 标签模块 (F4)

## 目标
实现第三个主页:**标签**,展示标签树、进入标签查看其内媒体、TagSelectorDialog(两种模式:详情页绑定 / 筛选)。

## 设计要点

| 项 | 设计 |
|---|------|
| 位置 | `feature-home/.../home/tab/TagPage.kt` + `feature-tag/...` |
| 数据源 | `TagDao.observeAll(): Flow<List<TagEntity>>` |
| 树渲染 | 同相册(无限层级、客户端构造) |
| 颜色 | `TagEntity.colorHex` 用于标签左边竖条 / 选中态背景 |
| 多对多 | 媒体 ↔ 标签 走 `MediaTagCrossRef` 连接表 |
| 标签详情 | 显示标签颜色 + 名称 + 该标签下所有媒体 |

### TagSelectorDialog

| 模式 | 触发 | 行为 |
|------|------|------|
| **BIND** | 详情页「编辑标签」按钮 | 选中媒体 + 标签,保存时全量覆盖该媒体的标签列表 |
| **FILTER** | 搜索页 / 主页筛选 | 选中标签作为筛选条件,可多选,组合关系为「OR」(任一匹配) |

### BIND 模式数据流

```
TagSelectorDialog(mode=BIND, mediaIds: List<Long>) →
  onConfirm(checkedTagIds: List<Long>) →
    MediaTagBindUseCase(mediaIds, checkedTagIds) →
      for each mediaId:
        clear old cross refs
        insert new cross refs
      cross ref Flow → UI 立即更新
```

### 标签 CRUD

- **新建**:长按空白 → 输入名称 + 选颜色 + 选父标签。
- **重命名 / 改颜色**:长按标签。
- **删除**:长按标签 → 删除;其下媒体与该标签的关联被删(级联)。

## 代码检查点

- [ ] BIND 模式覆盖式写入,不是增量 diff(避免漏删旧关联)。
- [ ] FILER 模式返回 `List<Long>`(选中的标签 id)。
- [ ] 标签颜色使用 `#AARRGGBB` 字符串,**不**用 Int(避免颜色混淆)。
- [ ] 删除标签时,级联删除通过 `@ForeignKey(onDelete = CASCADE)` 在 `MediaTagCrossRef` 上声明。
- [ ] 标签名 trim 后非空才能保存。
- [ ] `TagSelectorDialog` **不**依赖 Activity,可在任意 Composable 内调用。

## 验收标准

- 详情页打开 TagSelectorDialog,显示当前媒体的已有标签 ✓ 预勾选。
- 取消勾选 → 保存 → 媒体标签立刻消失。
- 新勾选 → 保存 → 媒体标签立刻出现(Flow 推送)。
- 标签树删除父标签,子标签升级为顶级(ForeignKey SET_NULL)。
- FILER 模式多选,搜索结果为「任一命中」。

## 已知问题

- 颜色调色板目前固定 8 色;后续考虑自定义。
- 标签数量 > 1000 时 Dialog 渲染慢,可加虚拟列表。

## 相关文件

- `feature-tag/src/main/java/com/advancemediakb/tag/TagTreePage.kt`
- `feature-tag/src/main/java/com/advancemediakb/tag/TagDetailPage.kt`
- `feature-tag/src/main/java/com/advancemediakb/tag/TagViewModel.kt`
- `feature-tag/src/main/java/com/advancemediakb/tag/TagSelectorDialog.kt`
- `core-database/src/main/java/com/advancemediakb/db/TagDao.kt`
- `core-database/src/main/java/com/advancemediakb/db/MediaTagCrossRefDao.kt`
- `domain/src/main/java/com/advancemediakb/domain/usecase/MediaTagBindUseCase.kt`
