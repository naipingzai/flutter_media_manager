# AdvanceMediaKB Skills 索引

> **用途**: 把 `docs/AdvanceMediaKB_完整设计方案.md` 拆分为 22 份可执行的 AI 步骤,
> 每份 skill 是「代码评审 checklist」+「功能实现指南」。
>
> **使用方式**:
> - **代码评审**: AI 拿到 PR 后,按对应 skill 内的「代码检查点」逐项核对。
> - **新功能开发**: AI 按对应 skill 的「设计要点」+「验收标准」实现。
> - **回归测试**: AI 按「已知问题清单」找潜在回归。

---

## Skill 列表

| # | 文件 | 主设计文档章节 | 主题 |
|---|------|--------------|------|
| 00 | `skill-00-project-architecture.md` | 第一部分 | 模块架构 / 依赖关系 / 单 Activity |
| 01 | `skill-01-data-model.md` | 第二部分 | 6 个 Room Entity + 关系 |
| 02 | `skill-02-database-layer.md` | 第二部分 | Room DAO + Database + 迁移 |
| 03 | `skill-03-design-system.md` | 第三 + 第五部分 | Material3 主题 / 颜色 / 字体 |
| 04 | `skill-04-permission-management.md` | F1 + F0.5 | 存储权限 + SAF |
| 05 | `skill-05-file-scanner.md` | F1 | 文件扫描器(支持的格式) |
| 06 | `skill-06-media-import-pipeline.md` | F1 | 媒体导入管线(去重 / 进度 / 状态机) |
| 07 | `skill-07-thumbnail-generator.md` | F1 | 缩略图生成(图 / 视频) |
| 08 | `skill-08-settings-storage.md` | F8 | DataStore + 10 个设置 |
| 09 | `skill-09-app-shell-and-navigation.md` | F0 + 第五部分 | 主屏 Shell + 三个主页 + 搜索/设置覆盖 |
| 10 | `skill-10-home-screen.md` | F2 | 所有媒体主页 + HomeFilterMode + 多选 |
| 11 | `skill-11-album-module.md` | F3 | 相册树 + 多选 |
| 12 | `skill-12-tag-module.md` | F4 | 标签树 + TagSelectorDialog(两种模式) |
| 13 | `skill-13-detail-screen.md` | F5 | 详情页 — MediaViewerActivity(独立 Activity) |
| 14 | `skill-14-note-module.md` | (空 / 作废) | **项目不做笔记** — 仅留标记 |
| 15 | `skill-15-search-module.md` | F6 | 搜索(关键字 + 标签筛选 + 历史) |
| 16 | `skill-16-settings-screen.md` | F8 | 设置页 UI(7 分区 + 6 操作) |
| 17 | `skill-17-fullscreen-viewer.md` | F5 | MediaViewerActivity 详细行为 |
| 18 | `skill-18-internationalization.md` | 第六部分 | 中英 i18n + strings.xml |
| 19 | `skill-19-state-machine.md` | F1 + F9 | 导入 / AMB 导出 / AMB 导入状态机 |
| 20 | `skill-20-testing.md` | 附录 | 测试策略(项目当前未实现) |
| 21 | `skill-21-amb-package-format.md` | F9 | AMB ZIP 格式 + manifest.json |

---

## 配套文档

| 文档 | 路径 | 用途 |
|------|------|------|
| 主设计文档 | `docs/AdvanceMediaKB_完整设计方案.md` | 总览,所有功能的权威说明 |
| 设计草稿 | `docs/00-设计草稿.md` | 过程性讨论、决策记录 |
| 一致性审查 | `docs/audit-skills-vs-code.md` | skill 与代码的对齐情况 |

---

## Skill 文件模板

每份 skill 应包含以下章节:

```markdown
# Skill-XX 主题

## 目标
(用 1-2 句话说清这个 skill 涵盖什么)

## 设计要点
(从主设计文档提取关键设计,通常是一个表格)

## 代码检查点
(评审 PR 时,AI 应核对的具体事项,用 checklist 形式)

## 验收标准
(实现新功能时,AI 应达到的标准)

## 已知问题
(在主设计文档「6.5 已知问题清单」中对应的项)

## 相关文件
(本 skill 涉及的核心代码文件)
```
