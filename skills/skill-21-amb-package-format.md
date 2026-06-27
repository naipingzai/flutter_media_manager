# Skill-21 AMB 包格式 (F9)

## 目标
定义 AdvanceMediaKB 自有 `.amb` 包格式,用于跨设备 / 跨 App 备份相册 + 标签 + 专辑树。`.amb` 本质是 ZIP,但内部结构固定。

## 设计要点

### 文件结构

```
my-album.amb (ZIP)
├── manifest.json         ← 元数据(版本、App 版本、生成时间、统计)
├── media/                ← 所有媒体文件,按 sha256 前 2 位分子目录
│   ├── ab/
│   │   ├── abcd1234...jpg
│   │   └── abcd5678...mp4
│   └── cd/
│       └── cdef9012...heic
├── thumbnails/           ← 缩略图(可选,加速导入)
│   └── ab/
│       └── abcd1234...jpg
└── database/
    ├── media.json        ← MediaEntity 列表
    ├── album.json        ← AlbumEntity 列表(树扁平化)
    ├── tag.json          ← TagEntity 列表(树扁平化)
    └── media_tag.json    ← MediaTagCrossRef 列表
```

### manifest.json schema

```json
{
  "formatVersion": "1.0",
  "appVersion": "AdvanceMediaKB/1.2.3",
  "exportedAt": "2026-06-27T12:34:56Z",
  "exportedBy": "device:Pixel-8",
  "stats": {
    "mediaCount": 1234,
    "albumCount": 12,
    "tagCount": 56,
    "mediaTagRefCount": 789,
    "totalBytes": 9876543210
  },
  "mediaRootRelativePaths": ["/DCIM/", "/Pictures/"]
}
```

### media.json schema

```json
[
  {
    "id": 1,
    "displayName": "IMG_20250101_120000.jpg",
    "mimeType": "image/jpeg",
    "relativePath": "DCIM/Camera/IMG_20250101_120000.jpg",
    "sizeBytes": 4567890,
    "dateAddedSec": 1735732800,
    "dateTakenSec": 1735732800,
    "durationMs": null,
    "width": 4032,
    "height": 3024,
    "sha256": "abcd1234...",
    "thumbPath": "thumbnails/ab/abcd1234....jpg",
    "albumId": 5
  }
]
```

### album.json schema

```json
[
  { "id": 1, "name": "Travel", "parentId": null, "coverMediaId": 100, "sortOrder": 0, "createdAtSec": 1735000000 },
  { "id": 2, "name": "2025", "parentId": 1, "coverMediaId": 101, "sortOrder": 0, "createdAtSec": 1735000100 }
]
```

### tag.json schema

```json
[
  { "id": 1, "name": "Family", "parentId": null, "colorHex": "#FF8800FF", "sortOrder": 0, "createdAtSec": 1735000000 }
]
```

### media_tag.json schema

```json
[
  { "mediaId": 1, "tagId": 1 },
  { "mediaId": 1, "tagId": 2 }
]
```

## 关键约束

- `id` 在不同设备可能冲突,导入时**重新映射**为新 id。
- `parentId` / `albumId` 在重映射后也要同步替换。
- `media/` 路径下的文件按 `sha256` 去重(同一包内不可能有重复 sha)。
- 导入时若 App 数据库已有相同 sha 的媒体,**跳过**(不覆盖)。

## 压缩策略

- 媒体文件:**不**二次压缩(本来就是 jpg/mp4)。
- JSON 文件:UTF-8 + 无 BOM。
- 整体用 `ZipOutputStream` 压缩级别 `STORED`(媒体已压缩)or `DEFLATED`(对 json)。

## 代码检查点

- [ ] `.amb` 本质是 ZIP,扩展名 `.amb`,MimeType `application/octet-stream`。
- [ ] `media/` 按 `sha256` 前 2 位分目录,避免单目录文件过多。
- [ ] `manifest.json` 必含 `formatVersion`,导入时校验。
- [ ] 导出/导入时 JSON 字段顺序与 `Entity` 一致,避免漏字段。
- [ ] id 重映射在 `AmbImporter` 中做,**不**让调用方关心。
- [ ] 导入失败应回滚(删除已插入的数据)。

## 验收标准

- 导出 1000 媒体 + 10 相册 + 50 标签,`.amb` 大小 ≈ 媒体原始大小(因为不二次压缩)。
- 同一 `.amb` 在不同设备上导入,得到相同的树结构。
- 导入时不覆盖 App 已有相同 sha 的媒体。
- `.amb` 文件可用 `unzip` 命令解包验证结构。

## 已知问题

- 大文件(>2GB)在 32 位设备上 `ZipOutputStream` 可能 OOM,需分卷。
- `formatVersion` 当前仅 1.0,无版本兼容代码;后续加 v2 时需 `AmbImporter` 适配。

## 相关文件

- `data/src/main/java/com/advancemediakb/data/amb/AmbExporter.kt`
- `data/src/main/java/com/advancemediakb/data/amb/AmbImporter.kt`
- `data/src/main/java/com/advancemediakb/data/amb/AmbManifest.kt`
- `data/src/main/java/com/advancemediakb/data/amb/AmbJsonCodec.kt`
- `core-model/src/main/java/com/advancemediakb/model/amb/`
- `feature-home/src/main/java/com/advancemediakb/home/overlay/AmbOverlay.kt`
