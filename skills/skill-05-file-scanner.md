# Skill-05 文件扫描器

## 目标

定义从磁盘扫描媒体文件的算法、支持的文件格式、白名单策略,作为 F1 的输入。

## 设计要点

### 实际代码的扫描器实现

| 项 | 设计 |
|---|------|
| 类名 | `MediaFileScanner`(非 `FileScanner` / `MediaStoreScanner` / `SafTreeScanner`) |
| 包路径 | `com.advancemediakb.core.common.scanner`(非 `com.advancemediakb.data.scanner`) |
| 扫描源 | `Environment.getExternalStorageDirectory()` + 6 个常见公共目录(DOWNLOADS/DOCUMENTS/PICTURES/MOVIES/DCIM/Android/media) |
| 返回类型 | `suspend fun scanAllFiles(): List<MediaFile>`(非 `Flow<ScannedFile>`) |
| 去重 | `distinctBy { it.path }`,按 `dateModified DESC` 排序 |
| 线程 | `withContext(Dispatchers.IO)` |
| 数据类 | `MediaFile(uri, path, name, size, dateModified, mimeType, isSupported)` |

### 支持的文件格式(白名单)

| 分类 | 扩展名 | 对应 MIME |
|------|--------|-----------|
| 图片 | jpg, jpeg, png, gif, webp, bmp, heic, heif | image/jpeg, image/png, image/gif, image/webp, image/bmp, image/heic |
| 视频 | mp4, mkv, avi, mov, webm, 3gp, flv, wmv | video/mp4, video/x-matroska, video/x-msvideo, video/quicktime, video/webm, video/3gpp, video/x-flv, video/x-ms-wmv |

### 扫描步骤

1. **递归扫描外部存储根目录**:`scanDirectoryRecursive(externalStorage)`
2. **扫描 6 个公共目录**:DOWNLOADS / DOCUMENTS / PICTURES / MOVIES / DCIM / Android/media
3. **去重并排序**:`distinctBy { it.path }` → `sortedByDescending { it.dateModified }`
4. **产出**:`List<MediaFile>` 交给导入管线

### v4 设想 vs 实际代码差异

| 设想 | 实际 |
|------|------|
| SAF 持久化 URI 树扫描 | ❌ 不存在 SAF 扫描,纯 `File.listFiles()` 递归 |
| `MediaStore` 查询 | ❌ 不使用 MediaStore |
| `.nomedia` 排除 | ❌ **不排除** `.nomedia`,递归包含所有子目录 |
| 隐藏文件排除 | ❌ **不排除** 隐藏文件(注释明确写"包含隐藏文件") |
| 小于 10KB 过滤 | ❌ 不按大小过滤 |
| `Flow<ScannedFile>` | ❌ 用 `suspend fun List<MediaFile>` |
| `SharedFlow<Int>` 进度 | ❌ 无进度回调 |
| `.tmp` / `.part` 排除 | ❌ 不排除 |

### 补充方法

- `isSupportedExtension(ext: String): Boolean` — 检查扩展名是否在白名单
- `getMimeTypeForExtension(ext: String): String` — 扩展名转 MIME
- `scanSupportedMediaFiles(limit: Int = 1000): List<MediaFile>` — 只返回支持的文件,限制数量

## 代码检查点

- [x] MIME 过滤走白名单(`supportedExtensions` Set),**不**用黑名单。
- [x] 不在扫描阶段计算 SHA-256,交给导入管线异步做。
- [x] 扫描器使用 `suspend fun`,`withContext(Dispatchers.IO)`,不阻塞主线程。
- [ ] **未使用** SAF `DocumentFile.fromTreeUri`(v4 设想但实际没有)。
- [ ] **未使用** `MediaStore` / `ContentResolver.query`(v4 设想但实际没有)。
- [ ] **未排除** `.nomedia` 和隐藏文件 — 与 v4 设想不符,实际代码包含所有文件。
- [ ] **无进度回调** — `scanAllFiles()` 是一次性返回完整列表。
- [x] `MediaFileScanner` 不是 Hilt 注入(普通 class,构造器接收 `Context`)。

## 验收标准

- 扫描 1000 张照片,`Dispatchers.IO` 不阻塞主线程。
- `distinctBy { path }` 确保同一文件不重复入列。
- `scanSupportedMediaFiles(limit=1000)` 限制返回数量,避免性能问题。
- `getMimeType` 对未知扩展名返回 `application/octet-stream`。

## 已知问题

- 实际代码**不排除** `.nomedia` 和隐藏文件 — 与设计意图不符,建议后续修复。
- 无进度回调,大量文件扫描时 UI 无法显示进度。
- 不使用 MediaStore,纯 `File.listFiles()`,在 Android 11+ 需要 `MANAGE_EXTERNAL_STORAGE`。
- 不支持 SAF 树 URI 扫描。

## 相关文件

- `core-common/src/main/java/com/advancemediakb/core/common/scanner/MediaFileScanner.kt` (130 行)
