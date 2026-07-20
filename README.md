# AdvanceMediaKB

一个跨平台媒体管理应用，支持 Android、iOS 和 macOS。

## 平台支持

| 平台 | 支持状态 |
|------|---------|
| Android | ✅ |
| iOS | ✅ |
| macOS | ✅ |

## 编译指南

### 环境要求

- Flutter 3.27.0 (stable channel)
- Dart 3.x
- Android: JDK 17 + Android SDK
| iOS/macOS | Xcode 15+ (仅在 macOS 上)

### Android 编译

```bash
# 获取依赖
flutter pub get

# 运行
flutter run

# 构建 APK
flutter build apk --release
```

### iOS 编译 (需要 macOS)

```bash
# 进入 iOS 目录
cd ios

# 安装 CocoaPods 依赖
pod install

# 返回根目录并运行
cd ..
flutter run

# 构建 IPA
flutter build ios --release
```

### macOS 编译 (需要 macOS)

```bash
# 运行
flutter run -d macos

# 构建
flutter build macos --release
```

## CI/CD

项目使用 GitHub Actions 进行持续集成：

- **Build Android** - 在 Ubuntu 上构建 APK
- **Build iOS** - 在 macOS 上构建 iOS 应用

## 架构

项目遵循 BLoC 模式进行状态管理，采用分层架构：

- `lib/bridge/` - 原生功能桥接层
- `lib/core/` - 核心基础设施
- `lib/functionality/` - 业务逻辑 (BLoC)
- `lib/ui/` - 用户界面

## 许可证

MIT
