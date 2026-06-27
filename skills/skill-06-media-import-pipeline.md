# Skill-06 媒体导入管线 (F1)

## 目标
定义从「已扫描文件列表」到「媒体入库 + 缩略图生成 + 进度回调」的完整状态机,实现去重、并发控制、错误恢复。

## 设计要点

| 项 | 设计 |
|---|------|
| 入口 | `ImportUseCase.start(sources: List<ImportSource>): Long` 返回 ImportTask id |
| 任务模型 | `ImportTaskEntity(status: PENDING/RUNNING/SUCCESS/PARTIAL/FAILED/...)` |
| 进度暴露 | `ImportRepository.observeTask(id): Flow<ImportTaskEntity>` |
| 去重键 | `sha256`(优先);URI 仅作 fallback |
| 哈希计算 | 异步 + 节流(每文件 ≤ 50MB 一次性读,> 50MB 分块) |
| 缩略图 | 触发 `ThumbnailUseCase.generate(mediaId)`,失败不阻塞导入 |
| 并发 | 导入 worker 默认 2 协程,可被设置项 `importConcurrency` 覆盖 |
| 取消 | 协程作用域取消后,任务标记 `CANCELED`,DB 记录保留 |

### 状态机

```
PENDING → RUNNING → SUCCESS   (全部成功)
                  → PARTIAL   (部分失败,errorMessage 含失败原因)
                  → FAILED    (整体失败)
                  → CANCELED  (用户取消)
```

### 步骤拆解

1. 创建 `ImportTaskEntity`,状态 `PENDING`。
2. 对每个 `ScannedFile`:
   - 计算 SHA-256。
   - `MediaDao.findBySha256(sha)` 已存在 → `skippedCount++`,跳过。
   - 不存在 → 插入 `MediaEntity`,`addedCount++`。
   - 异步触发缩略图生成。
3. 更新任务 `processedCount`、`addedCount`、`skippedCount`。
4. 全部完成后,更新状态 `SUCCESS` / `PARTIAL` / `FAILED`。
5. 失败的文件记录到 `ImportTaskEntity.errorMessage`(JSON 数组)。

## 代码检查点

- [ ] SHA-256 计算放在 `Dispatchers.IO`,**不**放 Default(可能 OOM)。
- [ ] 大文件哈希使用 `DigestInputStream` 分块读,不是一次性 `readBytes`。
- [ ] 每次插入后 `processedCount` 立即更新,UI 进度实时。
- [ ] 任务取消要捕获 `CancellationException`,并把状态置为 `CANCELED`。
- [ ] 失败原因不能吞 `Throwable`,至少写到日志 + errorMessage。
- [ ] 缩略图生成失败不应回滚媒体入库。
- [ ] 没有「全部扫描完再入库」的设计,必须流式。

## 验收标准

- 导入 5000 张照片,内存峰值 < 200MB。
- 取消后再次启动同一任务,不产生重复媒体。
- 同一文件重复导入,第二次显示「已存在」并 `skippedCount++`。

## 已知问题

- SAF URI 在部分厂商重启后会失效,需要重新授权。
- HEIC 缩略图可能为黑屏(设备解码器问题),考虑用系统自带 `MediaStore` 缩略图。

## 相关文件

- `domain/src/main/java/com/advancemediakb/domain/usecase/ImportUseCase.kt`
- `data/src/main/java/com/advancemediakb/data/repository/ImportRepositoryImpl.kt`
- `data/src/main/java/com/advancemediakb/data/import/ImportWorker.kt`
- `data/src/main/java/com/advancemediakb/data/import/Sha256Calculator.kt`
- `core-model/src/main/java/com/advancemediakb/model/ImportTaskEntity.kt`
