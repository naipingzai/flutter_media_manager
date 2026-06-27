# Skill-07 缩略图生成

## 目标
为导入的每条媒体生成统一尺寸 / 格式的本地缩略图,主页、相册、标签、详情缩略图统一读取。

## 设计要点

| 项 | 设计 |
|---|------|
| 输出尺寸 | 长边 ≤ 512px(原始比例) |
| 输出格式 | JPEG 质量 80(动图 GIF 保留原格式) |
| 输出路径 | `context.cacheDir/thumbs/<mediaId>.jpg` |
| 图片源 | `ContentResolver` + `BitmapFactory` + `inSampleSize` 缩放 |
| 视频源 | `MediaMetadataRetriever.getFrameAtTime(timeUs, OPTION_CLOSEST)` |
| 失败回退 | 图片:`MediaStore` 自带缩略图;视频:首帧黑屏占位 |
| 触发时机 | 导入管线入库后立即触发,失败仅记日志 |

## 代码检查点

- [ ] 用 `inSampleSize` 二次采样,**不**直接 `decodeStream` 再 `createScaledBitmap`(OOM)。
- [ ] `MediaMetadataRetriever` 必须 `release()`,放在 `finally` 或 `use { }`。
- [ ] JPEG 输出走 `FileOutputStream` + `compress`,不是 `Bitmap.save()`。
- [ ] 缩略图写入 `cacheDir` 而不是 `filesDir`,系统可在低存储时清理。
- [ ] 缩略图失败不应阻塞导入(吞异常 + 写日志)。
- [ ] 视频帧取 `getFrameAtTime(1_000_000, OPTION_CLOSEST_SYNC)`(1 秒处)。

## 验收标准

- 主页 1000 个缩略图首屏渲染 < 500ms(走 Coil 内存缓存)。
- 视频缩略图与系统相册一致(取首帧画面)。
- 删除媒体后,对应缩略图文件被一并删除(参考 F7 多选删除)。

## 已知问题

- 部分 HEIC 在某些 Android 版本无系统解码器,需 `androidx.exifinterface` + 第三方库。
- 4K 视频 `getFrameAtTime` 较慢,可考虑 `OPTION_CLOSEST` 改 `OPTION_CLOSEST_SYNC`。

## 相关文件

- `core-image/src/main/java/com/advancemediakb/image/ThumbnailGenerator.kt`
- `core-image/src/main/java/com/advancemediakb/image/VideoFrameExtractor.kt`
- `core-image/src/main/java/com/advancemediakb/image/CoilModule.kt`
