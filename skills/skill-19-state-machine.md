# Skill-19 状态机(F1 + F9)

## 目标
统一定义 ImportUseCase(媒体导入)与 AmbUseCase(导出 / 导入 AMB 包)的状态机,作为异步任务的契约。

## 设计要点

### F1 导入状态机

```
[Idle]
  ↓ start(sources)
[Pending]              ← ImportTaskEntity created
  ↓ workers 启动
[Running]              ← processedCount 持续更新
  ↓ all done
[Success]              ← addedCount = processedCount, skippedCount = 0
  ↓ 部分失败
[Partial]              ← 部分成功,errorMessage 含失败列表
  ↓ 整体失败
[Failed]               ← errorMessage 含原因
  ↓ 用户取消
[Canceled]             ← CancellationException 捕获后
```

状态枚举持久化为 `String`(见 skill-01 设计要点)。

### F9 导出 AMB 状态机

```
[Idle]
  ↓ exportToDir(sources, destDir)
[Collecting]           ← 收集 mediaId / tagId / albumId
  ↓
[CopyingFiles]         ← 复制 media 到 staging 目录
  ↓
[BuildingManifest]     ← 写 manifest.json
  ↓
[Zipping]              ← 打包成 .amb (ZIP)
  ↓
[Cleaning]             ← 删除 staging 目录
  ↓
[Success]              ← 返回 .amb 路径
  ↓ 失败
[Failed]               ← errorMessage 含原因
  ↓ 用户取消
[Canceled]
```

### F9 导入 AMB 状态机

```
[Idle]
  ↓ importFromFile(ambFile)
[ValidatingManifest]   ← 检查 ZIP + manifest.json
  ↓
[Extracting]           ← 解压到 staging
  ↓
[ImportingDatabase]    ← 逐条 importTask → MediaDao.insert (按 manifest)
  ↓
[ImportingFiles]       ← 把 media/ 复制到 SAF 持久化目录
  ↓
[Cleaning]             ← 删除 staging
  ↓
[Success]              ← 返回导入的 mediaId 列表
  ↓ 失败
[Failed]
```

### 状态机实现位置

- 导入:`ImportTaskEntity.status` + `ImportUseCase`。
- 导出 / 导入 AMB:`AmbTaskEntity.status`(如果存在)或在内存 ViewModel 中维护。

## 代码检查点

- [ ] 状态转移**不**直接写 enum 字段,走 Repository 提供的 `markXxx(taskId)` 函数。
- [ ] `CancellationException` 必须捕获并标记 `Canceled`,不能直接抛出给 UI。
- [ ] 状态字段持久化为 `String`(name),不是 ordinal。
- [ ] 状态变更通过 `Flow` 推送给 UI,UI 不轮询。
- [ ] 失败信息包含错误堆栈摘要(不超过 1KB),不泄漏完整路径。
- [ ] 进度(`processedCount`)更新频率 < 100ms/次,避免 UI 抖动。

## 验收标准

- 5 个状态(Pending/Running/Success/Partial/Failed/Canceled)都能从 UI 观察到。
- 取消后,任务 DB 记录仍在,标记 `Canceled`,用户可查看历史。
- 导出 AMB 中途断电,重启后状态正确(若实现持久化)。
- 导入 AMB 时如目标媒体已存在,跳过而非覆盖(`sha256` 去重)。

## 已知问题

- 导出 AMB 大文件(>1GB)可能 OOM,需要流式压缩。
- 导入 AMB 当前不做版本兼容校验(manifest 缺 `version` 字段)。

## 相关文件

- `domain/src/main/java/com/advancemediakb/domain/usecase/ImportUseCase.kt`
- `domain/src/main/java/com/advancemediakb/domain/usecase/AmbExportUseCase.kt`
- `domain/src/main/java/com/advancemediakb/domain/usecase/AmbImportUseCase.kt`
- `data/src/main/java/com/advancemediakb/data/import/ImportWorker.kt`
- `data/src/main/java/com/advancemediakb/data/amb/AmbExporter.kt`
- `data/src/main/java/com/advancemediakb/data/amb/AmbImporter.kt`
- `core-model/src/main/java/com/advancemediakb/model/ImportTaskEntity.kt`
