# Skill-00 项目架构

## 目标
定义 AdvanceMediaKB 的多模块 Gradle 结构、依赖方向、单 Activity + 单 Composable 架构约束,作为所有 skill 的基础设施。

## 设计要点

| 项 | 设计 |
|---|------|
| 构建工具 | Gradle 8.x + Kotlin DSL + Version Catalog (`gradle/libs.versions.toml`) |
| JDK | JVM 21 |
| compileSdk / minSdk / targetSdk | 36 / 31 / 36 |
| 资源限定 | `resourceConfigurations += setOf("zh", "en")` 仅打包中英 |
| 主框架 | Jetpack Compose + Material3 |
| 架构模式 | MVVM + Repository + UseCase + Hilt DI |
| 单 Activity | `MainActivity` (主页) + `MediaViewerActivity` (全屏预览,独立 Activity) |
| 单 Composable | `HomeScreen()` 切换三个主页 + 覆盖层(搜索/设置/详情/AMB) |
| DI 风格 | **全部构造器注入**,不使用 `@Module @Provides` |
| 异步 | Kotlin Coroutines + Flow (StateFlow + SharedFlow) |
| 持久化 | Room + DataStore Preferences |
| 播放 | Media3 ExoPlayer |
| 主题 | Material3 + `AppCompatDelegate.MODE_NIGHT_YES` 强制深色 |

### 模块依赖图

```
:app
 ├─→ :feature-home        (主页 Shell + 三个主页)
 ├─→ :feature-detail      (媒体详情 Composable)
 ├─→ :feature-album       (相册树)
 ├─→ :feature-tag         (标签树)
 ├─→ :feature-search      (搜索)
 ├─→ :feature-settings    (设置页)
 ├─→ :core-ui             (通用 Compose 组件)
 ├─→ :core-designsystem   (主题 / 颜色 / 字号)
 ├─→ :core-image          (Coil 加载 / 视频帧提取)
 ├─→ :core-database       (Room 数据库)
 ├─→ :core-model          (领域模型 / Entity)
 ├─→ :core-common         (Result / 扩展)
 ├─→ :data                (Repository 实现)
 └─→ :domain              (UseCase / Repository 接口)
```

依赖规则:
- `:core-*` **不依赖**任何其他项目模块。
- `:data` 依赖 `:domain` 和 `:core-*`,`:domain` 不依赖 `:data`。
- `:feature-*` 依赖 `:domain`、`:core-*`、`:data`,**不**依赖其他 feature。
- `:app` 依赖所有 `:feature-*`,负责把它们装进导航结构。

## 代码检查点

- [ ] `:core-*` 模块的 `build.gradle.kts` **没有** `implementation(project(":data"))` 等反向依赖。
- [ ] 所有 DI 都是构造器注入;`grep -r "@Module" --include="*.kt"` 应为 0。
- [ ] `app/build.gradle.kts` 的 `resourceConfigurations` 仅含 `"zh"` `"en"`。
- [ ] `AndroidManifest.xml` 只有 2 个 Activity:`MainActivity` (LAUNCHER) 和 `MediaViewerActivity`。
- [ ] 没有引入 Navigation Compose;页面切换通过 `HomeScreen` 的状态字段完成。
- [ ] 新功能应优先放到 `:feature-*`,业务逻辑放 `:domain`,数据访问放 `:data`。

## 验收标准

- 项目能 `./gradlew :app:assembleDebug` 成功出 APK。
- 删除任一 `:feature-*` 模块,主体壳仍能跑(只剩该模块对应功能不可用)。
- DI 不依赖运行时反射,App 启动时 Hilt 图能编译通过。

## 已知问题

- (当前项目无遗留问题;新增 feature 必须遵循依赖方向)

## 相关文件

- `build.gradle.kts` / `settings.gradle.kts` / `gradle/libs.versions.toml`
- `app/build.gradle.kts`
- `app/src/main/AndroidManifest.xml`
- `app/src/main/java/com/advancemediakb/AdvanceMediaKBApplication.kt`
- `app/src/main/java/com/advancemediakb/MainActivity.kt`
