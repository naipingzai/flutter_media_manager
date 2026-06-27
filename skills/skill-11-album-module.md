# Skill-11 相册模块 (F3)

## 目标
实现第二个主页:**相册**,展示相册树(无限层级)、进入相册查看其内媒体、支持相册 CRUD、多选。

## 设计要点

| 项 | 设计 |
|---|------|
| 位置 | `feature-home/.../home/tab/AlbumPage.kt` + `feature-album/...` |
| 数据源 | `AlbumDao.observeAll(): Flow<List<AlbumEntity>>` + 客户端构造树 |
| 树渲染 | `AlbumTreeNode`(递归 Composable),展开 / 折叠状态用 `rememberSaveable` |
| 顶级节点 | `parentId IS NULL` |
| 排序 | 同级按 `sortOrder ASC`,未设置时按 `createdAtSec ASC` |
| 进入相册 | 点击顶级 / 子相册 → 切到「相册详情」视图 |
| 相册详情 | 显示相册封面 (`coverMediaId`) + 名称 + 媒体网格 |
| 媒体网格 | 复用 `AllMediaPage` 的网格渲染 |
| 长按多选 | 多选相册节点(用于批量删除 / 移动) |

### 相册 CRUD

- **新建**:长按空白处 → 输入名称 → 选择父相册(可空)。
- **重命名**:长按相册 → 重命名。
- **删除**:长按相册 → 删除;子相册升级为顶级(外键 `SET_NULL`),其内媒体 `albumId = NULL`。
- **移动**:长按相册 → 选择新父相册;不能移动到自己 / 自己的后代(防环)。
- **设置封面**:在「相册详情」里长按某媒体 → 「设为封面」。

### 防环校验

```
fun canMove(albumId, newParentId): Boolean {
  if (newParentId == null) return true
  if (albumId == newParentId) return false
  // 沿着 newParentId 向上找祖先,如果遇到 albumId 则成环
  var cur = newParentId
  while (cur != null) {
    if (cur == albumId) return false
    cur = albumOf(cur).parentId
  }
  return true
}
```

## 代码检查点

- [ ] 树渲染**不**在 SQL 里递归;一次查全集,UI 构造。
- [ ] 展开 / 折叠状态 `rememberSaveable`(旋转屏幕保留)。
- [ ] 删除相册走 `AlbumDao.delete()`(外键 `SET_NULL` 自动生效)。
- [ ] 移动相册前**先** `canMove` 校验,**不**交给 DB 报错。
- [ ] 相册名 trim 后非空才能保存。
- [ ] 同名相册在同级下允许(`parentId` 限定)。

## 验收标准

- 树深度 10 级仍能流畅渲染。
- 删除中间层相册,其子相册自动提升为顶级。
- 移动相册到自己后代被阻止,有 toast 提示。
- 相册封面在删除媒体后自动回退到「无封面」占位。

## 已知问题

- 大量相册(>500)平铺时滚动稍慢,后续可加虚拟滚动。
- 封面更新走同步 DAO 调用,可能阻塞;后续可异步。

## 相关文件

- `feature-album/src/main/java/com/advancemediakb/album/AlbumTreePage.kt`
- `feature-album/src/main/java/com/advancemediakb/album/AlbumDetailPage.kt`
- `feature-album/src/main/java/com/advancemediakb/album/AlbumViewModel.kt`
- `feature-album/src/main/java/com/advancemediakb/album/AlbumTreeBuilder.kt`
- `core-database/src/main/java/com/advancemediakb/db/AlbumDao.kt`
- `core-model/src/main/java/com/advancemediakb/model/AlbumEntity.kt`
