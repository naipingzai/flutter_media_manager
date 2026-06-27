# Skill-16 设置页 UI (F8)

## 目标
实现 `SettingsOverlay`,展示 7 个分区 + 6 个操作,所有写操作走 `SettingsDataStore`,数据操作走 Repository。

## 设计要点

| 项 | 设计 |
|---|------|
| 入口 | 主页顶栏设置图标 → `SettingsOverlay` 全屏覆盖层 |
| 布局 | `LazyColumn` 滚动列表 |
| 分区 | 7 个(外观 / 主页 / 导入 / 标签相册 / 搜索 / 备份 / 关于) |
| 操作 | 6 个(导出 AMB / 导入 AMB / 清空数据库 / 重新扫描 / 授权管理 / 关于) |

### 7 个分区

| # | 分区 | 包含项 |
|---|------|------|
| 1 | 外观 | 主题模式、语言、网格列数 |
| 2 | 主页 | 默认筛选、是否含视频 |
| 3 | 导入 | 导入并发数、扫描根路径管理 |
| 4 | 标签相册 | 默认展开层级(后续可加) |
| 5 | 搜索 | 历史保留条数(后续可加) |
| 6 | 备份 | 备份提醒开关、导出 AMB |
| 7 | 关于 | 版本号、GitHub 链接、致谢 |

### 6 个操作

| 操作 | 触发 | 行为 |
|------|------|------|
| 导出 AMB | 点击 | 跳 `AmbOverlay` → 选择导出目录 → 生成 `.amb` ZIP |
| 导入 AMB | 点击 | 跳 `AmbOverlay` → 选择 `.amb` 文件 → 解压 + 入库 |
| 清空数据库 | 长按 / 二次确认 | 删除所有表数据(媒体文件保留) |
| 重新扫描 | 点击 | 触发 FileScanner 重新扫描 |
| 授权管理 | 点击 | 跳系统设置 → App 权限页 |
| 关于 | 点击 | 显示版本号 / 构建号 / 致谢 / 开源协议 |

### 控件规范

- 开关:`Switch` + `ListItem`。
- 单选:`RadioButton` 列表(`AlertDialog` 弹出)。
- 数字:`Slider`(如导入并发数)。
- 操作:文本按钮 + 描述 + 箭头。
- 分区标题:`SectionHeader`(见 skill-03)。

## 代码检查点

- [ ] 设置项写操作走 `SettingsDataStore.setXxx(...)`,**不**直接动 DataStore。
- [ ] 数据库清空走 `MediaRepository.clearAll()`,**不**直接 `database.clearAllTables()`(需配套清缩略图)。
- [ ] 危险操作(清空数据库)必须二次确认 `AlertDialog`。
- [ ] 重新扫描按钮触发后,显示进度,完成后 toast。
- [ ] 关于页版本号从 `BuildConfig.VERSION_NAME` 读,**不**写死。

## 验收标准

- 7 个分区齐全,6 个操作均可点击。
- 修改任何设置项,返回主页后立即生效。
- 危险操作二次确认,误触不直接执行。
- 关于页版本号与 `app/build.gradle.kts` 的 `versionName` 一致。

## 已知问题

- 「标签相册」分区目前只占位,实际无设置项。
- 「搜索」分区历史条数目前硬编码 20。

## 相关文件

- `feature-settings/src/main/java/com/advancemediakb/settings/SettingsOverlay.kt`
- `feature-settings/src/main/java/com/advancemediakb/settings/SettingsViewModel.kt`
- `feature-settings/src/main/java/com/advancemediakb/settings/section/`
- `feature-settings/src/main/java/com/advancemediakb/settings/action/`
