# Skill-04 权限管理

## 目标

定义 Android 存储权限模型、`MANAGE_EXTERNAL_STORAGE` 申请路径,保证 F1 导入能扫到目标文件。

## 设计要点

### 实际代码的权限管理实现

| 项 | 设计 |
|---|------|
| 类名 | `StoragePermissionManager`(object 单例) |
| 包路径 | `com.advancemediakb.core.common.permission`(非 `com.advancemediakb.common.permission`) |
| 目标 SDK | 见 `build.gradle.kts`(待确认) |
| 权限声明 | `READ_EXTERNAL_STORAGE` + `MANAGE_EXTERNAL_STORAGE` |
| 全盘访问 | API ≥ 30(R)用 `Environment.isExternalStorageManager()` |
| 低版本回退 | API < 30 检查 `READ_EXTERNAL_STORAGE` |

### AndroidManifest.xml 实际声明

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
```

> **注意**:Manifest 中**没有**声明 `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO`(Android 13+),也**没有** `tools:ignore="ScopedStorage"`。
> 实际代码**有** `android:requestLegacyExternalStorage="true"` — v4 设想说已废弃但实际代码保留了。

### StoragePermissionManager API

| 方法 | 说明 |
|------|------|
| `hasAllFilesAccess(context): Boolean` | API≥30 用 `isExternalStorageManager()`;API<30 检查 `READ_EXTERNAL_STORAGE` |
| `requestAllFilesAccess(context)` | 简化版,内部调用 `requestAllFilesAccessPermission`,自动 `findActivity` 启动 Intent |
| `requestAllFilesAccessPermission(context, onIntentLaunched, onError)` | 带回调版本,支持 `ActivityResultLauncher`;尝试 3 种 Intent 兼容不同 ROM |
| `hasReadStoragePermission(context): Boolean` | 检查 `READ_EXTERNAL_STORAGE` |

### Intent 兼容策略(3 种降级)

1. `ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION`(Android 11+ 推荐,精确到包名)
2. `ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION`(全盘权限列表)
3. `ACTION_APPLICATION_DETAILS_SETTINGS`(应用信息页兜底)

### v4 设想 vs 实际代码差异

| 设想 | 实际 |
|------|------|
| `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` | ❌ 未声明 |
| `tools:ignore="ScopedStorage"` | ❌ 未声明 |
| `requestLegacyExternalStorage` 已废弃 | ❌ 实际代码保留了 `requestLegacyExternalStorage="true"` |
| SAF `ActivityResultContracts.OpenDocument` | ❌ 未实现 SAF 文件选择 |
| `takePersistableUriPermission` | ❌ 未实现 SAF 权限持久化 |
| 最低 SDK 31 | ⚠️ 待确认 `build.gradle.kts` |
| `PermissionGate.kt` | ❌ 不存在 |

### 授权流程(实际)

1. App 启动 → 检查 `hasAllFilesAccess(context)`
2. 未授权 → 调用 `requestAllFilesAccess(context)` → 跳系统设置页
3. 用户授权后返回 → 再次检查
4. 扫描器(`MediaFileScanner`)直接用 `File.listFiles()`,依赖全盘访问权限

## 代码检查点

- [x] `AndroidManifest.xml` 含 `MANAGE_EXTERNAL_STORAGE` 声明。
- [ ] **有** `requestLegacyExternalStorage="true"` — v4 设想废弃,实际代码保留(可能需要清理)。
- [ ] **未声明** `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO`(Android 13+ 需要)。
- [ ] **未使用** SAF `ActivityResultLauncher` / `OpenDocumentTree`。
- [ ] **未调用** `takePersistableUriPermission`。
- [x] `StoragePermissionManager` 是 `object` 单例,方法均为静态调用。
- [x] 3 种 Intent 降级策略,兼容不同 ROM。
- [x] `findActivity` 通过 ContextWrapper 链查找 Activity,兼容 Compose。

## 验收标准

- 全新安装后,引导用户授权全盘访问,授权后能扫到 `/sdcard/DCIM/`、`/sdcard/Pictures/`。
- 拒绝授权,App 仍能正常打开但 F1 导入功能被禁用,有明确提示。
- 3 种 Intent 降级确保不同设备至少能打开设置页。

## 已知问题

- `requestLegacyExternalStorage="true"` 在 Android 11+ 实际无效,建议清理。
- 缺少 `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO`,Android 13+ 可能需要。
- 不支持 SAF 文件选择和持久化 URI 权限。
- `requestAllFilesAccess` 内部 `findActivity` 失败时用 `FLAG_ACTIVITY_NEW_TASK` 兜底。

## 相关文件

- `app/src/main/AndroidManifest.xml`
- `core-common/src/main/java/com/advancemediakb/core/common/permission/StoragePermissionManager.kt` (101 行)
