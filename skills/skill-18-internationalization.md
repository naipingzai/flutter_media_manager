# Skill-18 国际化 (i18n)

## 目标
定义 AdvanceMediaKB 的中英双语支持策略,资源文件结构、运行时切换、`AppCompatDelegate` 集成。

## 设计要点

| 项 | 设计 |
|---|------|
| 支持语言 | `zh` / `en`(其他语言显示英文) |
| 默认 | 系统语言 |
| 强制设置 | `SettingsDataStore.language_override` 提供 `SYSTEM / ZH / EN` |
| 实现 | 通过 `AppCompatDelegate.setApplicationLocales(LocaleListCompat)` |
| 资源限定 | `app/build.gradle.kts` 的 `resourceConfigurations += setOf("zh", "en")` |
| 资源目录 | `values-zh/strings.xml`、`values-en/strings.xml`、`values/strings.xml`(默认 = 英文) |

### strings.xml 组织

```
res/
├── values/strings.xml            (默认英文,作为 fallback)
├── values-zh/strings.xml         (简体中文)
└── values-en/strings.xml         (英文)
```

### 运行时切换

```
SettingsDataStore.setLanguageOverride(LanguageOverride.ZH)
  ↓
AppCompatDelegate.setApplicationLocales(LocaleListCompat.forLanguageTags("zh"))
  ↓
Activity 自动重建 → 资源重新加载
```

### 多语言字符串规范

- 复数:用 `<plurals>` 资源,不是手写「X 个项目 / X items」。
- 占位符:`<string name="import_progress">已导入 %1$d / %2$d</string>`。
- 顺序敏感文案:`getString(R.string.x, arg1, arg2)`,不用字符串拼接。

## 代码检查点

- [ ] 所有用户可见字符串必须在 `strings.xml`,**不**硬编码在 Composable。
- [ ] `resourceConfigurations` 仅含 `"zh"` `"en"`,其他语言不会被打包。
- [ ] `values/strings.xml`(默认)与 `values-en/strings.xml` 内容一致。
- [ ] 切换语言后,`AppCompatDelegate.setApplicationLocales` 调用,App 自动重建。
- [ ] 不在 Composable 中 `Locale.getDefault()` 读取语言,只通过 `LocalConfiguration.current.locales` 拿。
- [ ] 字符串中**不**混用英语标点(逗号 / 句号),用半角。

## 验收标准

- 系统切到英文,App 显示英文。
- 设置中强制中文,即使系统英文,App 也显示中文。
- 重新安装 App,语言设置从系统继承(SYSTEM 模式下)。
- 所有 Composable 内的文案都在 `strings.xml` 中可找到。

## 已知问题

- 部分 Compose Material3 组件默认字符串硬编码英文(如 Snackbar 默认 action),需显式覆盖。
- `LocaleListCompat` 在 API 31 之前需要手动 wrap 兼容。

## 相关文件

- `app/src/main/res/values/strings.xml`
- `app/src/main/res/values-en/strings.xml`
- `app/src/main/res/values-zh/strings.xml`(如存在,中文 fallback)
- `core-common/src/main/java/com/advancemediakb/common/i18n/LanguageManager.kt`
- `app/build.gradle.kts`(`resourceConfigurations`)
- `core-model/src/main/java/com/advancemediakb/model/LanguageOverride.kt`
