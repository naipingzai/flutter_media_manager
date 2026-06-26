# Skill-00: 项目构建配置与 Gradle 设置

## 前置依赖
无（这是第一个执行的 skill）

## 目标
完成项目的 Gradle 构建配置，确保多模块项目结构正确，所有依赖版本统一管理。

## 任务清单

### 1. 确认项目根目录结构

项目根目录必须包含以下文件和目录（全部必须存在）：

```
AdvanceMediaKB/
├── settings.gradle.kts          # 模块注册
├── build.gradle.kts             # 根构建脚本
├── gradle.properties            # Gradle 属性
├── gradlew                      # Gradle Wrapper 脚本 (Unix)
├── gradlew.bat                  # Gradle Wrapper 脚本 (Windows)
├── gradle/
│   ├── wrapper/
│   │   ├── gradle-wrapper.jar
│   │   └── gradle-wrapper.properties
│   └── libs.versions.toml       # 版本目录
├── .editorconfig
├── .gitignore
├── app/                         # 主应用模块
├── core-model/                  # 数据模型模块
├── core-database/               # 数据库模块
├── core-designsystem/           # 设计系统模块
├── core-common/                 # 公共基础模块
├── core-image/                  # 图片处理模块
├── core-ui/                     # UI 组件模块
├── domain/                      # 领域层模块
├── data/                        # 数据层模块
├── feature-home/                # 首页功能模块
├── feature-album/               # 相册功能模块
├── feature-tag/                 # 标签功能模块
├── feature-detail/              # 详情功能模块
├── feature-note/                # 笔记功能模块
├── feature-search/              # 搜索功能模块
└── feature-settings/            # 设置功能模块
```

### 2. gradle/libs.versions.toml — 版本目录

必须包含以下全部版本、库和插件定义，一个都不能少：

```toml
[versions]
agp = "8.7.0"
kotlin = "2.0.21"
coreKtx = "1.15.0"
junit = "4.13.2"
junitVersion = "1.2.1"
espressoCore = "3.6.1"
lifecycleRuntimeKtx = "2.8.7"
activityCompose = "1.9.3"
composeBom = "2024.10.01"
appcompat = "1.7.0"
material = "1.12.0"
room = "2.6.1"
ksp = "2.0.21-1.0.25"
hilt = "2.52"
hiltNavigationCompose = "1.2.0"
coil = "2.7.0"
navigationCompose = "2.8.3"
coroutines = "1.9.0"
media3 = "1.5.1"
datastore = "1.1.1"
javaxInject = "1"
robolectric = "4.13"

[libraries]
coreKtx = { group = "androidx.core", name = "core-ktx", version.ref = "coreKtx" }
junit = { group = "junit", name = "junit", version.ref = "junit" }
androidxJunit = { group = "androidx.test.ext", name = "junit", version.ref = "junitVersion" }
espressoCore = { group = "androidx.test.espresso", name = "espresso-core", version.ref = "espressoCore" }
lifecycleRuntimeKtx = { group = "androidx.lifecycle", name = "lifecycle-runtime-ktx", version.ref = "lifecycleRuntimeKtx" }
activityCompose = { group = "androidx.activity", name = "activity-compose", version.ref = "activityCompose" }
composeBom = { group = "androidx.compose", name = "compose-bom", version.ref = "composeBom" }
ui = { group = "androidx.compose.ui", name = "ui" }
uiGraphics = { group = "androidx.compose.ui", name = "ui-graphics" }
uiTooling = { group = "androidx.compose.ui", name = "ui-tooling" }
uiToolingPreview = { group = "androidx.compose.ui", name = "ui-tooling-preview" }
uiTestManifest = { group = "androidx.compose.ui", name = "ui-test-manifest" }
uiTestJunit4 = { group = "androidx.compose.ui", name = "ui-test-junit4" }
material3 = { group = "androidx.compose.material3", name = "material3" }
foundation = { group = "androidx.compose.foundation", name = "foundation" }
appcompat = { group = "androidx.appcompat", name = "appcompat", version.ref = "appcompat" }
material = { group = "com.google.android.material", name = "material", version.ref = "material" }
materialIconsExtended = { group = "androidx.compose.material", name = "material-icons-extended" }
roomRuntime = { group = "androidx.room", name = "room-runtime", version.ref = "room" }
roomKtx = { group = "androidx.room", name = "room-ktx", version.ref = "room" }
roomCompiler = { group = "androidx.room", name = "room-compiler", version.ref = "room" }
roomPaging = { group = "androidx.room", name = "room-paging", version.ref = "room" }
roomFts = { group = "androidx.room", name = "room-fts", version.ref = "room" }
hiltAndroid = { group = "com.google.dagger", name = "hilt-android", version.ref = "hilt" }
hiltCompiler = { group = "com.google.dagger", name = "hilt-android-compiler", version.ref = "hilt" }
hiltNavigationCompose = { group = "androidx.hilt", name = "hilt-navigation-compose", version.ref = "hiltNavigationCompose" }
coilCompose = { group = "io.coil-kt", name = "coil-compose", version.ref = "coil" }
navigationCompose = { group = "androidx.navigation", name = "navigation-compose", version.ref = "navigationCompose" }
kotlinxCoroutinesAndroid = { group = "org.jetbrains.kotlinx", name = "kotlinx-coroutines-android", version.ref = "coroutines" }
kotlinxCoroutinesCore = { group = "org.jetbrains.kotlinx", name = "kotlinx-coroutines-core", version.ref = "coroutines" }
media3Exoplayer = { group = "androidx.media3", name = "media3-exoplayer", version.ref = "media3" }
media3Session = { group = "androidx.media3", name = "media3-session", version.ref = "media3" }
media3Ui = { group = "androidx.media3", name = "media3-ui", version.ref = "media3" }
datastorePreferences = { group = "androidx.datastore", name = "datastore-preferences", version.ref = "datastore" }
splashscreen = { group = "androidx.core", name = "core-splashscreen", version = "1.0.1" }
javaxInject = { group = "javax.inject", name = "javax.inject", version.ref = "javaxInject" }
robolectric = { group = "org.robolectric", name = "robolectric", version.ref = "robolectric" }

[plugins]
androidApplication = { id = "com.android.application", version.ref = "agp" }
androidLibrary = { id = "com.android.library", version.ref = "agp" }
kotlinAndroid = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
kotlinCompose = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
ksp = { id = "com.google.devtools.ksp", version.ref = "ksp" }
hilt = { id = "com.google.dagger.hilt.android", version.ref = "hilt" }
```

### 3. settings.gradle.kts

必须注册所有 14 个模块（1 个 app + 6 个 core + 1 个 domain + 1 个 data + 5 个 feature）：

```kotlin
pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "AdvanceMediaKB"
include(":app")
include(":core-model")
include(":core-database")
include(":core-designsystem")
include(":core-common")
include(":core-image")
include(":core-ui")
include(":domain")
include(":data")
include(":feature-home")
include(":feature-album")
include(":feature-tag")
include(":feature-detail")
include(":feature-note")
include(":feature-search")
include(":feature-settings")
```

### 4. 根 build.gradle.kts

```kotlin
plugins {
    alias(libs.plugins.androidApplication) apply false
    alias(libs.plugins.androidLibrary) apply false
    alias(libs.plugins.kotlinAndroid) apply false
    alias(libs.plugins.kotlinCompose) apply false
    alias(libs.plugins.ksp) apply false
    alias(libs.plugins.hilt) apply false
}
```

### 5. gradle.properties

```properties
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
kotlin.code.style=official
android.nonTransitiveRClass=true
```

### 6. app/build.gradle.kts

```kotlin
plugins {
    alias(libs.plugins.androidApplication)
    alias(libs.plugins.kotlinAndroid)
    alias(libs.plugins.kotlinCompose)
    alias(libs.plugins.ksp)
    alias(libs.plugins.hilt)
}

android {
    namespace = "com.advancemediakb"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.advancemediakb"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }
}

dependencies {
    implementation(project(":core-model"))
    implementation(project(":core-database"))
    implementation(project(":core-designsystem"))
    implementation(project(":core-common"))
    implementation(project(":core-image"))
    implementation(project(":core-ui"))
    implementation(project(":domain"))
    implementation(project(":data"))
    implementation(project(":feature-home"))
    implementation(project(":feature-album"))
    implementation(project(":feature-tag"))
    implementation(project(":feature-detail"))
    implementation(project(":feature-note"))
    implementation(project(":feature-search"))
    implementation(project(":feature-settings"))

    implementation(libs.coreKtx)
    implementation(libs.lifecycleRuntimeKtx)
    implementation(libs.activityCompose)
    implementation(libs.hiltAndroid)
    ksp(libs.hiltCompiler)
    implementation(libs.hiltNavigationCompose)
    implementation(libs.navigationCompose)

    implementation(platform(libs.composeBom))
    implementation(libs.ui)
    implementation(libs.uiGraphics)
    implementation(libs.uiToolingPreview)
    implementation(libs.material3)
