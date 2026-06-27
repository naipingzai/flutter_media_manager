# Skill-20 测试策略

## 目标
定义项目的测试层级、覆盖目标、当前未实现的事实,作为 AI 评审 / 补全测试的指南。

## 设计要点

| 项 | 设计 |
|---|------|
| 测试目录 | `:core-database/src/test/` `androidTest/`、`:domain/src/test/` 等 |
| 当前状态 | ⚠️ 项目当前**几乎未实现**单元 / UI 测试,目录存在但内容空 |
| 推荐覆盖 | DAO CRUD、UseCase 业务逻辑、状态机迁移、树构建、防环校验 |
| 工具 | JUnit4 + Truth / AssertJ + MockK + Robolectric + Compose UI Test |

### 推荐分层

| 层 | 测试类型 | 工具 | 例子 |
|----|---------|------|------|
| `:core-model` | 纯单元 | JUnit | Entity 字段校验 |
| `:core-database` | Room in-memory | `Room.inMemoryDatabaseBuilder` + JUnit | DAO 增删改查 |
| `:domain` | 业务单元 | JUnit + MockK | UseCase 行为、防环校验 |
| `:data` | 集成 | Robolectric | Repository + Room + DataStore |
| `:feature-*` | Compose UI | `createComposeRule()` | 主页渲染 / 多选 / Dialog |

### 关键测试用例清单(应当补全)

- [ ] `AlbumDao`:插入 + 自引用 FK + `SET_NULL` 行为。
- [ ] `MediaTagCrossRefDao`:批量 bind/unbind + 联合查询。
- [ ] `MediaDao.searchByKeyword`:keyword + tagIds 组合 OR 关系。
- [ ] `AlbumTreeBuilder.canMove`:防环(自环 / 后代环)。
- [ ] `MediaTagBindUseCase.bind(mediaIds, tagIds)`:覆盖式写入。
- [ ] `ImportUseCase`:SHA-256 重复跳过。
- [ ] `AmbExporter`:manifest.json schema 校验。
- [ ] Compose:`AllMediaPage` 5 种 filter 切换。
- [ ] Compose:`TagSelectorDialog` BIND / FILTER 模式。

## 代码检查点

- [ ] 新增 DAO 函数必须配 Room in-memory 测试(否则视为不完整)。
- [ ] 业务逻辑(UseCase)必须有 JUnit 测试覆盖**至少** happy path + 1 个边界。
- [ ] 树 / 状态机变更必须有专门的迁移测试。
- [ ] UI 测试**至少** 1 个 smoke test(主页可渲染)。
- [ ] 测试不应依赖外部网络 / 真实文件系统。
- [ ] `androidTest/` 与 `test/` 分离:Room 测试放 `test/`(Robolectric),需要 Context 的放 `androidTest/`。

## 验收标准

- `core-database` DAO 覆盖率 ≥ 60%。
- `domain` UseCase 覆盖率 ≥ 80%。
- 任何 PR 不能降低现有测试通过率。
- CI 默认跑 `./gradlew test`。

## 已知问题

- 当前项目**几乎无测试**,需大量补全。
- Robolectric 在 JVM 单测下启动慢(>5s),需考虑迁移部分到 `androidTest`。

## 相关文件

- `core-database/src/test/`
- `core-database/src/androidTest/`
- `domain/src/test/`
- `data/src/test/`
- (feature 模块当前未配测试源集)
